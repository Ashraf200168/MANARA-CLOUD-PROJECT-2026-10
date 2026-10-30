[CmdletBinding()]
param([switch]$Scheduled)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$statusRoot = Join-Path $projectRoot '.tools\github-update'
$statusPath = Join-Path $statusRoot 'last-status.json'
$mutex = New-Object Threading.Mutex($false, 'Local\ManaraReleaseBackupUpload')
$hasLock = $false
$reportToolsReady = $false
$savedGitPrompt = $env:GIT_TERMINAL_PROMPT
$savedGcmInteractive = $env:GCM_INTERACTIVE
$state = [ordered]@{
  status = 'RUNNING'
  startedAt = [DateTimeOffset]::Now.ToString('o')
  completedAt = $null
  appVersion = '1.5.1'
  backup = $null
  sourceCommit = $null
  encryptedBackupCommit = $null
  error = $null
}
function Save-UploadState {
  $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statusPath -Encoding UTF8
}
function Save-TextReport {
  $text = Format-ManaraBackupReport -State $state
  $stamp = [DateTimeOffset]::Parse($state.startedAt).ToString('yyyyMMdd-HHmmss')
  $roots = @((Join-Path $statusRoot 'reports'))
  $configPath = Join-Path $projectRoot '.tools\backup\backup-config.json'
  if (Test-Path -LiteralPath $configPath) {
    try {
      $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      if ($config.backupRoot) { $roots += Join-Path ([string]$config.backupRoot) 'Reports' }
    } catch { Write-Warning 'Could not read the backup folder for the second report copy.' }
  }
  foreach ($root in $roots) {
    try {
      New-Item -ItemType Directory -Force -Path $root | Out-Null
      $report = Join-Path $root "manara-backup-report-$stamp.txt"
      Set-Content -LiteralPath $report -Value $text -Encoding UTF8
      Set-Content -LiteralPath (Join-Path $root 'latest-report.txt') -Value $text -Encoding UTF8
      Write-Host "Text report: $report"
    } catch { Write-Warning "Could not save a text report in $root" }
  }
}
function Read-Git {
  param([string[]]$GitArgs)
  $output = @(& git -c "safe.directory=$projectRoot" -C $projectRoot @GitArgs)
  if ($LASTEXITCODE -ne 0) { throw "Git verification failed: $($GitArgs[0])" }
  return ($output -join "`n").Trim()
}
try {
  try { $hasLock = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $hasLock = $true }
  if (-not $hasLock) { Write-Host 'A Manara backup/upload is already running. This duplicate run was skipped.'; exit 75 }
  . (Join-Path $projectRoot 'scripts\BackupReportTools.ps1')
  $reportToolsReady = $true
  if ($Scheduled) {
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'Never'
  }
  New-Item -ItemType Directory -Force -Path $statusRoot | Out-Null
  Save-UploadState
  $apk = Join-Path $projectRoot 'release\Manara-App-v1.5.1-question-editor-roadmap-arm64.apk'
  if (-not (Test-Path -LiteralPath $apk)) { throw 'The verified v1.5.1 APK is missing. Run FINALIZE-MANARA-APK.cmd first.' }
  $apkHash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
  $recordedApkHash = ((Get-Content -LiteralPath "$apk.sha256.txt" -Raw).Trim() -split '\s+')[0]
  if ($apkHash -ne $recordedApkHash) { throw 'The APK checksum does not match.' }

  Write-Host '[1/3] Creating and verifying a fresh encrypted database and books backup...'
  $started = [DateTimeOffset]::Now
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'RUN-MANARA-BACKUP.ps1') -Force -SkipGitHubUpload -WaitForLockSeconds 900
  if ($LASTEXITCODE -eq 75) { throw 'Another backup is still running after 15 minutes. It was left untouched; try again after it finishes.' }
  if ($LASTEXITCODE -ne 0) { throw 'The fresh encrypted backup failed. Existing successful backups are still available.' }
  $last = Get-Content -LiteralPath (Join-Path $projectRoot '.tools\backup\last-success.json') -Raw | ConvertFrom-Json
  if ($last.status -ne 'SUCCESS' -or [DateTimeOffset]::Parse($last.completedAt) -lt $started) {
    throw 'The backup process ended without confirming a fresh verified backup. Nothing was uploaded.'
  }
  $backupHash = (Get-FileHash -LiteralPath $last.archive -Algorithm SHA256).Hash
  if ($backupHash -ne $last.sha256) { throw 'The verified backup checksum does not match.' }
  $state.backup = @{ path = $last.archive; sha256 = $backupHash; bytes = $last.bytes }
  $state.status = 'BACKUP_CREATED'
  Save-UploadState

  Write-Host '[2/3] Uploading the current source, documentation, and v1.5.1 APK to GitHub main...'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'SYNC-MANARA-PUBLIC-GITHUB.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'The backup is safe locally, but the source/APK upload failed.' }
  $head = Read-Git -GitArgs @('rev-parse', 'HEAD')
  $remote = Read-Git -GitArgs @('ls-remote', '--heads', 'origin', 'main')
  $remoteHead = ($remote -split '\s+')[0]
  if ($remoteHead -ne $head) { throw 'The remote main branch did not confirm the uploaded commit.' }
  $remoteHashText = Read-Git -GitArgs @('show', "${head}:release/Manara-App-v1.5.1-question-editor-roadmap-arm64.apk.sha256.txt")
  if (($remoteHashText -split '\s+')[0] -ne $apkHash) { throw 'The uploaded APK checksum was not confirmed in the commit.' }
  $state.sourceCommit = $head
  $state.status = 'SOURCE_UPLOADED'
  Save-UploadState

  Write-Host '[3/3] Uploading the verified snapshot to the encrypted-backup branch...'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'PUBLISH-MANARA-ENCRYPTED-BACKUP.ps1') -BackupPath $last.archive
  if ($LASTEXITCODE -ne 0) { throw 'Source/APK are uploaded, but encrypted-backup publishing failed. The backup is still safe locally.' }
  $null = Read-Git -GitArgs @('fetch', 'origin', 'encrypted-backup')
  $metadataText = Read-Git -GitArgs @('show', 'FETCH_HEAD:backup-metadata.json')
  $metadata = $metadataText | ConvertFrom-Json
  if ($metadata.sha256 -ne $backupHash) { throw 'The remote encrypted backup checksum did not match.' }
  $state.encryptedBackupCommit = Read-Git -GitArgs @('rev-parse', 'FETCH_HEAD')
  $state.status = 'SUCCESS'
  $state.completedAt = [DateTimeOffset]::Now.ToString('o')
  Save-UploadState
  Write-Host 'MANARA BACKUP AND GITHUB UPDATE COMPLETED SUCCESSFULLY' -ForegroundColor Green
  Write-Host 'main: latest source, documentation, and v1.5.1 APK'
  Write-Host "encrypted-backup: $([IO.Path]::GetFileName($last.archive))"
  Write-Host 'Both remote checksums have been verified.'
  exit 0
} catch {
  $state.status = 'FAILED'
  $state.error = $_.Exception.Message
  $state.completedAt = [DateTimeOffset]::Now.ToString('o')
  if ($hasLock -and (Test-Path -LiteralPath $statusRoot)) { Save-UploadState }
  Write-Host "BACKUP/UPLOAD FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  if ($hasLock) {
    try { if ($reportToolsReady) { Save-TextReport } }
    finally { $mutex.ReleaseMutex() }
  }
  $mutex.Dispose()
  $env:GIT_TERMINAL_PROMPT = $savedGitPrompt
  $env:GCM_INTERACTIVE = $savedGcmInteractive
}

param(
  [switch]$Force,
  [switch]$SkipGitHubUpload,
  [ValidateRange(0, 3600)][int]$WaitForLockSeconds = 0
)

$ErrorActionPreference = 'Stop'
$projectRoot = 'C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud'
$toolRoot = Join-Path $projectRoot '.tools\backup'
$privateRoot = Join-Path $toolRoot 'private'
$stagingRoot = Join-Path $toolRoot 'staging'
$configPath = Join-Path $toolRoot 'backup-config.json'
$lastSuccessPath = Join-Path $toolRoot 'last-success.json'
$statusPath = Join-Path $toolRoot 'last-run.json'
$logPath = Join-Path $toolRoot 'backup.log'
$mutex = New-Object Threading.Mutex($false, 'Local\ManaraCloudBackup')
$hasLock = $false

function Write-BackupLog([string]$Message) {
  $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
  Write-Host $line
}

function Convert-SecureToPlain([Security.SecureString]$Value) {
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
  finally { if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) } }
}

function Assert-ChildPath([string]$Candidate, [string]$Parent) {
  $resolvedCandidate = [IO.Path]::GetFullPath($Candidate)
  $resolvedParent = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
  if (-not $resolvedCandidate.StartsWith($resolvedParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe path outside expected directory: $resolvedCandidate"
  }
}

function Remove-StagingPath([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Assert-ChildPath $Path $stagingRoot
  Remove-Item -LiteralPath $Path -Recurse -Force
}

try {
  . (Join-Path $PSScriptRoot 'scripts\BackupLockTools.ps1')
  $hasLock = Wait-ManaraBackupLock -Mutex $mutex -TimeoutSeconds $WaitForLockSeconds
  if (-not $hasLock) {
    Write-Host 'Another Manara backup is still running. No backup was stopped or replaced.'
    if ($WaitForLockSeconds -gt 0) { exit 75 }
    exit 0
  }
  New-Item -ItemType Directory -Path $toolRoot, $privateRoot, $stagingRoot -Force | Out-Null
  if (-not (Test-Path -LiteralPath $configPath)) { throw 'Backup is not configured. Run SETUP-MANARA-AUTOMATIC-BACKUP.cmd first.' }
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $backupRoot = [IO.Path]::GetFullPath([string]$config.backupRoot)
  New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

  if (-not $Force -and (Test-Path -LiteralPath $lastSuccessPath)) {
    $last = Get-Content -LiteralPath $lastSuccessPath -Raw | ConvertFrom-Json
    $elapsed = (Get-Date) - ([DateTimeOffset]::Parse([string]$last.completedAt)).LocalDateTime
    if ($elapsed.TotalHours -lt [double]$config.minimumIntervalHours) {
      Write-BackupLog ('Not due yet; last successful backup was {0:N1} hours ago.' -f $elapsed.TotalHours)
      exit 0
    }
  }

  $secretBlob = (Get-Content -LiteralPath (Join-Path $privateRoot 'supabase-secret.dpapi') -Raw).Trim()
  $passwordBlob = (Get-Content -LiteralPath (Join-Path $privateRoot 'backup-password.dpapi') -Raw).Trim()
  $secretSecure = ConvertTo-SecureString $secretBlob
  $passwordSecure = ConvertTo-SecureString $passwordBlob
  $env:SUPABASE_URL = [string]$config.supabaseUrl
  $env:SUPABASE_SECRET_KEY = Convert-SecureToPlain $secretSecure
  $env:MANARA_BACKUP_PASSPHRASE = Convert-SecureToPlain $passwordSecure

  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $snapshotName = "manara-cloud-$stamp"
  $snapshotPath = Join-Path $stagingRoot $snapshotName
  $plainArchive = Join-Path $stagingRoot "$snapshotName.tar.gz"
  $verifyArchive = Join-Path $stagingRoot "$snapshotName.verify.tar.gz"
  $encryptedArchive = Join-Path $backupRoot "$snapshotName.mnbak"
  $nodePath = [string]$config.nodePath
  $backupScript = Join-Path $projectRoot 'migration\backup-supabase.mjs'
  $encryptScript = Join-Path $projectRoot 'migration\encrypt-backup.mjs'
  $decryptScript = Join-Path $projectRoot 'migration\decrypt-backup.mjs'

  Write-BackupLog "Starting encrypted backup $snapshotName"
  $exportSucceeded = $false
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    Remove-StagingPath $snapshotPath
    Write-BackupLog "Database and books export attempt $attempt of 3"
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $nativeOutput = & $nodePath $backupScript $snapshotPath $projectRoot 2>&1
    $nativeExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    $nativeOutput | ForEach-Object { Write-BackupLog ([string]$_) }
    if ($nativeExitCode -eq 0) { $exportSucceeded = $true; break }
    if ($attempt -lt 3) { Write-BackupLog 'Export failed; retrying in 30 seconds.'; Start-Sleep -Seconds 30 }
  }
  if (-not $exportSucceeded) { throw 'Export failed after three attempts.' }

  & tar -C $stagingRoot -czf $plainArchive $snapshotName
  if ($LASTEXITCODE -ne 0) { throw "Archive creation failed with exit code $LASTEXITCODE" }
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $nativeOutput = & $nodePath $encryptScript $plainArchive $encryptedArchive 2>&1
  $nativeExitCode = $LASTEXITCODE
  $ErrorActionPreference = $savedPreference
  $nativeOutput | ForEach-Object { Write-BackupLog ([string]$_) }
  if ($nativeExitCode -ne 0) { throw 'Backup encryption failed.' }

  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $nativeOutput = & $nodePath $decryptScript $encryptedArchive $verifyArchive 2>&1
  $nativeExitCode = $LASTEXITCODE
  $ErrorActionPreference = $savedPreference
  $nativeOutput | ForEach-Object { Write-BackupLog ([string]$_) }
  if ($nativeExitCode -ne 0) { throw 'Encrypted backup verification failed.' }
  $plainHash = (Get-FileHash -LiteralPath $plainArchive -Algorithm SHA256).Hash
  $verifyHash = (Get-FileHash -LiteralPath $verifyArchive -Algorithm SHA256).Hash
  if ($plainHash -ne $verifyHash) { throw 'Encrypted backup verification hash did not match.' }

  $encryptedHash = (Get-FileHash -LiteralPath $encryptedArchive -Algorithm SHA256).Hash
  $hashPath = "$encryptedArchive.sha256.txt"
  Set-Content -LiteralPath $hashPath -Value "$encryptedHash  $([IO.Path]::GetFileName($encryptedArchive))" -Encoding ASCII
  Remove-StagingPath $snapshotPath
  Remove-StagingPath $plainArchive
  Remove-StagingPath $verifyArchive

  $archives = Get-ChildItem -LiteralPath $backupRoot -Filter 'manara-cloud-*.mnbak' -File | Sort-Object LastWriteTime -Descending
  $retentionCount = [Math]::Max(1, [int]$config.retentionCount)
  foreach ($old in ($archives | Select-Object -Skip $retentionCount)) {
    Assert-ChildPath $old.FullName $backupRoot
    Remove-Item -LiteralPath $old.FullName -Force
    $oldHash = "$($old.FullName).sha256.txt"
    if (Test-Path -LiteralPath $oldHash) { Assert-ChildPath $oldHash $backupRoot; Remove-Item -LiteralPath $oldHash -Force }
    Write-BackupLog "Removed expired backup $($old.Name)"
  }

  $result = [ordered]@{
    status = 'SUCCESS'
    completedAt = [DateTimeOffset]::Now.ToString('o')
    archive = $encryptedArchive
    bytes = (Get-Item -LiteralPath $encryptedArchive).Length
    sha256 = $encryptedHash
  }
  $result | ConvertTo-Json | Set-Content -LiteralPath $lastSuccessPath -Encoding UTF8
  $result | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
  Write-BackupLog "BACKUP SUCCESS: $encryptedArchive"

  $githubMarker = Join-Path $projectRoot '.tools\github-backup-publish\enabled'
  $githubPublisher = Join-Path $projectRoot 'PUBLISH-MANARA-ENCRYPTED-BACKUP.ps1'
  if (-not $SkipGitHubUpload -and (Test-Path -LiteralPath $githubMarker) -and (Test-Path -LiteralPath $githubPublisher)) {
    Write-BackupLog 'Publishing the verified encrypted snapshot to the GitHub encrypted-backup branch.'
    $publisherProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy', 'Bypass',
      '-File', "`"$githubPublisher`"",
      '-BackupPath', "`"$encryptedArchive`""
    ) -Wait -PassThru -WindowStyle Hidden
    if ($publisherProcess.ExitCode -eq 0) {
      Write-BackupLog 'GitHub encrypted-backup upload completed.'
    } else {
      Write-BackupLog "WARNING: Backup is safe in OneDrive, but GitHub upload failed with exit code $($publisherProcess.ExitCode)."
    }
  }
}
catch {
  New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
  $failure = [ordered]@{ status = 'FAILED'; completedAt = [DateTimeOffset]::Now.ToString('o'); error = $_.Exception.Message }
  $failure | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
  Write-BackupLog "BACKUP FAILED: $($_.Exception.Message)"
  exit 1
}
finally {
  Remove-Item Env:SUPABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SUPABASE_SECRET_KEY -ErrorAction SilentlyContinue
  Remove-Item Env:MANARA_BACKUP_PASSPHRASE -ErrorAction SilentlyContinue
  if ($hasLock) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}

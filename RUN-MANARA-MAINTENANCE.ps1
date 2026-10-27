[CmdletBinding()]
param(
  [switch]$SkipNetwork,
  [switch]$NoRepair
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$toolRoot = Join-Path $projectRoot '.tools\maintenance'
$statusPath = Join-Path $toolRoot 'last-status.json'
$logPath = Join-Path $toolRoot 'maintenance.log'
$backupToolRoot = Join-Path $projectRoot '.tools\backup'
$backupConfigPath = Join-Path $backupToolRoot 'backup-config.json'
$backupSuccessPath = Join-Path $backupToolRoot 'last-success.json'
$backupRunner = Join-Path $projectRoot 'RUN-MANARA-BACKUP.ps1'
$publicSync = Join-Path $projectRoot 'SYNC-MANARA-PUBLIC-GITHUB.ps1'
$backupPublisher = Join-Path $projectRoot 'PUBLISH-MANARA-ENCRYPTED-BACKUP.ps1'
$backupPublishMarker = Join-Path $projectRoot '.tools\github-backup-publish\enabled'
$backupPublishLog = Join-Path $projectRoot '.tools\github-backup-publish\publish.log'
$websiteUrl = 'https://manara-cloud-preview.pages.dev/'
$apiHealthUrl = 'https://zgzqoxxhiwrzxsgoqyyb.supabase.co/functions/v1/manara-api/api/health'
$mutex = New-Object Threading.Mutex($false, 'Local\ManaraFullHandsOffMaintenance')
$hasLock = $false

function Write-MaintenanceLog([string]$Message) {
  New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
  if ((Test-Path -LiteralPath $logPath) -and (Get-Item -LiteralPath $logPath).Length -gt 2MB) {
    $oldLog = Join-Path $toolRoot 'maintenance.previous.log'
    Copy-Item -LiteralPath $logPath -Destination $oldLog -Force
    Clear-Content -LiteralPath $logPath
  }
  $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
  Write-Host $line
}

function Test-Endpoint {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Url,
    [switch]$RequireHealthyJson
  )
  if ($SkipNetwork) {
    return [ordered]@{ status = 'SKIPPED'; detail = 'Network checks were disabled for this run.'; checkedAt = [DateTimeOffset]::Now.ToString('o') }
  }

  $lastError = ''
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Get -TimeoutSec 25 -Headers @{ 'Cache-Control' = 'no-cache' }
      if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 400) {
        throw "$Name returned HTTP $($response.StatusCode)."
      }
      if ($RequireHealthyJson) {
        $payload = $response.Content | ConvertFrom-Json
        if (-not $payload.ok) { throw "$Name returned a response without ok=true." }
      }
      return [ordered]@{ status = 'OK'; httpStatus = [int]$response.StatusCode; attempt = $attempt; checkedAt = [DateTimeOffset]::Now.ToString('o') }
    }
    catch {
      $lastError = $_.Exception.Message
      Write-MaintenanceLog "$Name check attempt $attempt failed: $lastError"
      if ($attempt -lt 3) { Start-Sleep -Seconds 10 }
    }
  }
  return [ordered]@{ status = 'FAILED'; detail = $lastError; checkedAt = [DateTimeOffset]::Now.ToString('o') }
}

function Invoke-PowerShellFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string[]]$Arguments = @()
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required script was not found: $Path" }
  $argumentList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$Path`"") + $Arguments
  $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentList -Wait -PassThru -WindowStyle Hidden
  return [int]$process.ExitCode
}

function Get-BackupState {
  if (-not (Test-Path -LiteralPath $backupConfigPath)) {
    return [ordered]@{ status = 'FAILED'; detail = 'Automatic backup is not configured.' }
  }
  $config = Get-Content -LiteralPath $backupConfigPath -Raw | ConvertFrom-Json
  $backupRoot = [IO.Path]::GetFullPath([string]$config.backupRoot)
  $latest = Get-ChildItem -LiteralPath $backupRoot -Filter 'manara-cloud-*.mnbak' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
  if (-not $latest) {
    return [ordered]@{ status = 'FAILED'; detail = "No encrypted backup exists in $backupRoot"; backupRoot = $backupRoot }
  }
  $ageHours = ((Get-Date).ToUniversalTime() - $latest.LastWriteTimeUtc).TotalHours
  $state = if ($ageHours -le 76) { 'OK' } else { 'STALE' }
  return [ordered]@{
    status = $state
    backupRoot = $backupRoot
    latestName = $latest.Name
    latestPath = $latest.FullName
    ageHours = [Math]::Round($ageHours, 1)
    bytes = $latest.Length
  }
}

function Test-BackupWasPublished([string]$BackupName) {
  if (-not (Test-Path -LiteralPath $backupPublishLog)) { return $false }
  return [bool](Select-String -LiteralPath $backupPublishLog -SimpleMatch -Pattern "ENCRYPTED BACKUP GITHUB UPLOAD SUCCESS: $BackupName" -Quiet)
}

try {
  $hasLock = $mutex.WaitOne(0)
  if (-not $hasLock) { Write-Host 'Another Manara maintenance run is already active.'; exit 0 }
  New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
  Write-MaintenanceLog 'Starting full hands-off maintenance.'

  $previousFailureCount = 0
  $previousNotifiedAt = $null
  if (Test-Path -LiteralPath $statusPath) {
    try {
      $previous = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
      $previousFailureCount = [int]$previous.consecutiveFailures
      if ($previous.notifiedAt) { $previousNotifiedAt = [DateTimeOffset]::Parse([string]$previous.notifiedAt) }
    } catch { Write-MaintenanceLog 'Previous status could not be read; starting a new status history.' }
  }

  $checks = [ordered]@{}
  $checks.website = Test-Endpoint -Name 'Cloudflare website' -Url $websiteUrl
  $checks.api = Test-Endpoint -Name 'Supabase API' -Url $apiHealthUrl -RequireHealthyJson

  $backup = Get-BackupState
  if ($backup.status -ne 'OK' -and -not $NoRepair) {
    Write-MaintenanceLog "Backup state is $($backup.status); starting a verified encrypted backup."
    $backupExit = Invoke-PowerShellFile -Path $backupRunner -Arguments @('-Force')
    if ($backupExit -ne 0) { Write-MaintenanceLog "Backup repair exited with code $backupExit." }
    $backup = Get-BackupState
  }
  $checks.backup = $backup

  if ($SkipNetwork -or $NoRepair) {
    $checks.publicGitHub = [ordered]@{ status = 'SKIPPED'; detail = 'Publishing was disabled for this run.' }
  } else {
    Write-MaintenanceLog 'Synchronizing sanitized source, documentation, and the curated APK with GitHub.'
    $syncExit = Invoke-PowerShellFile -Path $publicSync
    $checks.publicGitHub = if ($syncExit -eq 0) {
      [ordered]@{ status = 'OK'; detail = 'main is synchronized.' }
    } else {
      [ordered]@{ status = 'FAILED'; detail = "GitHub source sync exited with code $syncExit." }
    }
  }

  if ($backup.status -eq 'OK' -and $backup.latestName) {
    $alreadyPublished = Test-BackupWasPublished -BackupName ([string]$backup.latestName)
    if (-not $alreadyPublished -and -not $SkipNetwork -and -not $NoRepair -and (Test-Path -LiteralPath $backupPublishMarker)) {
      Write-MaintenanceLog "The newest encrypted backup is not confirmed on GitHub; uploading $($backup.latestName)."
      $quotedBackup = "-BackupPath `"$($backup.latestPath)`""
      $uploadExit = Invoke-PowerShellFile -Path $backupPublisher -Arguments @($quotedBackup)
      $alreadyPublished = ($uploadExit -eq 0) -and (Test-BackupWasPublished -BackupName ([string]$backup.latestName))
    }
    $checks.encryptedBackupGitHub = if ($SkipNetwork -or $NoRepair) {
      [ordered]@{ status = 'SKIPPED'; latestName = $backup.latestName; previouslyPublished = $alreadyPublished }
    } elseif (-not (Test-Path -LiteralPath $backupPublishMarker)) {
      [ordered]@{ status = 'FAILED'; detail = 'GitHub encrypted-backup publishing is not enabled.' }
    } elseif ($alreadyPublished) {
      [ordered]@{ status = 'OK'; latestName = $backup.latestName }
    } else {
      [ordered]@{ status = 'FAILED'; detail = "Could not confirm $($backup.latestName) on the encrypted-backup branch." }
    }
  } else {
    $checks.encryptedBackupGitHub = [ordered]@{ status = 'FAILED'; detail = 'No current verified backup is available to publish.' }
  }

  $failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value.status -in @('FAILED', 'STALE') })
  $healthy = ($failedChecks.Count -eq 0)
  $failureCount = if ($healthy) { 0 } else { $previousFailureCount + 1 }
  $notifiedAt = $previousNotifiedAt

  $backupRootForNotice = if ($backup.backupRoot) { [string]$backup.backupRoot } else { $toolRoot }
  $attentionPath = Join-Path $backupRootForNotice 'MANARA-ATTENTION.txt'
  if ($healthy) {
    if (([IO.Path]::GetFileName($attentionPath) -eq 'MANARA-ATTENTION.txt') -and (Test-Path -LiteralPath $attentionPath)) {
      Remove-Item -LiteralPath $attentionPath -Force
    }
    Write-MaintenanceLog 'HANDS-OFF MAINTENANCE SUCCESS: all enabled checks passed.'
  } else {
    $summary = ($failedChecks | ForEach-Object { "$($_.Key): $($_.Value.detail)" }) -join [Environment]::NewLine
    Write-MaintenanceLog "MAINTENANCE WARNING: $($failedChecks.Count) check(s) failed; consecutive failures: $failureCount."
    $mayNotify = ($failureCount -ge 3) -and (-not $previousNotifiedAt -or ((Get-Date) - $previousNotifiedAt.LocalDateTime).TotalHours -ge 24)
    if ($mayNotify) {
      @(
        'MANARA NEEDS ATTENTION'
        "Detected: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Consecutive failed checks: $failureCount"
        ''
        $summary
        ''
        "Full status: $statusPath"
        "Log: $logPath"
      ) | Set-Content -LiteralPath $attentionPath -Encoding UTF8
      $notifiedAt = [DateTimeOffset]::Now
      $savedPreference = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      & msg.exe $env:USERNAME 'Manara needs attention after three failed automatic checks. Open MANARA-ATTENTION.txt in the backup folder.' 2>$null
      $ErrorActionPreference = $savedPreference
    }
  }

  $result = [ordered]@{
    format = 'manara-maintenance-status-v1'
    runAt = [DateTimeOffset]::Now.ToString('o')
    overall = if ($healthy) { 'HEALTHY' } else { 'NEEDS_ATTENTION' }
    consecutiveFailures = $failureCount
    notifiedAt = if ($notifiedAt) { $notifiedAt.ToString('o') } else { $null }
    checks = $checks
  }
  $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statusPath -Encoding UTF8
  if (-not $healthy) { exit 1 }
}
catch {
  New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
  $fatalError = $_.Exception.Message
  Write-MaintenanceLog "MAINTENANCE FAILED: $fatalError"
  $fatalFailureCount = 1
  $fatalNotifiedAt = $null
  if (Test-Path -LiteralPath $statusPath) {
    try {
      $oldStatus = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
      $fatalFailureCount = [int]$oldStatus.consecutiveFailures + 1
      if ($oldStatus.notifiedAt) { $fatalNotifiedAt = [DateTimeOffset]::Parse([string]$oldStatus.notifiedAt) }
    } catch { $fatalFailureCount = 1 }
  }
  if ($fatalFailureCount -ge 3 -and (-not $fatalNotifiedAt -or ((Get-Date) - $fatalNotifiedAt.LocalDateTime).TotalHours -ge 24)) {
    $fatalNoticeRoot = $toolRoot
    try {
      if (Test-Path -LiteralPath $backupConfigPath) {
        $fatalConfig = Get-Content -LiteralPath $backupConfigPath -Raw | ConvertFrom-Json
        $fatalNoticeRoot = [IO.Path]::GetFullPath([string]$fatalConfig.backupRoot)
      }
    } catch { $fatalNoticeRoot = $toolRoot }
    $fatalAttentionPath = Join-Path $fatalNoticeRoot 'MANARA-ATTENTION.txt'
    @(
      'MANARA NEEDS ATTENTION'
      "Detected: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
      "Consecutive maintenance failures: $fatalFailureCount"
      ''
      $fatalError
      ''
      "Log: $logPath"
    ) | Set-Content -LiteralPath $fatalAttentionPath -Encoding UTF8
    $fatalNotifiedAt = [DateTimeOffset]::Now
  }
  [ordered]@{
    format = 'manara-maintenance-status-v1'
    runAt = [DateTimeOffset]::Now.ToString('o')
    overall = 'FAILED'
    consecutiveFailures = $fatalFailureCount
    notifiedAt = if ($fatalNotifiedAt) { $fatalNotifiedAt.ToString('o') } else { $null }
    error = $fatalError
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statusPath -Encoding UTF8
  exit 1
}
finally {
  if ($hasLock) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}

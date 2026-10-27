$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Manara Full Hands-Off Setup'
$projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$maintenanceScript = Join-Path $projectRoot 'RUN-MANARA-MAINTENANCE.ps1'
$publicSync = Join-Path $projectRoot 'SYNC-MANARA-PUBLIC-GITHUB.ps1'
$backupConfig = Join-Path $projectRoot '.tools\backup\backup-config.json'
$githubMarker = Join-Path $projectRoot '.tools\github-backup-publish\enabled'
$statusPath = Join-Path $projectRoot '.tools\maintenance\last-status.json'

try {
  Write-Host ''
  Write-Host 'MANARA - FULL HANDS-OFF SETUP' -ForegroundColor Cyan
  Write-Host 'No website or mobile app update is required for this operations setup.'
  Write-Host ''

  if (-not (Test-Path -LiteralPath $backupConfig)) {
    throw 'Encrypted backup is not configured. Run START-MANARA-BACKUP-SETUP.bat first.'
  }
  if (-not (Test-Path -LiteralPath $githubMarker)) {
    throw 'GitHub backup publishing is not enabled. Run START-MANARA-GITHUB-UPLOAD.bat first.'
  }
  if (-not (Test-Path -LiteralPath $maintenanceScript)) { throw 'The maintenance script is missing.' }

  Write-Host '[1/3] Publishing the hands-off operations files to GitHub...' -ForegroundColor Cyan
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $publicSync
  if ($LASTEXITCODE -ne 0) { throw 'GitHub synchronization failed. Check the browser login or VPN and run this file again.' }

  Write-Host ''
  Write-Host '[2/3] Registering the automatic maintenance task...' -ForegroundColor Cyan
  $taskName = 'Manara Full Hands-Off Maintenance'
  $taskArgument = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$maintenanceScript`""
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgument
  $morning = New-ScheduledTaskTrigger -Daily -At '09:00'
  $evening = New-ScheduledTaskTrigger -Daily -At '19:00'
  $atLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 3)
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($morning, $evening, $atLogon) -Settings $settings -Principal $principal -Description 'Checks Manara Cloud, repairs stale backups, and synchronizes GitHub twice daily and at Windows sign-in.' -Force | Out-Null

  Write-Host ''
  Write-Host '[3/3] Running the first complete health and recovery check...' -ForegroundColor Cyan
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $maintenanceScript
  $maintenanceExit = $LASTEXITCODE

  Write-Host ''
  if ($maintenanceExit -eq 0) {
    Write-Host 'MANARA FULL HANDS-OFF MODE IS ACTIVE AND HEALTHY' -ForegroundColor Green
  } else {
    Write-Host 'MANARA FULL HANDS-OFF MODE IS ACTIVE, BUT THE FIRST CHECK FOUND A TEMPORARY FAILURE.' -ForegroundColor Yellow
    Write-Host 'It will retry automatically at the next scheduled check.'
  }
  Write-Host 'Checks: at Windows sign-in, 09:00, and 19:00.'
  Write-Host 'Automatic: website/API health, encrypted backup freshness, GitHub source, APK, and encrypted-backup branch.'
  Write-Host 'After three consecutive failures, Windows and the backup folder will show an attention notice.'
  Write-Host "Status: $statusPath"
}
catch {
  Write-Host ''
  Write-Host 'FULL HANDS-OFF SETUP FAILED' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host 'Keep this window open and send Codex only this error message. Never send passwords or secret keys.'
}
finally {
  Read-Host 'Press Enter to close'
}

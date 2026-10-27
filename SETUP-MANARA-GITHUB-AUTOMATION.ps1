$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Manara GitHub Automation Setup'
$projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$syncScript = Join-Path $projectRoot 'SYNC-MANARA-PUBLIC-GITHUB.ps1'
$backupPublisher = Join-Path $projectRoot 'PUBLISH-MANARA-ENCRYPTED-BACKUP.ps1'
$enableMarker = Join-Path $projectRoot '.tools\github-backup-publish\enabled'
$backupRoot = Join-Path $env:USERPROFILE 'OneDrive\Manara Cloud Backups'

try {
  Write-Host ''
  Write-Host 'MANARA - GITHUB AUTOMATION SETUP' -ForegroundColor Cyan
  Write-Host 'A GitHub browser login may appear once. Complete it with Ashraf200168.' -ForegroundColor Yellow
  Write-Host ''

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript
  if ($LASTEXITCODE -ne 0) { throw 'The first public source upload failed. Complete the GitHub sign-in and run this file again.' }

  $taskName = 'Manara Public Source GitHub Sync'
  $taskArgument = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$syncScript`""
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgument
  $daily = New-ScheduledTaskTrigger -Daily -At '18:30'
  $atLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($daily, $atLogon) -Settings $settings -Principal $principal -Description 'Publishes the sanitized Manara source, documentation, and curated APK to GitHub.' -Force | Out-Null

  New-Item -ItemType Directory -Path (Split-Path -Parent $enableMarker) -Force | Out-Null
  Set-Content -LiteralPath $enableMarker -Value 'enabled' -Encoding ASCII

  $latestBackup = Get-ChildItem -LiteralPath $backupRoot -Filter 'manara-cloud-*.mnbak' -File -ErrorAction Stop |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latestBackup) { throw "No encrypted backup was found in $backupRoot" }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $backupPublisher -BackupPath $latestBackup.FullName
  if ($LASTEXITCODE -ne 0) { throw 'The source was published, but the encrypted-backup branch upload failed.' }

  Write-Host ''
  Write-Host 'MANARA GITHUB AUTOMATION COMPLETED SUCCESSFULLY' -ForegroundColor Green
  Write-Host 'main: source, documentation, and latest APK'
  Write-Host 'encrypted-backup: newest encrypted backup only'
  Write-Host 'Future verified backups will upload automatically.'
}
catch {
  Write-Host ''
  Write-Host 'GITHUB AUTOMATION SETUP FAILED' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host 'Keep this window open and send Codex only this error. Do not send passwords or keys.'
}
finally {
  Read-Host 'Press Enter to close'
}

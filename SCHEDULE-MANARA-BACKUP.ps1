[CmdletBinding()]
param([switch]$Preview)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$taskName = 'Manara Cloud Encrypted Backup'
$runner = Join-Path $projectRoot 'BACKUP-AND-UPLOAD-MANARA.cmd'
$configPath = Join-Path $projectRoot '.tools\backup\backup-config.json'
$scheduleRoot = Join-Path $projectRoot '.tools\github-update'
. (Join-Path $projectRoot 'scripts\BackupReportTools.ps1')
try {
  if ((Get-TimeZone).Id -ne 'Syria Standard Time') {
    throw 'Set the Windows time zone to Damascus (Syria Standard Time), then run this file again. No task was changed.'
  }
  $firstRun = Get-ManaraNextBackupTime
  $account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
  $arguments = '/d /c ""' + $runner + '" --scheduled"'
  if ($Preview) {
    [pscustomobject]@{ TaskName=$taskName; Account=$account; FirstRun=$firstRun.ToString('yyyy-MM-dd HH:mm'); DaysInterval=3; Command='cmd.exe'; Arguments=$arguments; TimeZone='Asia/Damascus' } | Format-List
    exit 0
  }
  if ($account -match 'codexsandbox') { throw 'Run SCHEDULE-MANARA-BACKUP.cmd from your normal Windows account, not the isolated coding account.' }
  foreach ($path in @($runner, $configPath, (Join-Path $projectRoot '.tools\backup\private\supabase-secret.dpapi'), (Join-Path $projectRoot '.tools\backup\private\backup-password.dpapi'))) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required backup configuration file is missing: $path" }
  }
  Import-Module ScheduledTasks
  $oldTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($oldTask -and $oldTask.State -eq 'Running') { throw 'The existing backup task is still running. Wait until it finishes, then run this setup again.' }
  New-Item -ItemType Directory -Force -Path $scheduleRoot | Out-Null
  if ($oldTask) {
    $oldXml = Export-ScheduledTask -TaskName $taskName
    $oldXml | Set-Content -LiteralPath (Join-Path $scheduleRoot ('previous-backup-task-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xml')) -Encoding Unicode
  }
  $trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 3 -At $firstRun
  $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\cmd.exe" -Argument $arguments -WorkingDirectory $projectRoot
  $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 3)
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Manara: verified encrypted database/books backup, source/APK and encrypted GitHub upload, plus text report. Every 3 days at 10:00 Damascus time.' -Force | Out-Null
  $task = Get-ScheduledTask -TaskName $taskName
  $info = Get-ScheduledTaskInfo -TaskName $taskName
  if ($task.Triggers.Count -ne 1 -or [int]$task.Triggers[0].DaysInterval -ne 3 -or $task.Actions.Arguments -ne $arguments) { throw 'The registered task did not match the requested schedule.' }
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $schedule = [ordered]@{ status='ACTIVE'; taskName=$taskName; registeredAt=[DateTimeOffset]::Now.ToString('o'); firstRun=$firstRun.ToString('o'); daysInterval=3; time='10:00'; timeZone='Asia/Damascus'; account=$account; textReports=(Join-Path ([string]$config.backupRoot) 'Reports'); requiresWindowsSignIn=$true }
  $schedule | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $scheduleRoot 'schedule.json') -Encoding UTF8
  Write-Host 'MANARA BACKUP SCHEDULE ACTIVE' -ForegroundColor Green
  Write-Host 'Every 3 days at 10:00 AM (Damascus). The previous backup task schedule was replaced, not duplicated.'
  Write-Host "Next run: $($info.NextRunTime.ToString('yyyy-MM-dd HH:mm'))"
  Write-Host "Text reports: $($schedule.textReports)"
  Write-Host 'Keep the PC on, connected to the internet, and signed in to this Windows account (locking the screen is OK).'
  Write-Host 'Missed runs start when the computer and signed-in account become available. No backup is started by this setup.'
  exit 0
} catch {
  Write-Host "SCHEDULE SETUP FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

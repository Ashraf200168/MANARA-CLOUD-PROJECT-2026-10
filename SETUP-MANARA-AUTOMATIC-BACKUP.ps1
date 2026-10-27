$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Manara Backup Setup'
$projectRoot = 'C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud'
$toolRoot = Join-Path $projectRoot '.tools\backup'
$privateRoot = Join-Path $toolRoot 'private'
$configPath = Join-Path $toolRoot 'backup-config.json'
$runnerPath = Join-Path $projectRoot 'RUN-MANARA-BACKUP.ps1'
$projectRef = 'zgzqoxxhiwrzxsgoqyyb'
$supabaseUrl = 'https://zgzqoxxhiwrzxsgoqyyb.supabase.co'
$dashboardUrl = "https://supabase.com/dashboard/project/$projectRef/settings/api-keys"

function Convert-SecureToPlain([Security.SecureString]$Value) {
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
  finally { if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) } }
}

try {
  Write-Host ''
  Write-Host 'MANARA CLOUD - AUTOMATIC ENCRYPTED BACKUP SETUP' -ForegroundColor Cyan
  Write-Host 'No mobile app update is required.'
  Write-Host ''
  New-Item -ItemType Directory -Path $toolRoot, $privateRoot -Force | Out-Null

  $oneDriveRoot = @($env:OneDrive, $env:OneDriveConsumer, (Join-Path $env:USERPROFILE 'OneDrive')) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
  if (-not $oneDriveRoot) { throw 'OneDrive folder was not found. Start OneDrive, then run this setup again.' }
  $backupRoot = Join-Path $oneDriveRoot 'Manara Cloud Backups'
  New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

  Write-Host 'Supabase API Keys will open in your browser.' -ForegroundColor Yellow
  Write-Host 'Copy the SECRET key (sb_secret_... or legacy service_role).'
  Write-Host 'Do not use the publishable key, and never send the secret in chat.'
  Start-Process $dashboardUrl
  $supabaseSecret = Read-Host 'Paste the Supabase SECRET key here (hidden)' -AsSecureString
  if ($supabaseSecret.Length -lt 20) { throw 'The Supabase secret key was empty or too short.' }

  Write-Host ''
  Write-Host 'Choose a backup password of at least 12 characters.' -ForegroundColor Yellow
  Write-Host 'Write it down offline. It is required to recover backups on another computer.'
  $backupPassword = Read-Host 'Backup password (hidden)' -AsSecureString
  $backupPasswordAgain = Read-Host 'Repeat backup password (hidden)' -AsSecureString
  if ($backupPassword.Length -lt 12) { throw 'Backup password must contain at least 12 characters.' }
  $first = Convert-SecureToPlain $backupPassword
  $second = Convert-SecureToPlain $backupPasswordAgain
  if ($first -cne $second) { throw 'The two backup passwords do not match.' }
  $first = $null
  $second = $null

  $supabaseSecret | ConvertFrom-SecureString | Set-Content -LiteralPath (Join-Path $privateRoot 'supabase-secret.dpapi') -Encoding ASCII
  $backupPassword | ConvertFrom-SecureString | Set-Content -LiteralPath (Join-Path $privateRoot 'backup-password.dpapi') -Encoding ASCII

  $nodeCommand = Get-Command node -ErrorAction Stop
  $config = [ordered]@{
    format = 'manara-backup-config-v1'
    supabaseUrl = $supabaseUrl
    projectRef = $projectRef
    backupRoot = $backupRoot
    nodePath = $nodeCommand.Source
    retentionCount = 10
    minimumIntervalHours = 70
    schedule = 'Daily check at 18:00 and at sign-in; backup runs when 70 hours have elapsed.'
  }
  $config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8

  $taskName = 'Manara Cloud Encrypted Backup'
  $taskArgument = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$runnerPath`""
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgument
  $daily = New-ScheduledTaskTrigger -Daily -At '18:00'
  $atLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($daily, $atLogon) -Settings $settings -Principal $principal -Description 'Encrypted Manara Supabase database and book backup. Runs when 70 hours elapsed; keeps 10 copies in OneDrive.' -Force | Out-Null

  Write-Host ''
  Write-Host 'Configuration saved securely. Running the first verified backup now...' -ForegroundColor Cyan
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runnerPath -Force
  if ($LASTEXITCODE -ne 0) { throw "The scheduled task was created, but the first backup failed. Read $toolRoot\backup.log" }

  Write-Host ''
  Write-Host 'AUTOMATIC BACKUP SETUP COMPLETED SUCCESSFULLY' -ForegroundColor Green
  Write-Host "Backups: $backupRoot"
  Write-Host 'Schedule: every three days, checked daily and at Windows sign-in.'
  Write-Host 'Retention: last 10 encrypted backups (about 30 days).'
}
catch {
  Write-Host ''
  Write-Host 'BACKUP SETUP FAILED' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host 'Keep this window open and send Codex only the error message. Never send a secret key or backup password.'
}
finally {
  Read-Host 'Press Enter to close'
}

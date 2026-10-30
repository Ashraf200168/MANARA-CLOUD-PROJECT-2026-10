function Get-ManaraNextBackupTime {
  param([DateTime]$Now = (Get-Date))
  $next = $Now.Date.AddHours(10)
  if ($next -le $Now) { $next = $next.AddDays(1) }
  return $next
}

function Format-ManaraBackupReport {
  param([Parameter(Mandatory = $true)]$State)
  $lines = @(
    'MANARA - BACKUP AND GITHUB REPORT',
    "Result: $($State.status)",
    "Started: $($State.startedAt)",
    "Finished: $($State.completedAt)",
    "App version: $($State.appVersion)"
  )
  if ($State.backup) {
    $lines += "Verified encrypted backup: $($State.backup.path)"
    $lines += "Backup size (bytes): $($State.backup.bytes)"
    $lines += "Backup SHA-256: $($State.backup.sha256)"
  } else { $lines += 'Verified new backup: NOT CONFIRMED' }
  $lines += "GitHub main verified commit: $($State.sourceCommit)"
  $lines += "GitHub encrypted-backup verified commit: $($State.encryptedBackupCommit)"
  if ($State.error) { $lines += "Error: $($State.error)" }
  if ($State.status -eq 'SUCCESS') {
    $lines += 'Database/books backup and both GitHub uploads verified successfully.'
  } else {
    $lines += 'The full operation did not complete. Existing successful backups are retained.'
  }
  return ($lines -join [Environment]::NewLine)
}

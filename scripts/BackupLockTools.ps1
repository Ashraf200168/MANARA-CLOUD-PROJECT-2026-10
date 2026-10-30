function Wait-ManaraBackupLock {
  param(
    [Parameter(Mandatory = $true)][Threading.Mutex]$Mutex,
    [ValidateRange(0, 3600)][int]$TimeoutSeconds = 0
  )
  $timer = [Diagnostics.Stopwatch]::StartNew()
  $nextNotice = 0
  while ($true) {
    try {
      if ($Mutex.WaitOne(0)) { return $true }
    } catch [Threading.AbandonedMutexException] {
      # Windows has granted ownership after the previous owner exited.
      return $true
    }
    if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) { return $false }
    if ($timer.Elapsed.TotalSeconds -ge $nextNotice) {
      Write-Host 'Another Manara backup is running. Waiting safely for it to finish...'
      $nextNotice = $timer.Elapsed.TotalSeconds + 30
    }
    Start-Sleep -Milliseconds 500
  }
}

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\BackupLockTools.ps1')
$name = 'Local\ManaraBackupLockTest-' + [Guid]::NewGuid().ToString('N')
$mutex = New-Object Threading.Mutex($false, $name)
$job = $null
$hasLock = $false
try {
  $hasLock = Wait-ManaraBackupLock -Mutex $mutex
  if (-not $hasLock) { throw 'An available mutex was not acquired.' }
  $mutex.ReleaseMutex()
  $hasLock = $false
  $job = Start-Job -ArgumentList $name -ScriptBlock {
    param($LockName)
    $held = New-Object Threading.Mutex($false, $LockName)
    $owned = $false
    try {
      $owned = $held.WaitOne(0)
      if (-not $owned) { throw 'Test could not acquire lock.' }
      Write-Output 'LOCKED'
      Start-Sleep -Seconds 4
    } finally {
      if ($owned) { $held.ReleaseMutex() }
      $held.Dispose()
    }
  }
  $ready = $false
  $deadline = [DateTime]::UtcNow.AddSeconds(20)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (@(Receive-Job $job -Keep) -contains 'LOCKED') { $ready = $true; break }
    Start-Sleep -Milliseconds 100
  }
  if (-not $ready) { throw 'Lock-holder test job did not become ready.' }
  if (Wait-ManaraBackupLock -Mutex $mutex -TimeoutSeconds 1) {
    $hasLock = $true
    throw 'A busy mutex was incorrectly acquired.'
  }
  $hasLock = Wait-ManaraBackupLock -Mutex $mutex -TimeoutSeconds 10
  if (-not $hasLock) { throw 'Waiting did not acquire the released mutex.' }
  Write-Output 'BACKUP LOCK TESTS PASSED: available, busy timeout, and wait then acquire.'
} finally {
  if ($hasLock) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
  if ($null -ne $job) { Stop-Job $job; Remove-Job $job }
}

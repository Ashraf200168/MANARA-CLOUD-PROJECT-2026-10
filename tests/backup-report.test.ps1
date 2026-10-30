$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\BackupReportTools.ps1')
foreach ($case in @(
  @{ Now=[DateTime]'2026-10-30T09:59:00'; Expected=[DateTime]'2026-10-30T10:00:00' },
  @{ Now=[DateTime]'2026-10-30T10:00:00'; Expected=[DateTime]'2026-10-31T10:00:00' },
  @{ Now=[DateTime]'2026-10-30T14:30:00'; Expected=[DateTime]'2026-10-31T10:00:00' }
)) {
  if ((Get-ManaraNextBackupTime -Now $case.Now) -ne $case.Expected) { throw 'First-run time regression.' }
}
$state = [ordered]@{ status='SUCCESS'; startedAt='2026-10-31T10:00:00+03:00'; completedAt='2026-10-31T10:10:00+03:00'; appVersion='1.5.1'; backup=@{path='example.mnbak';bytes=1234;sha256='ABC123'}; sourceCommit='SOURCE'; encryptedBackupCommit='ENCRYPTED'; error=$null }
$text = Format-ManaraBackupReport -State $state
foreach ($value in @('Result: SUCCESS','example.mnbak','ABC123','SOURCE','ENCRYPTED')) { if (-not $text.Contains($value)) { throw "Report field missing: $value" } }
$state.status='FAILED'; $state.backup=$null; $state.error='Network unavailable'; $state.sourceCommit=$null; $state.encryptedBackupCommit=$null
$text = Format-ManaraBackupReport -State $state
if (-not $text.Contains('NOT CONFIRMED') -or -not $text.Contains('Network unavailable') -or $text.Contains('both GitHub uploads verified successfully')) { throw 'Failure report incorrectly claims success.' }
Write-Output 'BACKUP SCHEDULE AND TEXT REPORT TESTS PASSED'

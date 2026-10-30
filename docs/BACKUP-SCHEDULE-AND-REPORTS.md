# Automatic backup and GitHub upload

Run `SCHEDULE-MANARA-BACKUP.cmd` once from the normal Windows account that owns the saved backup credentials. A successful setup prints `MANARA BACKUP SCHEDULE ACTIVE`.

The setup replaces the existing **Manara Cloud Encrypted Backup** task instead of adding a second backup schedule. It saves the old task definition under `.tools/github-update/` before replacing it. It does not change the separate full hands-off maintenance task, which can still repair a missing/stale backup.

- Every 3 calendar days, at **10:00 AM Damascus time**.
- First run is the next future 10:00 AM when setup is run. The preview command below shows it without registering anything.
- Runs `BACKUP-AND-UPLOAD-MANARA.cmd --scheduled`: the same backup/upload workflow without the interactive pause.
- Database, books, encrypted backup verification, sanitized source/documentation/APK upload to `main`, and verified encrypted snapshot upload to `encrypted-backup`.
- Uses the signed-in Windows account, not SYSTEM or the coding sandbox. No Windows password is collected and no existing backup credentials are changed.
- Requires internet, the existing project/runtime files, and previously authorized GitHub credentials. Scheduled Git commands fail rather than prompting for interactive login. Sign in manually and rerun if authorization expires.
- Keep the PC powered on and signed in; locking the screen is fine. Missed starts are allowed to run when the PC/account becomes available. It cannot run while powered off or signed out.
- A concurrent scheduled instance is ignored; the backup workflow waits up to 15 minutes if a separate database backup owns its lock.

## Text reports

Each completed success/failure writes a timestamped `.txt` report and `latest-report.txt` to:

1. `.tools/github-update/reports/` inside the project.
2. `Reports/` inside the configured backup folder (currently `C:\Users\shraf\OneDrive\Manara Cloud Backups\Reports`).

The report includes completion time, verified backup path/hash/size, confirmed GitHub commit IDs and any failure message. An unconfirmed upload is never reported as successful. Report files are local/private and ignored by public Git synchronization. Power loss or forced termination can prevent a final report; Windows Task Scheduler and `.tools/github-update/last-status.json` help diagnose an interrupted run. OneDrive synchronization itself is not verified by this workflow.

## Preview / tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File SCHEDULE-MANARA-BACKUP.ps1 -Preview
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/backup-report.test.ps1
```

Scheduling uses Windows [daily triggers with a three-day interval](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasktrigger?view=windowsserver2025-ps).

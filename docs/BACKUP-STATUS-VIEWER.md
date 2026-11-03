# Manara Backup Status

Open `release/Manara-Backup-Status.exe` on the Windows PC configured for Manara backups. It displays backup status and can start the existing backup/upload workflow on demand. It does not replace `Manara-Backup-Now.exe` or change the scheduled task.

## Back up now

Click **نسخ احتياطي الآن**, then confirm. The program starts `BACKUP-AND-UPLOAD-MANARA.ps1 -Scheduled` under the Windows account running the viewer, without a separate console or pause. It shows live output while the existing workflow exports/encrypts/verifies data and books and uploads the encrypted snapshot plus sanitized source/documentation/APK to GitHub. The existing workflow saves the text reports.

The window remains responsive and can be minimized. Starting another backup, changing project, and closing the viewer are blocked while its child backup process is active. The existing backup/upload mutex prevents concurrent duplicate operations; a busy exit is not shown as success. The viewer requires exit code zero **and a fresh successful upload record for the run** before displaying success, never an old successful record. It refreshes the list/report after completion and shows failures separately from previously successful snapshots.

Internet and the configured Windows account's protected backup credentials and cached GitHub authorization are required. If GitHub authorization has expired, the operation reports failure rather than prompting invisibly; sign in through the existing manual setup workflow. Clicking the button does not modify the automatic schedule. Opening the viewer by itself never starts a backup.

## What it shows

- Last successful encrypted backup and timestamp.
- Last combined backup/upload outcome and the recorded verification time for GitHub.
- List of local `.mnbak` files, dates, sizes, and checksum-check results.
- Expected next run calculated from the saved schedule; it explicitly does **not** confirm the live Windows Task Scheduler state.
- Latest combined text report, plus shortcuts to the report and backup folder.
- Select a downloaded `.mnbak` file, read its adjacent `.sha256.txt` file, or paste an expected SHA-256 and verify the bytes locally.

For status display, the viewer uses only nonsensitive configuration/status/report files. The viewer itself does not read DPAPI secrets, ask for the encryption password, decrypt student data, or contact Supabase/GitHub. **When you start a backup**, its child workflow uses the existing protected credentials and contacts Supabase/GitHub, just as the command file does. Green GitHub status means the workflow recorded a verified successful upload for the same backup hash; opening the viewer does not perform a fresh online check.

A matching SHA-256 confirms that the file matches its reference checksum. It does not by itself prove that the database can be restored. The existing backup runner separately verifies encryption by decrypting its newly created archive and comparing hashes. Keep the recovery password separately; this viewer does not store or recover it.

The EXE can be moved to another folder. If it cannot locate the project, use **تحديد المشروع** and choose `manara-cloud`. On another PC, **اختيار ملف نسخة** still permits checking a file/checksum without having a configured Manara project. Do not delete the actual project or backup files; they are not embedded in the EXE.

## Build / tests

Requires the .NET Framework provided by Windows and its C# compiler; no adjacent DLLs, .NET SDK, or Node.js are needed by the viewer.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File BUILD-MANARA-BACKUP-STATUS.ps1
```

The build runs checksum parsing, known SHA-256 hashing, schedule calculation, upload-status association, and fresh-versus-old success-record self-tests. It also launches isolated mock PowerShell scripts to check progress capture, the scheduled flag, and success/failure/busy exit codes without running a real backup. `--verify-latest <project-folder>` checks the latest actual local archive against its saved hash and checks that the local upload-success record matches it (exit 0 on success). All checks are read-only except temporary self-test data and the generated build/checksum files.

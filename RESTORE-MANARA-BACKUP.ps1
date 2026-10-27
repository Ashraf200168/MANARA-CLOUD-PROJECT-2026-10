param([string]$BackupFile)

$ErrorActionPreference = 'Stop'
$projectRoot = 'C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud'
$configPath = Join-Path $projectRoot '.tools\backup\backup-config.json'
if (-not (Test-Path -LiteralPath $configPath)) { throw 'Backup is not configured on this computer.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$backupRoot = [IO.Path]::GetFullPath([string]$config.backupRoot)
if (-not $BackupFile) {
  $BackupFile = (Get-ChildItem -LiteralPath $backupRoot -Filter 'manara-cloud-*.mnbak' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $BackupFile -or -not (Test-Path -LiteralPath $BackupFile)) { throw 'No encrypted Manara backup was found.' }

$restoreRoot = Join-Path $projectRoot 'outputs\restored-backups'
$name = [IO.Path]::GetFileNameWithoutExtension($BackupFile)
$destination = Join-Path $restoreRoot $name
$archive = Join-Path $restoreRoot "$name.tar.gz"
if (Test-Path -LiteralPath $destination) { throw "Restore destination already exists: $destination" }
New-Item -ItemType Directory -Path $restoreRoot -Force | Out-Null

Write-Host 'This creates a private decrypted recovery copy. Delete it securely when recovery is complete.' -ForegroundColor Yellow
$password = Read-Host 'Backup password' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
try {
  $env:MANARA_BACKUP_PASSPHRASE = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  & ([string]$config.nodePath) (Join-Path $projectRoot 'migration\decrypt-backup.mjs') $BackupFile $archive
  if ($LASTEXITCODE -ne 0) { throw 'Backup decryption or authentication failed.' }
  New-Item -ItemType Directory -Path $destination | Out-Null
  & tar -xzf $archive -C $destination --strip-components 1
  if ($LASTEXITCODE -ne 0) { throw 'Backup extraction failed.' }
  Remove-Item -LiteralPath $archive -Force
  Write-Host "Verified recovery files are ready: $destination" -ForegroundColor Green
}
finally {
  Remove-Item Env:MANARA_BACKUP_PASSPHRASE -ErrorAction SilentlyContinue
  if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

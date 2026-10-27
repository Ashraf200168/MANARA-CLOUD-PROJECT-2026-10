$ErrorActionPreference = 'Stop'
$projectRoot = 'C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud'
$exportPath = Join-Path $projectRoot 'imports\supabase-export-20261024-164843'
$env:SUPABASE_URL = 'https://zgzqoxxhiwrzxsgoqyyb.supabase.co'

Set-Location -LiteralPath $projectRoot
Write-Host 'Manara cloud data import' -ForegroundColor Cyan
Write-Host 'The current ngrok website will not be changed or stopped.'
Write-Host 'Paste the Supabase SECRET key below. It will stay hidden and will not be saved.'
$secureKey = Read-Host 'Supabase secret key' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)

try {
  $env:SUPABASE_SECRET_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  if ([string]::IsNullOrWhiteSpace($env:SUPABASE_SECRET_KEY)) {
    throw 'No secret key was entered.'
  }

  Write-Host "`n[1/2] Importing the verified live snapshot..." -ForegroundColor Yellow
  & node 'migration/import-supabase.mjs' $exportPath
  if ($LASTEXITCODE -ne 0) { throw "Import failed with exit code $LASTEXITCODE" }

  Write-Host "`n[2/2] Verifying every table and uploaded book..." -ForegroundColor Yellow
  & node 'migration/verify-supabase.mjs' $exportPath
  if ($LASTEXITCODE -ne 0) { throw "Verification failed with exit code $LASTEXITCODE" }

  Write-Host "`nDATA IMPORT AND VERIFICATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
  Write-Host 'Tell Codex: data import complete'
}
catch {
  Write-Host "`nDATA IMPORT FAILED" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host 'Keep this window open and send the error text to Codex.'
}
finally {
  Remove-Item Env:SUPABASE_SECRET_KEY -ErrorAction SilentlyContinue
  Remove-Item Env:SUPABASE_URL -ErrorAction SilentlyContinue
  if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
  Read-Host 'Press Enter to close'
}

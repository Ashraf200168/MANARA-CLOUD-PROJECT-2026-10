[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$BackupPath,

  [string]$RemoteUrl = 'https://github.com/Ashraf200168/MANARA-CLOUD-PROJECT-2026-10.git'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$branch = 'encrypted-backup'
$toolRoot = Join-Path $projectRoot '.tools\github-backup-publish'
$logPath = Join-Path $toolRoot 'publish.log'

function Write-UploadLog([string]$Message) {
  New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
  $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
  Write-Host $line
}

function Assert-ChildPath([string]$Path, [string]$Parent) {
  $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
  $resolvedParent = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
  if (-not $resolvedPath.StartsWith($resolvedParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe temporary path: $resolvedPath"
  }
}

try {
  $backup = Get-Item -LiteralPath $BackupPath -ErrorAction Stop
  if ($backup.Extension -ne '.mnbak') { throw 'Only an encrypted .mnbak file can be uploaded.' }
  if ($backup.Length -lt 1KB) { throw 'The encrypted backup is unexpectedly small.' }
  $hash = (Get-FileHash -LiteralPath $backup.FullName -Algorithm SHA256).Hash
  $hashFile = "$($backup.FullName).sha256.txt"
  if (Test-Path -LiteralPath $hashFile) {
    $recorded = ((Get-Content -LiteralPath $hashFile -Raw).Trim() -split '\s+')[0].ToUpperInvariant()
    if ($recorded -ne $hash) { throw 'The backup SHA-256 does not match its checksum file.' }
  }

  Get-Command git -ErrorAction Stop | Out-Null
  New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
  $workRoot = Join-Path $toolRoot (Get-Date -Format 'yyyyMMdd-HHmmss-ffff')
  Assert-ChildPath $workRoot $toolRoot
  New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

  & git -C $workRoot init -b $branch | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not initialise the backup publishing workspace.' }
  & git -C $workRoot remote add origin $RemoteUrl
  if ($LASTEXITCODE -ne 0) { throw 'Could not configure the GitHub remote.' }

  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $remoteOutput = & git -C $workRoot ls-remote --heads origin $branch 2>&1
  $remoteExit = $LASTEXITCODE
  $ErrorActionPreference = $savedPreference
  if ($remoteExit -ne 0) { throw "Could not authenticate to GitHub: $($remoteOutput -join ' ')" }
  $expected = ''
  $remoteLines = @($remoteOutput)
  if ($remoteLines.Count -gt 0) { $expected = (([string]$remoteLines[0]) -split '\s+')[0] }

  $publishedBackup = Join-Path $workRoot 'manara-cloud-latest.mnbak'
  $publishedHash = Join-Path $workRoot 'manara-cloud-latest.mnbak.sha256.txt'
  $metadataPath = Join-Path $workRoot 'backup-metadata.json'
  Copy-Item -LiteralPath $backup.FullName -Destination $publishedBackup -Force
  Set-Content -LiteralPath $publishedHash -Value "$hash  manara-cloud-latest.mnbak" -Encoding ASCII
  [ordered]@{
    format = 'manara-public-encrypted-backup-v1'
    sourceName = $backup.Name
    createdAt = $backup.LastWriteTimeUtc.ToString('o')
    publishedAt = [DateTimeOffset]::UtcNow.ToString('o')
    bytes = $backup.Length
    sha256 = $hash
    notice = 'Encrypted operational snapshot. The recovery passphrase is not stored in GitHub.'
  } | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding UTF8

  Set-Content -LiteralPath (Join-Path $workRoot 'README.md') -Encoding UTF8 -Value @'
# Manara encrypted backup

This branch contains only the newest encrypted `.mnbak` snapshot and its SHA-256 checksum. The recovery passphrase is never stored in GitHub. The branch is replaced on every successful backup so binary history does not grow without limit.
'@

  & git -C $workRoot add README.md backup-metadata.json manara-cloud-latest.mnbak manara-cloud-latest.mnbak.sha256.txt
  if ($LASTEXITCODE -ne 0) { throw 'Could not stage the encrypted backup.' }
  & git -C $workRoot commit -m "Publish encrypted Manara backup $($backup.Name)" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not commit the encrypted backup.' }

  $lease = if ($expected) { "--force-with-lease=refs/heads/$branch`:$expected" } else { "--force-with-lease=refs/heads/$branch`:" }
  & git -C $workRoot push $lease origin "HEAD:refs/heads/$branch"
  if ($LASTEXITCODE -ne 0) { throw 'Could not publish the encrypted backup.' }
  Write-UploadLog "ENCRYPTED BACKUP GITHUB UPLOAD SUCCESS: $($backup.Name)"
}
catch {
  Write-UploadLog "ENCRYPTED BACKUP GITHUB UPLOAD FAILED: $($_.Exception.Message)"
  exit 1
}
finally {
  if ($workRoot -and (Test-Path -LiteralPath $workRoot)) {
    Assert-ChildPath $workRoot $toolRoot
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

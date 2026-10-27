[CmdletBinding()]
param(
  [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$remoteUrl = 'https://github.com/Ashraf200168/MANARA-CLOUD-PROJECT-2026-10.git'
$releaseRoot = Join-Path $projectRoot 'release'
$releaseApk = Join-Path $releaseRoot 'Manara-App-v1.4.1-full-sheikh-exam-arm64.apk'
$releaseHash = "$releaseApk.sha256.txt"
$logRoot = Join-Path $projectRoot '.tools\github-public'
$logPath = Join-Path $logRoot 'publish.log'

function Write-PublishLog([string]$Message) {
  New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
  $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
  Write-Host $line
}

function Get-Sha256([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '') }
  finally { $algorithm.Dispose(); $stream.Dispose() }
}

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$GitArgs
  )
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & git -c "safe.directory=$projectRoot" -C $projectRoot @GitArgs 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $savedPreference
  if ($output) { $output | ForEach-Object { Write-Host ([string]$_) } }
  if ($exitCode -ne 0) {
    $details = ($output | ForEach-Object { [string]$_ }) -join "`n"
    throw "git $($GitArgs -join ' ') failed with exit code $exitCode`n$details"
  }
  return @($output)
}

function Update-ReleaseApk {
  New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
  $candidateRoots = @(
    [IO.Path]::GetFullPath((Join-Path $projectRoot '..\..\outputs')),
    (Join-Path $projectRoot 'outputs')
  ) | Select-Object -Unique
  $candidate = $candidateRoots |
    Where-Object { Test-Path -LiteralPath $_ } |
    ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter 'Manara-App-*.apk' -File -ErrorAction SilentlyContinue } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($candidate) {
    if (-not (Test-Path -LiteralPath $releaseApk) -or
        $candidate.LastWriteTimeUtc -gt (Get-Item -LiteralPath $releaseApk).LastWriteTimeUtc -or
        $candidate.Length -ne (Get-Item -LiteralPath $releaseApk).Length) {
      Copy-Item -LiteralPath $candidate.FullName -Destination $releaseApk -Force
      Write-PublishLog "Release APK refreshed from $($candidate.FullName)"
    }
  }
  if (-not (Test-Path -LiteralPath $releaseApk)) { throw 'The curated release APK was not found.' }
  $hash = Get-Sha256 $releaseApk
  Set-Content -LiteralPath $releaseHash -Value "$hash  $([IO.Path]::GetFileName($releaseApk))" -Encoding ASCII
}

function Assert-PublicTreeSafe {
  $candidateFiles = @(& git -c "safe.directory=$projectRoot" -C $projectRoot ls-files --cached --others --exclude-standard)
  if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate Git files.' }
  $blockedPath = '(^|/)(imports|outputs|\.tools|node_modules|build|\.dart_tool|\.gradle|\.temp)/|(^|/)(local\.properties$|key\.properties$)|\.(db|sqlite3?|mnbak|jks|keystore|p12|pem|key)$'
  $blocked = @($candidateFiles | Where-Object {
    $normalized = $_ -replace '\\','/'
    ($normalized -match $blockedPath) -or
      (($normalized -match '(^|/)\.env($|\.)') -and ($normalized -notmatch '(^|/)\.env\.example$'))
  })
  if ($blocked.Count -gt 0) {
    throw "Blocked private/generated paths were about to be published:`n$($blocked -join "`n")"
  }

  $secretRegex = 'sb_secret_[A-Za-z0-9_-]{12,}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----'
  foreach ($relative in $candidateFiles) {
    $full = Join-Path $projectRoot $relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $full
    if ($item.Length -gt 5MB -or $item.Extension -in @('.apk','.png','.jpg','.jpeg','.gif','.ico','.pdf','.zip')) { continue }
    $text = Get-Content -LiteralPath $full -Raw -ErrorAction SilentlyContinue
    if ($text -and $text -match $secretRegex) { throw "A server secret/private key pattern was found in $relative" }
  }
}

try {
  Get-Command git -ErrorAction Stop | Out-Null
  Set-Location -LiteralPath $projectRoot
  Update-ReleaseApk

  if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.git'))) {
    & git -C $projectRoot init -b main
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialise the local Git repository.' }
  }

  $null = & git -c "safe.directory=$projectRoot" -C $projectRoot remote get-url origin 2>$null
  $originExists = ($LASTEXITCODE -eq 0)
  if ($originExists) { Invoke-Git -GitArgs @('remote', 'set-url', 'origin', $remoteUrl) | Out-Null }
  else { Invoke-Git -GitArgs @('remote', 'add', 'origin', $remoteUrl) | Out-Null }

  Assert-PublicTreeSafe
  Invoke-Git -GitArgs @('add', '-A') | Out-Null

  $staged = @(& git -c "safe.directory=$projectRoot" -C $projectRoot diff --cached --name-only)
  if ($LASTEXITCODE -ne 0) { throw 'Could not inspect staged files.' }
  if ($staged.Count -gt 0) {
    $message = 'Update Manara Cloud source, documentation, and Android release'
    Invoke-Git -GitArgs @('commit', '-m', $message) | Out-Null
    Write-PublishLog "Created commit for $($staged.Count) files."
  } else {
    Write-PublishLog 'No public source changes to commit.'
  }

  if (-not $NoPush) {
    $null = & git -c "safe.directory=$projectRoot" -C $projectRoot rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    $hasUpstream = ($LASTEXITCODE -eq 0)
    if (-not $hasUpstream) {
      $null = & git -c "safe.directory=$projectRoot" -C $projectRoot ls-remote --exit-code --heads origin main 2>$null
      $remoteMainExists = ($LASTEXITCODE -eq 0)
      if ($remoteMainExists) {
        Invoke-Git -GitArgs @('fetch', 'origin', 'main') | Out-Null
        $null = & git -c "safe.directory=$projectRoot" -C $projectRoot merge-base --is-ancestor origin/main HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
          Invoke-Git -GitArgs @('merge', '--allow-unrelated-histories', '-X', 'ours', '--no-edit', 'origin/main') | Out-Null
          Write-PublishLog 'Merged the repository initialization already present on GitHub.'
        }
      }
    }
    Invoke-Git -GitArgs @('push', '-u', 'origin', 'main') | Out-Null
    Write-PublishLog 'PUBLIC GITHUB SYNC SUCCESS'
  }
}
catch {
  Write-PublishLog "PUBLIC GITHUB SYNC FAILED: $($_.Exception.Message)"
  exit 1
}

function Get-ApkCertificateDigestFromOutput {
  param([Parameter(Mandatory = $true)][string[]]$OutputLines)
  # Android build-tools use both "Signer #1 certificate ..." and
  # "V2 Signer: certificate ...". Compare the certificate bytes, not the label.
  $text = $OutputLines -join "`n"
  $matches = [regex]::Matches($text, '(?im)^.*?certificate\s+SHA-256\s+digest:\s*([a-f0-9:]+)\s*$')
  $digests = @($matches | ForEach-Object { $_.Groups[1].Value.Replace(':', '').ToLowerInvariant() } | Select-Object -Unique)
  if ($digests.Count -ne 1 -or $digests[0] -notmatch '^[a-f0-9]{64}$') {
    throw 'Expected one valid APK signing certificate SHA-256 digest.'
  }
  return $digests[0]
}

function Get-VerifiedApkSigner {
  param(
    [Parameter(Mandatory = $true)][string]$ApkPath,
    [Parameter(Mandatory = $true)][string]$JavaExe,
    [Parameter(Mandatory = $true)][string]$SignerJar
  )
  $output = @(& $JavaExe -jar $SignerJar verify --print-certs $ApkPath 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed: $ApkPath" }
  return Get-ApkCertificateDigestFromOutput -OutputLines @($output | ForEach-Object { [string]$_ })
}

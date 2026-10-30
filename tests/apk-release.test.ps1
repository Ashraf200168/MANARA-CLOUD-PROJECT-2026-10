$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\ApkReleaseTools.ps1')
$digest = '3dd2ca34468baa56ec54077f9668013f50afa0a53391e3aeaf9395269a60f532'
foreach ($line in @("Signer #1 certificate SHA-256 digest: $digest", "V2 Signer: certificate SHA-256 digest: $digest", "V3.0 Signer: certificate SHA-256 digest: $($digest.ToUpperInvariant())")) {
  if ((Get-ApkCertificateDigestFromOutput -OutputLines @($line)) -ne $digest) { throw 'Certificate format regression.' }
}
foreach ($lines in @(@('No signing certificate'), @('Signer #1 certificate SHA-256 digest: abcd'), @("V2 Signer: certificate SHA-256 digest: $digest", ('Signer #2 certificate SHA-256 digest: ' + ('a' * 64))))) {
  $rejected = $false
  try { $null = Get-ApkCertificateDigestFromOutput -OutputLines $lines } catch { $rejected = $true }
  if (-not $rejected) { throw 'Invalid certificate output was accepted.' }
}
Write-Output 'APK CERTIFICATE PARSER TESTS PASSED'

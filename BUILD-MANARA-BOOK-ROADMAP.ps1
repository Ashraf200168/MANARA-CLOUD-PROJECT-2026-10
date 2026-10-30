[CmdletBinding()]
param([switch]$FinalizeOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$appRoot = Join-Path $projectRoot 'mobile\manara_app'
$releaseName = 'Manara-App-v1.5.1-question-editor-roadmap-arm64.apk'
$destination = Join-Path $projectRoot "release\$releaseName"
. (Join-Path $projectRoot 'scripts\ApkReleaseTools.ps1')

try {
  $flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
  $flutter = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\flutter\bin\flutter.bat' }
  if (-not (Test-Path -LiteralPath $flutter)) { throw 'Flutter was not found. Add the existing Flutter bin folder to PATH.' }
  $studioJava = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
  if (Test-Path -LiteralPath (Join-Path $studioJava 'bin\java.exe')) {
    $env:JAVA_HOME = $studioJava
    $env:Path = "$studioJava\bin;$env:Path"
  }
  # Use the original signing identity so the installed application can be upgraded.
  $projectAndroidHome = Join-Path $projectRoot '.android-home'
  $env:ANDROID_USER_HOME = if (Test-Path -LiteralPath (Join-Path $projectAndroidHome 'debug.keystore')) {
    $projectAndroidHome
  } else { Join-Path $env:USERPROFILE '.android' }
  $env:GRADLE_USER_HOME = Join-Path $env:USERPROFILE '.gradle'
  $originalKey = Join-Path $env:ANDROID_USER_HOME 'debug.keystore'
  if (-not (Test-Path -LiteralPath $originalKey)) {
    throw 'The original Android signing key was not found. Build on the original PC to preserve app update compatibility.'
  }
  Set-Location -LiteralPath $appRoot
  if (-not $FinalizeOnly) {
    Write-Host '[1/3] Checking the app...'
    & $flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    & $flutter test --no-pub test/book_roadmap_test.dart test/question_editor_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Roadmap or question editor screen tests failed.' }

    Write-Host '[2/3] Building Manara v1.5.1...'
    $startedAt = [DateTime]::UtcNow
    & $flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub --build-name 1.5.1 --build-number 8
    if ($LASTEXITCODE -ne 0) { throw 'Android APK build failed.' }
  }
  $builtApk = Join-Path $appRoot 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
  if (-not (Test-Path -LiteralPath $builtApk) -or (-not $FinalizeOnly -and (Get-Item -LiteralPath $builtApk).LastWriteTimeUtc -lt $startedAt.AddSeconds(-2))) {
    throw 'A new APK was not produced; the previous APK will not be relabelled.'
  }

  Write-Host '[3/3] Verifying signing identity and saving the release...'
  $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\sdk'
  if (-not (Test-Path -LiteralPath $sdkRoot)) { $sdkRoot = Join-Path $env:USERPROFILE 'AppData\Local\Android\sdk' }
  $buildTools = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory |
    Sort-Object Name -Descending |
    Where-Object { (Test-Path -LiteralPath (Join-Path $_.FullName 'lib\apksigner.jar')) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt2.exe')) } |
    Select-Object -First 1
  if (-not $buildTools) { throw 'Android apksigner.jar and aapt2.exe were not found.' }
  $signer = Join-Path $buildTools.FullName 'lib\apksigner.jar'
  $javaExe = (Get-Command java.exe -ErrorAction Stop).Source
  $metadata = @(& (Join-Path $buildTools.FullName 'aapt2.exe') dump badging $builtApk 2>&1) -join "`n"
  if ($LASTEXITCODE -ne 0 -or $metadata -notmatch "package: name='com.manara.manara_app' versionCode='2008' versionName='1.5.1'" -or $metadata -notmatch "native-code: 'arm64-v8a'") {
    throw 'The completed APK is not Manara v1.5.1 arm64 (version code 2008). Rebuild the latest source.'
  }
  $latestSource = @(Get-ChildItem -LiteralPath (Join-Path $appRoot 'lib') -Recurse -File; Get-Item -LiteralPath (Join-Path $appRoot 'pubspec.yaml')) |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
  if ($FinalizeOnly -and $latestSource.LastWriteTimeUtc -gt (Get-Item -LiteralPath $builtApk).LastWriteTimeUtc) {
    throw 'The app source changed after this APK was built. Run BUILD-MANARA-APP.cmd to include the latest changes.'
  }
  $verifyArgs = @{ JavaExe = $javaExe; SignerJar = $signer }
  $null = Get-VerifiedApkSigner -ApkPath $builtApk @verifyArgs
  $staging = Join-Path $projectRoot ('.tools\apk-release\' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $staging | Out-Null
  $signedApk = Join-Path $staging $releaseName
  & $javaExe -jar $signer sign --ks $originalKey --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --v4-signing-enabled false --out $signedApk $builtApk
  if ($LASTEXITCODE -ne 0) { throw 'APK signing with the original key failed.' }
  $newSigner = Get-VerifiedApkSigner -ApkPath $signedApk @verifyArgs
  $previousApk = Join-Path $projectRoot 'release\Manara-App-v1.4.1-full-sheikh-exam-arm64.apk'
  if (Test-Path -LiteralPath $previousApk) {
    if ($newSigner -ne (Get-VerifiedApkSigner -ApkPath $previousApk @verifyArgs)) {
      throw 'Signing identity differs from v1.4.1. The new release was not copied.'
    }
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $signedApk -Destination $destination -Force
  $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
  Set-Content -LiteralPath "$destination.sha256.txt" -Value "$hash  $releaseName" -Encoding ASCII
  Write-Host "BUILD AND SIGNATURE VERIFICATION SUCCESS: $destination"
  Write-Host 'Install this APK over the existing app. No uninstall is needed.'
  exit 0
} catch {
  Write-Host "BUILD FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

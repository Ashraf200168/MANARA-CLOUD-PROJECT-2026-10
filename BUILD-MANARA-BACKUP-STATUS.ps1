$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$framework = Split-Path $compiler
$source = Join-Path $projectRoot 'tools\manara-backup-status\Program.cs'
$output = Join-Path $projectRoot 'release\Manara-Backup-Status.exe'
$manifest = Join-Path $projectRoot 'tools\manara-backup-launcher\app.manifest'
$icon = Join-Path $projectRoot 'tools\manara-backup-status\manara.ico'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The Windows .NET Framework C# compiler was not found.' }
& (Join-Path $projectRoot 'scripts\Build-BackupStatusIcon.ps1') -SourcePath (Join-Path $projectRoot 'frontend\assets\reading-program-logo.jpg') -OutputPath $icon
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ "/out:$output" "/win32manifest:$manifest" "/win32icon:$icon" "/resource:$icon,Manara.Backup.Status.Icon" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "/reference:$(Join-Path $framework 'System.Web.Extensions.dll')" $source
if ($LASTEXITCODE -ne 0) { throw 'Status viewer compilation failed.' }
$test = Start-Process -FilePath $output -ArgumentList '--self-test' -Wait -PassThru -WindowStyle Hidden
if ($test.ExitCode -ne 0) { throw "Status viewer self-test failed with code $($test.ExitCode)." }
$hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
Set-Content -LiteralPath "$output.sha256.txt" -Value "$hash  $([IO.Path]::GetFileName($output))" -Encoding ASCII
Write-Output "BUILD AND SELF-TEST PASSED: $output"

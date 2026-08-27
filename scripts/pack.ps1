# 打 Android APK 与 Windows 发布目录。产物在 dist/。网络请求走国内镜像，见 scripts/china-mirrors.ps1。

param(
    [string]$FlutterPath = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

. (Join-Path $PSScriptRoot "china-mirrors.ps1")

$flutterBin = "D:\AI\tools\flutter\bin"
if ($env:Path -notlike "*$flutterBin*") {
    $env:Path = "$env:Path;$flutterBin"
}

if (-not $FlutterPath) {
    $candidate = Join-Path $flutterBin "flutter.bat"
    $FlutterPath = if (Test-Path $candidate) { $candidate } else { "flutter" }
}

$jdk17 = Join-Path $env:LOCALAPPDATA "Programs\Microsoft\jdk-17.0.10.7-hotspot"
if (Test-Path $jdk17) {
    $env:JAVA_HOME = $jdk17
    $env:Path = "$jdk17\bin;$env:Path"
    Write-Host "Using JAVA_HOME=$jdk17"
}

Install-ChengboGradleMirror -RepoRoot $root
Install-ChengboAndroidRepoCfg
Write-Host "Mirrors: pub=$env:PUB_HOSTED_URL sdk=$env:SDK_TEST_BASE_URL"

$version = "1.1.8"
if (Test-Path "pubspec.yaml") {
    $match = Select-String -Path "pubspec.yaml" -Pattern "^version:\s*([^\+]+)" | Select-Object -First 1
    if ($match) { $version = $match.Matches[0].Groups[1].Value.Trim() }
}

New-Item -ItemType Directory -Force -Path "dist" | Out-Null

Write-Host "Ensuring Android NDK from Tencent mirror..."
Install-ChengboAndroidNdk

if (Test-Path (Join-Path $root "android\key.properties")) {
    Write-Host "Android signing: release keystore (android/key.properties)"
} else {
    Write-Host "Android signing: debug (missing android/key.properties)"
}

$gradlew = Join-Path $root "android\gradlew.bat"
if (Test-Path $gradlew) {
    Write-Host "Stopping Gradle daemon..."
    & $gradlew --stop
    if ($LASTEXITCODE -ne 0) {
        Write-Host "gradlew --stop exited $LASTEXITCODE; continuing pack"
    }
}

Write-Host "Building Android APK..."
& $FlutterPath build apk --release
if ($LASTEXITCODE -ne 0) { throw "Android APK build failed" }
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "dist\chengbo-$version.apk" -Force

Write-Host "Building Windows zip..."
& $FlutterPath build windows --release
if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }

$winDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $winDir)) {
    $winDir = "build\windows\runner\Release"
}
$zipPath = "dist\chengbo-windows-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$winDir\*" -DestinationPath $zipPath -Force

Write-Host "Building Windows installer with Inno Setup..."
$iscc = "D:\PF\Inno Setup 7\ISCC.exe"
if (-not (Test-Path $iscc)) {
    $iscc = "ISCC.exe"
}
& $iscc (Join-Path $PSScriptRoot "chengbo-windows.iss")
if ($LASTEXITCODE -ne 0) { throw "Inno Setup build failed" }

Write-Host "Done."
Write-Host "  Android: dist\chengbo-$version.apk"
Write-Host "  Windows zip: $zipPath"
$exePath = "dist\chengbo-windows-$version.exe"
if (Test-Path $exePath) { Write-Host "  Windows installer: $exePath" }

# 在当前终端会话中加载 Flutter PATH、国内镜像，并运行命令
. "$PSScriptRoot\china-mirrors.ps1"

$flutterBin = "D:\AI\tools\flutter\bin"
if ($env:Path -notlike "*$flutterBin*") {
    $env:Path = "$env:Path;$flutterBin"
}

$jdk17 = Join-Path $env:LOCALAPPDATA "Programs\Microsoft\jdk-17.0.10.7-hotspot"
if (Test-Path $jdk17) {
    $env:JAVA_HOME = $jdk17
    $env:Path = "$jdk17\bin;$env:Path"
}

Install-ChengboGradleMirror -RepoRoot (Split-Path $PSScriptRoot -Parent)
Install-ChengboAndroidRepoCfg

Set-Location $PSScriptRoot\..

if ($args.Count -eq 0) {
    Write-Host "用法:"
    Write-Host "  .\scripts\flutter.ps1 run -d windows"
    Write-Host "  .\scripts\flutter.ps1 run -d android"
    Write-Host "  .\scripts\flutter.ps1 pub get"
    Write-Host "  .\scripts\flutter.ps1 doctor"
    exit 0
}

& "$flutterBin\flutter.bat" @args

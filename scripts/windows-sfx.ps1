# 打包 Windows 自解压安装包（不需要 Inno Setup / WiX）
# 依赖：7z.exe 已在本机 PATH 中（NanaZip 自带）
# 产物：dist\chengbo-windows-<version>.exe
#
# 用法：
#   .\scripts\windows-sfx.ps1
# 或从 pack.ps1 自动调用。

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

$version = "1.2.12"
if (Test-Path "pubspec.yaml") {
    $match = Select-String -Path "pubspec.yaml" -Pattern "^version:\s*([^\+]+)" | Select-Object -First 1
    if ($match) { $version = $match.Matches[0].Groups[1].Value.Trim() }
}

New-Item -ItemType Directory -Force -Path "dist" | Out-Null

# 1. 确保 Windows 发布目录存在
$winDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $winDir)) {
    $winDir = "build\windows\runner\Release"
}
if (-not (Test-Path $winDir)) {
    Write-Host "Windows release directory not found. Building..."
    & $FlutterPath build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }
}

# 2. 临时 staged 目录
$stamp = Get-Date -Format "yyyyMMddHHmmss"
$stageDir = Join-Path $env:TEMP "chengbo-windows-sfx-$stamp"
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

try {
    Write-Host "Staging release files to $stageDir ..."
    Copy-Item "$winDir\*" -Destination $stageDir -Recurse -Force

    # 3. 启动脚本（双击运行）
    $launchBat = @'
@echo off
cd /d "%~dp0"
start "" "Chengbo.exe"
'@
    [System.IO.File]::WriteAllText(
        (Join-Path $stageDir "launch.bat"),
        $launchBat,
        [System.Text.Encoding]::ASCII
    )

    # 4. 创建快捷方式脚本
    $shortcutPs1 = @'
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = [Environment]::GetFolderPath('StartMenu')
$installDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$shell = New-Object -COM WScript.Shell
$shortcut = $shell.CreateShortcut("$desktop\澄波.lnk")
$shortcut.TargetPath = Join-Path $installDir 'Chengbo.exe'
$shortcut.WorkingDirectory = $installDir
$shortcut.Description = '澄波 - 听国内广播与 RSS 播客'
$shortcut.Save()

$startMenuShortcut = $shell.CreateShortcut("$startMenu\澄波.lnk")
$startMenuShortcut.TargetPath = Join-Path $installDir 'Chengbo.exe'
$startMenuShortcut.WorkingDirectory = $installDir
$startMenuShortcut.Description = '澄波 - 听国内广播与 RSS 播客'
$startMenuShortcut.Save()

Write-Host ' shortcuts created.'
'@
    [System.IO.File]::WriteAllText(
        (Join-Path $stageDir "create-shortcuts.ps1"),
        $shortcutPs1,
        [System.Text.Encoding]::UTF8
    )

    # 5. 卸载脚本
    $uninstallPs1 = @'
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = [Environment]::GetFolderPath('StartMenu')
$installDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host 'Removing Chengbo shortcuts...'
taskkill /FI "IMAGENAME eq Chengbo.exe" /F | Out-Null

Remove-Item "$desktop\澄波.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$startMenu\澄波.lnk" -Force -ErrorAction SilentlyContinue

Write-Host 'Shortcuts removed.'
Write-Host "Please delete the folder manually: $installDir"
'@
    [System.IO.File]::WriteAllText(
        (Join-Path $stageDir "uninstall.ps1"),
        $uninstallPs1,
        [System.Text.Encoding]::UTF8
    )

    # 6. 说明文件
    $readme = @"
Chengbo $version
=====================================

1. Double-click launch.bat to start
2. Run create-shortcuts.ps1 to create desktop/start-menu shortcuts
3. Run uninstall.ps1 to remove shortcuts, then delete this folder

Data note:
- Listening data is stored locally; deleting this folder wipes it.
- Artwork cache path is in Settings.

Feedback: https://github.com/yourname/chengbo
"@
    [System.IO.File]::WriteAllText(
        (Join-Path $stageDir "README.txt"),
        $readme,
        [System.Text.Encoding]::UTF8
    )

    # 7. 7z SFX 配置
    $sfxConfig = @"
;!@Install@!UTF-8
Title=Chengbo $version
Directory=Chengbo
;!@InstallEnd@
"@
    $sfxConfigPath = Join-Path $env:TEMP "chengbo-sfx-config-$stamp.txt"
    [System.IO.File]::WriteAllText($sfxConfigPath, $sfxConfig, [System.Text.Encoding]::UTF8)

    # 8. 构建 SFX
    $exePath = "dist\chengbo-windows-$version.exe"
    if (Test-Path $exePath) { Remove-Item $exePath -Force }

    Write-Host "Building SFX installer..."
    & 7z.exe a -sfx -y -mx9 $exePath $sfxConfigPath "$stageDir\*"
    if ($LASTEXITCODE -ne 0) { throw "7z SFX build failed" }

    Write-Host "Installer built: $exePath"
}
finally {
    # 9. 清理临时文件
    if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
    if (Test-Path $sfxConfigPath) { Remove-Item $sfxConfigPath -Force }
}

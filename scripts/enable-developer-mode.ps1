# 启用 Windows 开发人员模式（Flutter 插件构建需要符号链接）
# 需要以管理员身份运行 PowerShell

Write-Host "正在启用开发人员模式..." -ForegroundColor Cyan

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "注册表写入失败，请手动开启：" -ForegroundColor Yellow
    Write-Host "  1. 运行: start ms-settings:developers"
    Write-Host "  2. 打开「开发人员模式」开关"
    Start-Process "ms-settings:developers"
    exit 1
}

Write-Host "开发人员模式已启用。" -ForegroundColor Green
Write-Host "请重新运行: .\scripts\flutter.ps1 pub get"
Write-Host "然后: .\scripts\flutter.ps1 run -d windows"

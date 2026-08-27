# 首次运行前，请确保已安装 Flutter SDK: https://docs.flutter.dev/get-started/install/windows
# 然后在项目根目录执行:

param(
    [string]$FlutterPath = "flutter"
)

Write-Host "正在补全 Flutter 平台文件..."
& $FlutterPath create . --platforms=android,windows --org com.chengbo --project-name chengbo
Write-Host "正在获取依赖..."
& $FlutterPath pub get
Write-Host "完成。运行: flutter run -d windows 或 flutter run -d android"

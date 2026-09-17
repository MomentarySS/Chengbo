# 打包与本机构建用的国内镜像。由 pack.ps1 / flutter.ps1 点源。
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"

# 替换 dl.google.com/android/repository/（SDK 目录表、NDK zip）
$env:SDK_TEST_BASE_URL = "https://mirrors.cloud.tencent.com/AndroidSDK/"

function Install-ChengboGradleMirror {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $initDir = Join-Path $env:USERPROFILE ".gradle\init.d"
    New-Item -ItemType Directory -Force -Path $initDir | Out-Null
    Copy-Item (Join-Path $RepoRoot "android\gradle\china-mirrors.init.gradle") `
        (Join-Path $initDir "chengbo-china-mirrors.gradle") -Force
}

function Install-ChengboAndroidRepoCfg {
    $androidDir = Join-Path $env:USERPROFILE ".android"
    New-Item -ItemType Directory -Force -Path $androidDir | Out-Null
    $cfg = Join-Path $androidDir "repositories.cfg"
    @(
        "### Chengbo: Android SDK package manifests via Tencent"
        "count=1"
        "enabled00=true"
        "disp00=Tencent AndroidSDK"
        "src00=https://mirrors.cloud.tencent.com/AndroidSDK/repository2-1.xml"
    ) | Set-Content -Path $cfg -Encoding ASCII
}

function Install-ChengboAndroidNdk {
    param(
        [string]$SdkDir = "",
        [string]$Revision = "27.0.12077973"
    )
    if (-not $SdkDir) {
        $SdkDir = Join-Path $env:LOCALAPPDATA "Android\sdk"
    }
    $ndkHome = Join-Path $SdkDir "ndk\$Revision"
    $marker = Join-Path $ndkHome "source.properties"
    if (Test-Path $marker) {
        Write-Host "NDK $Revision already installed."
        return
    }

    $url = "https://mirrors.cloud.tencent.com/AndroidSDK/android-ndk-r27-windows.zip"
    $zip = Join-Path $env:TEMP "android-ndk-r27-windows.zip"
    Write-Host "Downloading NDK $Revision from Tencent mirror..."
    curl.exe -L --retry 3 --retry-delay 2 -o $zip $url
    if ($LASTEXITCODE -ne 0) { throw "NDK download failed: $url" }

    $extractRoot = Join-Path $env:TEMP "chengbo-ndk-extract"
    if (Test-Path $extractRoot) { Remove-Item $extractRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    Write-Host "Extracting NDK..."
    Expand-Archive -Path $zip -DestinationPath $extractRoot -Force

    $unpacked = Get-ChildItem $extractRoot -Directory | Select-Object -First 1
    if (-not $unpacked) { throw "NDK zip did not contain a directory" }

    $ndkParent = Split-Path $ndkHome -Parent
    New-Item -ItemType Directory -Force -Path $ndkParent | Out-Null
    if (Test-Path $ndkHome) { Remove-Item $ndkHome -Recurse -Force }
    Move-Item $unpacked.FullName $ndkHome
    Write-Host "NDK installed to $ndkHome"
}

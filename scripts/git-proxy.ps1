# Detect the local proxy port, then run git / gh through it.
#
# The port moves when Clash Verge (or any other proxy) is reconfigured, so never
# hardcode it - the 7900 that older notes mentioned stopped working that way.
#
#   .\scripts\git-proxy.ps1 git push
#   .\scripts\git-proxy.ps1 git ls-remote --heads origin
#   .\scripts\git-proxy.ps1 gh pr view 11
#
# Detection order:
#   1. TCP ports that a proxy process is listening on (verge-mihomo / mihomo /
#      clash / v2ray / ...)
#   2. fallback scan of common ports: 7897 7890 7891 7900 10809 10808 1080 20171 33210
#   3. each listening candidate must open a real CONNECT tunnel to the host the
#      chosen tool needs (github.com for git, api.github.com for gh) and get an
#      answer back through it. Listening is not the same as being a proxy.
#
# Failure messages separate the two cases that matter: "nothing is proxying"
# versus "the proxy works but this host is unreachable through it" (dead node or
# a routing rule). It never silently falls back to a direct connection.
#
# This file is deliberately ASCII-only: the other scripts in this repo are UTF-8
# without a BOM, and PowerShell 5.1 decodes those as ANSI, where non-ASCII
# comment text can swallow the following character and break parsing.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('git', 'gh')]
    [string]$Tool,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$ToolArgs = @()
)

$ErrorActionPreference = 'Stop'
# PowerShell 5.1 may still default to TLS 1.0, which GitHub rejects.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-ProxyCandidatePorts {
    $names = @(
        'verge-mihomo', 'mihomo', 'clash', 'clash-verge', 'clash-verge-service',
        'clash-win64', 'v2ray', 'v2rayN', 'xray', 'sing-box', 'nekoray'
    )
    $listening = @()
    try {
        $proxyPids = @(Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $names -contains $_.ProcessName } |
            Select-Object -ExpandProperty Id)
        if ($proxyPids.Count -gt 0) {
            $listening = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                Where-Object { $proxyPids -contains $_.OwningProcess } |
                Select-Object -ExpandProperty LocalPort -Unique)
        }
    } catch {
        # Process/port lookup unavailable - fall back to the static list below.
    }
    $fallback = @(7897, 7890, 7891, 7900, 10809, 10808, 1080, 20171, 33210)
    return @($listening + $fallback | Where-Object { $_ -gt 0 } | Select-Object -Unique)
}

function Test-PortListening {
    param([int]$Port)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        return $client.ConnectAsync('127.0.0.1', $Port).Wait(600)
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

# Opens a raw CONNECT tunnel to host:443 and reports whether the proxy answered
# 2xx. This is the only reliable way to tell a real HTTP proxy apart from another
# local HTTP service: Clash's external controller answers a CONNECT with 404.
function Test-ConnectTunnel {
    param([int]$Port, [string]$TargetHost, [int]$TargetPort = 443)
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        if (-not $client.ConnectAsync('127.0.0.1', $Port).Wait(1500)) { return $false }
        $stream = $client.GetStream()
        $stream.ReadTimeout = 5000
        $stream.WriteTimeout = 5000
        $head = "CONNECT ${TargetHost}:${TargetPort} HTTP/1.1`r`nHost: ${TargetHost}:${TargetPort}`r`n`r`n"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($head)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()

        $deadline = (Get-Date).AddMilliseconds(5000)
        $sb = New-Object System.Text.StringBuilder
        $buffer = [byte[]]::new(256)
        while ((Get-Date) -lt $deadline) {
            if ($stream.DataAvailable) {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                [void]$sb.Append([System.Text.Encoding]::ASCII.GetString($buffer, 0, $read))
                if ($sb.ToString().Contains("`r`n")) { break }
            } else {
                Start-Sleep -Milliseconds 50
            }
        }
        $statusLine = ($sb.ToString() -split "`r`n")[0]
        return ($statusLine -match '^HTTP/\d(\.\d)?\s+2\d\d')
    } catch {
        return $false
    } finally {
        if ($client) { $client.Close() }
    }
}

# Returns the HTTP status, or 0 when the request never got a response.
function Get-StatusViaProxy {
    param([int]$Port, [string]$Url)
    $request = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Proxy = New-Object System.Net.WebProxy("http://127.0.0.1:$Port")
        $request.Method = 'GET'
        $request.Timeout = 8000
        $request.AllowAutoRedirect = $false
        $response = $request.GetResponse()
        $status = [int]$response.StatusCode
        $response.Close()
        return $status
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            return [int]$_.Exception.Response.StatusCode
        }
        return 0
    } catch {
        return 0
    } finally {
        if ($request) { $request.Abort() }
    }
}

# A working proxy answers the CONNECT with 2xx and opens the tunnel. The status
# the target returns afterwards must NOT decide this: api.github.com answers an
# unauthenticated GET with 403, and demanding 2xx/3xx there made gh look
# unroutable while git (github.com -> 200) kept working. The CONNECT reply is
# what separates a real proxy from a lookalike. Once the tunnel is up a real
# response is still required, which is what catches a dead node.
function Test-ProxyWorks {
    param([int]$Port, [string]$Url)
    $targetHost = ([Uri]$Url).Host
    if (-not (Test-ConnectTunnel -Port $Port -TargetHost $targetHost)) { return $false }
    return ((Get-StatusViaProxy -Port $Port -Url $Url) -ne 0)
}

$listening = @(Get-ProxyCandidatePorts | Where-Object { Test-PortListening -Port $_ })
if ($listening.Count -eq 0) {
    Write-Host 'No local proxy port is listening.' -ForegroundColor Red
    Write-Host 'Start Clash Verge (or another proxy) and retry.' -ForegroundColor Red
    exit 1
}

$target = if ($Tool -eq 'gh') { 'https://api.github.com/' } else { 'https://github.com/' }
$proxyPort = $null
foreach ($port in $listening) {
    if (Test-ProxyWorks -Port $port -Url $target) {
        $proxyPort = $port
        break
    }
}

if (-not $proxyPort) {
    Write-Host "Listening port(s): $($listening -join ', ') - none of them could tunnel to $target." -ForegroundColor Red
    $alive = @($listening | Where-Object { Test-ProxyWorks -Port $_ -Url 'https://www.gstatic.com/generate_204' })
    if ($alive.Count -gt 0) {
        Write-Host "The proxy on port $($alive[0]) does work, so the problem is the route to $target (dead node or a routing rule)." -ForegroundColor Red
    } else {
        Write-Host 'Nothing is proxying right now - the node may be down, or these are not HTTP proxy ports.' -ForegroundColor Red
    }
    exit 1
}

$proxy = "http://127.0.0.1:$proxyPort"
Write-Host "proxy: $proxy" -ForegroundColor DarkGray

switch ($Tool) {
    'git' {
        & git -c "http.proxy=$proxy" -c "https.proxy=$proxy" @ToolArgs
    }
    'gh' {
        $env:HTTP_PROXY = $proxy
        $env:HTTPS_PROXY = $proxy
        & gh @ToolArgs
    }
}

exit $LASTEXITCODE

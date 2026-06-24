param(
    [int]$Port = 8010,
    [string]$ListenAddress = '0.0.0.0',
    [string]$FirewallRuleName = 'CollectiveMemory8010'
)

# Must run elevated
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Error "This script must run as Administrator."
    exit 1
}

function Get-WslIp {
    $ip = (wsl.exe -e sh -lc "hostname -I | awk '{print \$1}'" 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($ip)) {
        throw "Could not detect WSL IP. Is WSL running?"
    }
    return $ip
}

$wslIp = Get-WslIp
Write-Host "WSL IP: $wslIp"

# Refresh portproxy rule idempotently
& netsh interface portproxy delete v4tov4 listenaddress=$ListenAddress listenport=$Port | Out-Null
& netsh interface portproxy add v4tov4 listenaddress=$ListenAddress listenport=$Port connectaddress=$wslIp connectport=$Port

# Refresh firewall rule idempotently
& netsh advfirewall firewall delete rule name="$FirewallRuleName" | Out-Null
& netsh advfirewall firewall add rule name="$FirewallRuleName" dir=in action=allow protocol=TCP localport=$Port

Write-Host "Updated portproxy + firewall for port $Port"
Write-Host "Current portproxy rules:"
& netsh interface portproxy show v4tov4

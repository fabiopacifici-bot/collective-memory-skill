param(
    [int]$Port = 8010,
    [string]$TaskName = 'OpenClaw-CollectiveMemory-Portproxy'
)

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Error "This script must run as Administrator."
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetScript = Join-Path $scriptDir 'ensure-collective-memory-portproxy.ps1'

if (-not (Test-Path $targetScript)) {
    throw "Missing script: $targetScript"
}

$action = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$targetScript`" -Port $Port"

# Create/replace task to run at startup with highest privileges
schtasks /Create /TN $TaskName /TR $action /SC ONSTART /RU SYSTEM /RL HIGHEST /F | Out-Null

Write-Host "Installed scheduled task: $TaskName"
Write-Host "Action: $action"
Write-Host "Trigger: ONSTART as SYSTEM"

# Run once immediately
schtasks /Run /TN $TaskName | Out-Null
Write-Host "Triggered task run now."

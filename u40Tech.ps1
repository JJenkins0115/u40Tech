# ============================================================
# 1. TOOL REPOSITORY DISCOVERY ENGINE (HYBRID / IRM SAFE)
# ============================================================

# Resolve parent directory safely regardless of execution mode:
# - Local Execution: Resolves from $PSScriptRoot or script file path.
# - Remote/IRM Execution: Fallbacks safely to $env:TEMP\U40Tech to avoid drive errors.
$ScriptRoot = $null

if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot) -and (Test-Path -Path $PSScriptRoot)) {
    # Preferred local path resolution
    $ScriptRoot = $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Definition -and (Test-Path -Path $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue)) {
    # Secondary resolution for called script files
    $ScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
else {
    # Fallback context when launched via 'irm <URL> | iex' or direct memory invocation
    $ScriptRoot = Join-Path -Path $env:TEMP -ChildPath "U40Tech"
}

# Construct tools directory path using resolved safe root
$ToolsDirectory = Join-Path -Path $ScriptRoot -ChildPath "Tools"

# Ensure directory exists on the system without throwing unhandled drive exceptions
if (-not (Test-Path -Path $ToolsDirectory)) {
    New-Item -ItemType Directory -Path $ToolsDirectory -Force | Out-Null
}

function Get-RepositoryTools {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if (Test-Path -Path $Path) {
        return Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse | Select-Object Name, FullName
    }
    return @()
}

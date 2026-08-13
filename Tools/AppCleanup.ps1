# ============================================================
# Script Name:   AppCleanup.ps1
# Path:          Tools/AppCleanup.ps1
# Description:   Interactive System Application Removal Utility
# ============================================================

[CmdletBinding()]
param(
    [switch]$SkipGPResult,
    [switch]$Force,
    [string]$LogFile = "$env:TEMP\AppCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

Set-StrictMode -Version 3.0

$script:Version      = "3.0"
$script:Apps         = @()
$script:SelectedApps = @()
$script:RemovedApps  = @()
$script:FailedApps   = @()

function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp  $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
    Write-Log "[INFO] $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
    Write-Log "[OK]   $Message"
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
    Write-Log "[WARN] $Message"
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    Write-Log "[FAIL] $Message"
}

function Get-InstalledApplications {
    Write-Info "Scanning system uninstall registry keys..."

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Applications = foreach ($Path in $RegistryPaths) {
        if (!(Test-Path ($Path -replace "\\\*$",""))) { continue }

        Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        ForEach-Object {
            $Guid = $null
            if ($_.PSChildName -match '^\{.*\}$') { $Guid = $_.PSChildName }

            [PSCustomObject]@{
                DisplayName          = $_.DisplayName
                DisplayVersion       = if ($_.DisplayVersion) { $_.DisplayVersion.Trim() } else { "" }
                Publisher            = $_.Publisher
                InstallDate          = $_.InstallDate
                QuietUninstallString = $_.QuietUninstallString
                UninstallString      = $_.UninstallString
                GUID                 = $Guid
            }
        }
    }

    $script:Apps = $Applications | Sort-Object DisplayName, DisplayVersion -Unique
    Write-Success "$($script:Apps.Count) installed application records retrieved."
    return $script:Apps
}

# Console Execution Entry point
Get-InstalledApplications | Select-Object DisplayName, DisplayVersion, Publisher | Format-Table -AutoSize

# ============================================================
# Script:        ChangeName.ps1
# Repository:    U40Tech / Tools
# Description:   Computer NetBIOS Name Modification Utility
# Compatibility: Integrated Host & Standalone Execution
# ============================================================

Set-StrictMode -Version 3.0

Write-Host "------------------------------------------------------------"
Write-Host " Tool: Change Computer Name"
Write-Host "------------------------------------------------------------"

$CurrentName = $env:COMPUTERNAME
Write-Host "[>] Current Computer Name: $CurrentName"

$NewName = Read-Host "Enter new computer name"

if ([string]::IsNullOrWhiteSpace($NewName)) {
    Write-Host "[-] Error: Computer name cannot be empty."
    exit 1
}

$NewName = $NewName.Trim()

if ($NewName.Length -gt 15) {
    Write-Host "[-] Error: NetBIOS computer name cannot exceed 15 characters."
    exit 1
}

if ($NewName -notmatch '^[a-zA-Z0-9-]+$') {
    Write-Host "[-] Error: Invalid character formatting detected."
    exit 1
}

if ($NewName.Equals($CurrentName, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "[!] Warning: Target name is identical to current computer name."
    exit 0
}

Write-Host "[>] Initiating rename operation: $CurrentName -> $NewName"

try {
    Rename-Computer -NewName $NewName -Force -ErrorAction Stop
    Write-Host "[+] Computer name updated successfully."
    Write-Host "[!] A system reboot is required for changes to take effect."
}
catch {
    Write-Host "[-] Operation Failed: $($_.Exception.Message)"
    exit 1
}

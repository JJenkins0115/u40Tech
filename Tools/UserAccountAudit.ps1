# ============================================================
# Script:        UserAccountAudit.ps1
# Repository:    U40Tech / Tools
# Description:   Local Security & Account Configuration Auditor
# Compatibility: PowerShell 5.1+, Windows 10/11
# ============================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

Write-Host "============================================================"
Write-Host "            U40Tech - Local User Account Audit              "
Write-Host "============================================================"
Write-Host ""

try {
    # 1. Enumerate Local Users
    Write-Host "[>] Auditing Local User Accounts..." -ForegroundColor Cyan
    $LocalUsers = Get-LocalUser

    foreach ($User in $LocalUsers) {
        $State = if ($User.Enabled) { "ENABLED" } else { "DISABLED" }
        $PassExp = if ($User.PasswordExpires) { $User.PasswordLastSet } else { "NEVER EXPIRES" }

        Write-Host "    Account: $($User.Name)"
        Write-Host "      State:            $State"
        Write-Host "      Password Set:     $PassExp"
        Write-Host "      Last Logon Time:  $($User.LastLogon)"
        Write-Host "    --------------------------------------------------------"
    }

    # 2. Local Administrators Group Membership Audit
    Write-Host ""
    Write-Host "[>] Checking Local Administrators Group Members..." -ForegroundColor Cyan
    $AdminMembers = Get-LocalGroupMember -Group "Administrators"

    foreach ($Member in $AdminMembers) {
        Write-Host "    [!] Elevated Member: $($Member.Name) ($($Member.ObjectClass))" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "[+] Local account audit completed successfully."
}
catch {
    Write-Host ""
    Write-Host "[-] Account Audit Error: $($_.Exception.Message)"
    exit 1
}

# ============================================================
# Script Name:   WindowsUpdate.ps1
# Path:          Tools/WindowsUpdate.ps1
# Description:   Non-Blocking Windows Update Engine with Progress
# Compatibility: Windows PowerShell 5.1+, VS Code Terminal Host
# ============================================================

[CmdletBinding()]
param(
    [switch]$AutoReboot,
    [switch]$IncludeMicrosoftUpdates = $true,
    [switch]$RunInBackgroundWithoutWaiting
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Enforce TLS 1.2 protocol for secure remote package management
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------
# 1. PREREQUISITE BOOTSTRAPPER & ENVIRONMENT VALIDATION
# ------------------------------------------------------------
function Initialize-UpdateEnvironment {
    [CmdletBinding()]
    param()

    $ModuleName  = "PSWindowsUpdate"
    $Identity    = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal   = New-Object Security.Principal.WindowsPrincipal($Identity)
    $IsAdmin     = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $TargetScope = if ($IsAdmin) { "AllUsers" } else { "CurrentUser" }

    Write-Host "[>] Validating package provider and module dependencies..." -ForegroundColor Cyan

    # Bootstrap NuGet provider silently to prevent interactive prompts
    if (-not (Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue)) {
        Write-Host "    [>] Installing NuGet Package Provider..." -ForegroundColor Gray
        Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.201" -Force -Confirm:$false -Scope $TargetScope -ErrorAction Stop | Out-Null
    }

    # Set PSGallery repository policy to trusted
    $GalleryRepo = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
    if ($null -ne $GalleryRepo -and $GalleryRepo.InstallationPolicy -ne "Trusted") {
        Write-Host "    [>] Setting PSGallery repository trust policy..." -ForegroundColor Gray
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
    }

    # Install PSWindowsUpdate module if absent
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "    [>] Installing $ModuleName module (Scope: $TargetScope)..." -ForegroundColor Yellow
        Install-Module -Name $ModuleName -Force -Confirm:$false -Scope $TargetScope -AllowClobber -ErrorAction Stop | Out-Null
    }

    # Import module into active runspace
    Import-Module -Name $ModuleName -Force -ErrorAction Stop
    Write-Host "    [+] Environment initialization complete." -ForegroundColor Green
}

# ------------------------------------------------------------
# 2. MAIN EXECUTION CONTROLLER
# ------------------------------------------------------------
try {
    # Phase 1: Environment Readiness
    Initialize-UpdateEnvironment

    # Phase 2: Enumeration Mode
    Write-Host "`n[>] Scanning system for available updates (Please wait)..." -ForegroundColor Cyan
    
    $ScanParams = @{
        ErrorAction = "Stop"
    }
    if ($IncludeMicrosoftUpdates) {
        $ScanParams["MicrosoftUpdate"] = $true
    }

    $AvailableUpdates = Get-WindowsUpdate @ScanParams

    if ($null -eq $AvailableUpdates -or $AvailableUpdates.Count -eq 0) {
        Write-Host "[+] System complete: No available updates found." -ForegroundColor Green
        return
    }

    # Display update summary table in terminal
    Write-Host "`n============================================================" -ForegroundColor White
    Write-Host "                AVAILABLE WINDOWS UPDATES                   " -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor White
    
    $AvailableUpdates | Select-Object @{Name="KB Article"; Expression={$_.KB}}, 
                                      @{Name="Size (MB)"; Expression={[Math]::Round($_.Size / 1MB, 2)}}, 
                                      @{Name="Title"; Expression={$_.Title}} | 
                        Format-Table -AutoSize

    Write-Host "[+] Found $($AvailableUpdates.Count) update(s) ready for processing." -ForegroundColor Green

    # Phase 3: Background Worker Preparation
    # Passing self-contained logic into background process context
    $BackgroundJobScript = {
        param(
            [bool]$EnableMicrosoftUpdate,
            [bool]$RebootAllowed
        )

        Set-StrictMode -Version 3.0
        $ErrorActionPreference = "Stop"

        # Force TLS 1.2 in secondary runspace
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Import-Module -Name "PSWindowsUpdate" -Force -ErrorAction Stop

        $ExecParams = @{
            AcceptAll   = $true
            Install     = $true
            ErrorAction = "Stop"
        }

        if ($EnableMicrosoftUpdate) {
            $ExecParams["MicrosoftUpdate"] = $true
        }

        if ($RebootAllowed) {
            $ExecParams["AutoReboot"] = $true
        } else {
            $ExecParams["IgnoreReboot"] = $true
        }

        # Run installation routine
        Get-WindowsUpdate @ExecParams
    }

    Write-Host "`n[>] Dispatching update installation engine to background process..." -ForegroundColor Cyan
    
    $UpdateJob = Start-Job -ScriptBlock $BackgroundJobScript -ArgumentList $IncludeMicrosoftUpdates.IsPresent, $AutoReboot.IsPresent -Name "U40Tech_WindowsUpdate_Job"

    Write-Host "[+] Background Job dispatched successfully (Job ID: $($UpdateJob.Id))." -ForegroundColor Green

    # Phase 4: Mode Branching (Non-blocking vs Monitored Progress)
    if ($RunInBackgroundWithoutWaiting) {
        Write-Host "[!] Background mode enabled. Terminal control returned immediately." -ForegroundColor Yellow
        Write-Host "[>] You can continue executing other scripts concurrently." -ForegroundColor Yellow
        Write-Host "[>] Check job state using: Get-Job -Id $($UpdateJob.Id) | Receive-Job" -ForegroundColor Gray
        return
    }

    # Phase 5: Managed Progress Monitoring Loop
    # Monitors job execution while allowing the user to break out safely via Ctrl+C without killing the underlying installation
    Write-Host "[>] Monitoring installation progress... (Press Ctrl+C at any time to return to prompt while updates finish in background)`n" -ForegroundColor Gray

    $ActivityName = "Applying $($AvailableUpdates.Count) Windows Update(s)"
    
    while ($UpdateJob.State -eq "Running") {
        # Fetch status logs from job streams
        $JobOutput = Receive-Job -Job $UpdateJob -ErrorAction SilentlyContinue

        if ($null -ne $JobOutput) {
            foreach ($Line in $JobOutput) {
                Write-Host "    [BACKGROUND] $Line" -ForegroundColor LightGray
            }
        }

        # Calculate rough runtime progress metrics
        $SecondsElapsed = [Math]::Round(((Get-Date) - $UpdateJob.PSBeginTime).TotalSeconds, 0)
        
        Write-Progress -Activity $ActivityName `
                       -Status "Processing background updates... ($SecondsElapsed seconds elapsed)" `
                       -PercentComplete -1

        Start-Sleep -Seconds 2
    }

    # Clear progress bar interface
    Write-Progress -Activity $ActivityName -Completed

    # Finalize Job State Output
    Write-Host "`n============================================================" -ForegroundColor White
    if ($UpdateJob.State -eq "Completed") {
        Write-Host "[+] All updates installed successfully." -ForegroundColor Green
        
        # Flush remaining streams
        Receive-Job -Job $UpdateJob -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "    [FINAL LOG] $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "[-] Background update job finished with state: $($UpdateJob.State)" -ForegroundColor Red
        Receive-Job -Job $UpdateJob -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "    [ERROR LOG] $_" -ForegroundColor Red
        }
    }
    Write-Host "============================================================" -ForegroundColor White

    # Cleanup finished job definition
    Remove-Job -Job $UpdateJob -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "[-] Execution halted: $($_.Exception.Message)" -ForegroundColor Red
    Write-Error $_
}

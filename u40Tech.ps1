# ============================================================
# Script Name:   u40Tech.ps1
# Repository:    JJenkins0115/u40Tech
# Description:   GitHub-Native Remote GUI Shell & Tool Runner
# Compatibility: PowerShell 5.1+, VS Code Terminal Host, Windows 10/11
# ============================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Enforce TLS 1.2 protocol for secure GitHub communications
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Clear residual runspace variables
Remove-Variable ActiveRunspace, ActivePipeline -ErrorAction SilentlyContinue

# Load GUI Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Elevation Verification
$Identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Privilege Check: Administrator rights required." -ForegroundColor Yellow
    Write-Host "[>] Requesting elevated process context..." -ForegroundColor Yellow

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/JJenkins0115/u40Tech/main/u40Tech.ps1' | iex`"" `
        -Verb RunAs

    exit
}

# ------------------------------------------------------------
# 1. GITHUB REPOSITORY DISCOVERY & CACHE ENGINE
# ------------------------------------------------------------

# Define remote repository parameters
$RepoOwner  = "JJenkins0115"
$RepoName   = "u40Tech"
$RepoBranch = "main"

# Establish local runtime cache directory inside $env:TEMP
$WorkspaceRoot = Join-Path -Path $env:TEMP -ChildPath "U40Tech"
$ToolsDirectory = Join-Path -Path $WorkspaceRoot -ChildPath "Tools"

if (-not (Test-Path -Path $ToolsDirectory)) {
    New-Item -ItemType Directory -Path $ToolsDirectory -Force | Out-Null
}

function Sync-GitHubRepositoryTools {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Branch,
        [string]$LocalTargetDir
    )

    Write-Host "[>] Interrogating GitHub Repository API ($Owner/$Repo)..." -ForegroundColor Cyan

    $ApiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/Tools?ref=$Branch"
    $UserAgent = "U40Tech-PowerShell-Host"

    try {
        # Query remote directory manifest via GitHub REST API
        $Response = Invoke-RestMethod -Uri $ApiUrl -Headers @{ "User-Agent" = $UserAgent } -Method Get -ErrorAction Stop
        
        # Filter response for PowerShell script assets
        $ScriptFiles = $Response | Where-Object { $_.type -eq "file" -and $_.name -like "*.ps1" }

        if (-not $ScriptFiles -or $ScriptFiles.Count -eq 0) {
            Write-Host "    [!] No script objects returned by API manifest." -ForegroundColor Yellow
            return
        }

        foreach ($FileObj in $ScriptFiles) {
            $DownloadUrl = $FileObj.download_url
            $FileName    = $FileObj.name
            $Destination = Join-Path -Path $LocalTargetDir -ChildPath $FileName

            Write-Host "    [>] Fetching: $FileName" -ForegroundColor Gray
            Invoke-RestMethod -Uri $DownloadUrl -OutFile $Destination -ErrorAction Stop
            
            # Remove Zone.Identifier tracking streams to allow seamless execution
            Unblock-File -Path $Destination -ErrorAction SilentlyContinue
            Write-Host "    [+] Cached: $FileName" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "    [-] GitHub API call failed ($($_.Exception.Message))." -ForegroundColor Red
        Write-Host "    [>] Falling back to direct raw file downloads..." -ForegroundColor Yellow

        # Fallback file array in the event of API rate-limiting or network blockades
        $FallbackFiles = @("ChangeName.ps1", "SystemDiagnostics.ps1", "NetFix.ps1", "UserAccountAudit.ps1")
        $RawBaseUrl    = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/Tools"

        foreach ($FileName in $FallbackFiles) {
            $FileUrl     = "$RawBaseUrl/$FileName"
            $Destination = Join-Path -Path $LocalTargetDir -ChildPath $FileName

            try {
                Invoke-RestMethod -Uri $FileUrl -OutFile $Destination -ErrorAction Stop
                Unblock-File -Path $Destination -ErrorAction SilentlyContinue
                Write-Host "    [+] Fallback Sync Succeeded: $FileName" -ForegroundColor Green
            }
            catch {
                Write-Host "    [-] Unable to resolve $FileName from remote source." -ForegroundColor Red
            }
        }
    }
}

# ------------------------------------------------------------
# 2. UNIFIED UI AND TERMINAL WINDOW FORM
# ------------------------------------------------------------
$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = "U40Tech - GitHub Unified Administration Console"
$MainForm.Size = New-Object System.Drawing.Size(1024, 680)
$MainForm.StartPosition = "CenterScreen"
$MainForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$MainForm.ForeColor = [System.Drawing.Color]::White
$MainForm.Font = New-Object System.Drawing.Font("Consolas", 10)

# Split Panel Layout
$SplitPanel = New-Object System.Windows.Forms.SplitContainer
$SplitPanel.Dock = "Fill"
$SplitPanel.SplitterDistance = 260
$SplitPanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$MainForm.Controls.Add($SplitPanel)

# Left Panel: Sidebar Header
$SidebarLabel = New-Object System.Windows.Forms.Label
$SidebarLabel.Text = "GITHUB REPO TOOLS"
$SidebarLabel.Dock = "Top"
$SidebarLabel.Height = 35
$SidebarLabel.TextAlign = "MiddleCenter"
$SidebarLabel.ForeColor = [System.Drawing.Color]::Cyan
$SidebarLabel.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$SplitPanel.Panel1.Controls.Add($SidebarLabel)

# Left Panel: Tools ListBox
$ToolListBox = New-Object System.Windows.Forms.ListBox
$ToolListBox.Dock = "Fill"
$ToolListBox.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 38)
$ToolListBox.ForeColor = [System.Drawing.Color]::Yellow
$ToolListBox.BorderStyle = "None"
$ToolListBox.DisplayMember = "Name"
$SplitPanel.Panel1.Controls.Add($ToolListBox)
$ToolListBox.BringToFront()

# Right Panel: Terminal Output Header
$ConsoleLabel = New-Object System.Windows.Forms.Label
$ConsoleLabel.Text = "INTEGRATED POWERSHELL TERMINAL OUTPUT"
$ConsoleLabel.Dock = "Top"
$ConsoleLabel.Height = 35
$ConsoleLabel.TextAlign = "MiddleLeft"
$ConsoleLabel.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$ConsoleLabel.ForeColor = [System.Drawing.Color]::LightGreen
$ConsoleLabel.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$SplitPanel.Panel2.Controls.Add($ConsoleLabel)

# Right Panel: Rich Text Terminal Box
$TerminalOutput = New-Object System.Windows.Forms.RichTextBox
$TerminalOutput.Dock = "Fill"
$TerminalOutput.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 12)
$TerminalOutput.ForeColor = [System.Drawing.Color]::FromArgb(204, 204, 204)
$TerminalOutput.Font = New-Object System.Drawing.Font("Consolas", 10)
$TerminalOutput.ReadOnly = $true
$TerminalOutput.BorderStyle = "None"
$SplitPanel.Panel2.Controls.Add($TerminalOutput)
$TerminalOutput.BringToFront()

# Bottom Control Action Bar
$ActionPanel = New-Object System.Windows.Forms.Panel
$ActionPanel.Dock = "Bottom"
$ActionPanel.Height = 50
$ActionPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$SplitPanel.Panel2.Controls.Add($ActionPanel)
$ActionPanel.BringToFront()

$RunButton = New-Object System.Windows.Forms.Button
$RunButton.Text = "Execute Selected Script"
$RunButton.Size = New-Object System.Drawing.Size(200, 32)
$RunButton.Location = New-Object System.Drawing.Point(10, 8)
$RunButton.FlatStyle = "Flat"
$RunButton.FlatAppearance.BorderSize = 1
$RunButton.FlatAppearance.BorderColor = [System.Drawing.Color]::Cyan
$RunButton.ForeColor = [System.Drawing.Color]::Cyan
$RunButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$ActionPanel.Controls.Add($RunButton)

$ClearButton = New-Object System.Windows.Forms.Button
$ClearButton.Text = "Clear Terminal"
$ClearButton.Size = New-Object System.Drawing.Size(140, 32)
$ClearButton.Location = New-Object System.Drawing.Point(220, 8)
$ClearButton.FlatStyle = "Flat"
$ClearButton.FlatAppearance.BorderSize = 1
$ClearButton.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
$ClearButton.ForeColor = [System.Drawing.Color]::LightGray
$ClearButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$ActionPanel.Controls.Add($ClearButton)

# ------------------------------------------------------------
# 3. TERMINAL LOGGING & ASYNC PROCESS EXECUTION ENGINE
# ------------------------------------------------------------

function Append-TerminalText {
    param(
        [string]$Message,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(204, 204, 204)
    )
    $TerminalOutput.SelectionStart = $TerminalOutput.TextLength
    $TerminalOutput.SelectionLength = 0
    $TerminalOutput.SelectionColor = $Color
    $TerminalOutput.AppendText("$Message`r`n")
    $TerminalOutput.ScrollToCaret()
}

function Invoke-SelectedScript {
    $Selected = $ToolListBox.SelectedItem
    if (-not $Selected) {
        Append-TerminalText "[-] Warning: Select a script from the tool menu first." ([System.Drawing.Color]::Orange)
        return
    }

    $ScriptPath = $Selected.FullName
    Append-TerminalText "`r`n============================================================" ([System.Drawing.Color]::Cyan)
    Append-TerminalText "[>] Launching Tool: $($Selected.Name)" ([System.Drawing.Color]::Cyan)
    Append-TerminalText "============================================================" ([System.Drawing.Color]::Cyan)

    $RunButton.Enabled = $false
    $ToolListBox.Enabled = $false

    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = "powershell.exe"
    $ProcessInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessInfo

    $OutEvent = {
        if (-not [string]::IsNullOrEmpty($Event.SourceEventArgs.Data)) {
            $MainForm.Invoke([Action[string, System.Drawing.Color]]{
                param($str, $clr) Append-TerminalText $str $clr
            }, $Event.SourceEventArgs.Data, [System.Drawing.Color]::LightGray)
        }
    }

    $ErrEvent = {
        if (-not [string]::IsNullOrEmpty($Event.SourceEventArgs.Data)) {
            $MainForm.Invoke([Action[string, System.Drawing.Color]]{
                param($str, $clr) Append-TerminalText $str $clr
            }, $Event.SourceEventArgs.Data, [System.Drawing.Color]::Coral)
        }
    }

    $null = Register-ObjectEvent -InputObject $Process -EventName "OutputDataReceived" -Action $OutEvent
    $null = Register-ObjectEvent -InputObject $Process -EventName "ErrorDataReceived" -Action $ErrEvent

    [void]$Process.Start()
    $Process.BeginOutputReadLine()
    $Process.BeginErrorReadLine()

    while (-not $Process.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }

    Append-TerminalText "[+] Execution complete. Process Exit Code: $($Process.ExitCode)" ([System.Drawing.Color]::LightGreen)

    $RunButton.Enabled = $true
    $ToolListBox.Enabled = $true
}

# ------------------------------------------------------------
# 4. EVENT BINDINGS & INITIALIZATION
# ------------------------------------------------------------
$RunButton.Add_Click({ Invoke-SelectedScript })
$ClearButton.Add_Click({ $TerminalOutput.Clear() })
$ToolListBox.Add_DoubleClick({ Invoke-SelectedScript })

$MainForm.Add_Load({
    Append-TerminalText "[+] U40Tech GitHub Host Engine Initialized." ([System.Drawing.Color]::LightGreen)

    # Perform dynamic sync with remote GitHub repository
    Sync-GitHubRepositoryTools -Owner $RepoOwner -Repo $RepoName -Branch $RepoBranch -LocalTargetDir $ToolsDirectory

    Append-TerminalText "[>] Local Tools Workspace: $ToolsDirectory" ([System.Drawing.Color]::Gray)

    $ToolsList = Get-ChildItem -Path $ToolsDirectory -Filter "*.ps1" -ErrorAction SilentlyContinue
    if (-not $ToolsList -or $ToolsList.Count -eq 0) {
        Append-TerminalText "[!] No .ps1 scripts found in local workspace." ([System.Drawing.Color]::Yellow)
    }
    else {
        foreach ($Tool in $ToolsList) {
            [void]$ToolListBox.Items.Add($Tool)
        }
        Append-TerminalText "[+] Successfully loaded $($ToolsList.Count) repository script(s)." ([System.Drawing.Color]::LightGreen)
    }
})

# Display Application Host
[void]$MainForm.ShowDialog()

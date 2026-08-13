# ============================================================
# Script Name:   u40Tech.ps1
# Repository:    JJenkins0115/u40Tech
# Description:   Integrated Graphical Shell & PowerShell Terminal Host
# Compatibility: PowerShell 5.1+, VS Code Terminal Host, Windows 10/11
# ============================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Force TLS 1.2 for secure GitHub communications on older PowerShell hosts
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
# 1. TOOL DISCOVERY & REMOTE SYNC ENGINE (IRM / LOCAL SAFE)
# ------------------------------------------------------------

# Determine execution context (Local vs. IRM Remote Memory)
$IsLocalScript = $false
$ScriptRoot    = $null

if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot) -and (Test-Path -Path $PSScriptRoot)) {
    $ScriptRoot    = $PSScriptRoot
    $IsLocalScript = $true
}
elseif ($MyInvocation.MyCommand.Path -and (Test-Path -Path $MyInvocation.MyCommand.Path)) {
    $ScriptRoot    = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $IsLocalScript = $true
}

if (-not $IsLocalScript) {
    # Executed via IRM / IEX in memory - fallback to local temp workspace
    $ScriptRoot = Join-Path -Path $env:TEMP -ChildPath "U40Tech"
}

$ToolsDirectory = Join-Path -Path $ScriptRoot -ChildPath "Tools"

if (-not (Test-Path -Path $ToolsDirectory)) {
    New-Item -ItemType Directory -Path $ToolsDirectory -Force | Out-Null
}

# Function to auto-download repository sub-scripts if launched remotely via IRM
function Sync-RemoteTools {
    param(
        [string]$TargetDir
    )
    
    Write-Host "[>] Remote IRM execution detected. Syncing toolkit scripts from GitHub..." -ForegroundColor Cyan

    $BaseRawUrl = "https://raw.githubusercontent.com/JJenkins0115/u40Tech/main/Tools"
    $ToolFiles  = @("ChangeName.ps1", "SystemDiagnostics.ps1", "NetFix.ps1")

    foreach ($File in $ToolFiles) {
        $Destination = Join-Path -Path $TargetDir -ChildPath $File
        $FileUrl     = "$BaseRawUrl/$File"

        try {
            Invoke-RestMethod -Uri $FileUrl -OutFile $Destination -ErrorAction Stop
            Write-Host "    [+] Downloaded: $File" -ForegroundColor Green
        }
        catch {
            Write-Host "    [-] Failed to sync $File from repository." -ForegroundColor Red
        }
    }
}

# ------------------------------------------------------------
# 2. UNIFIED UI AND TERMINAL WINDOW FORM
# ------------------------------------------------------------
$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = "U40Tech - IT Admin Unified Console Host"
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
$SidebarLabel.Text = "U40TECH TOOLKIT"
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
# 4. EVENT BINDINGS & FORM INITIALIZATION
# ------------------------------------------------------------
$RunButton.Add_Click({ Invoke-SelectedScript })
$ClearButton.Add_Click({ $TerminalOutput.Clear() })
$ToolListBox.Add_DoubleClick({ Invoke-SelectedScript })

$MainForm.Add_Load({
    Append-TerminalText "[+] U40Tech Host Engine Initialized." ([System.Drawing.Color]::LightGreen)

    if (-not $IsLocalScript) {
        Sync-RemoteTools -TargetDir $ToolsDirectory
    }

    Append-TerminalText "[>] Local Tools Directory: $ToolsDirectory" ([System.Drawing.Color]::Gray)

    $ToolsList = Get-ChildItem -Path $ToolsDirectory -Filter "*.ps1" -ErrorAction SilentlyContinue
    if (-not $ToolsList -or $ToolsList.Count -eq 0) {
        Append-TerminalText "[!] No .ps1 scripts discovered in 'Tools' directory." ([System.Drawing.Color]::Yellow)
    }
    else {
        foreach ($Tool in $ToolsList) {
            [void]$ToolListBox.Items.Add($Tool)
        }
        Append-TerminalText "[+] Loaded $($ToolsList.Count) script(s) into U40Tech." ([System.Drawing.Color]::LightGreen)
    }
})

# Display Application
[void]$MainForm.ShowDialog()

# ============================================================
# Script Name:   u40Tech.ps1
# Repository:    JJenkins0115/u40Tech
# Description:   GUI Administrative Suite with Persistent u40TechLog
# Compatibility: PowerShell 5.1+, VS Code Terminal Host, Windows 10/11
# ============================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Enforce TLS 1.2 protocol for secure remote package and API interactions
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Clear residual runspace variables
Remove-Variable ActiveRunspace, ActivePipeline -ErrorAction SilentlyContinue

# Load WinForms assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Privilege Verification
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
# 1. ENVIRONMENT & PERSISTENT LOG DIRECTORY CONFIGURATION
# ------------------------------------------------------------
$RepoOwner  = "JJenkins0115"
$RepoName   = "u40Tech"
$RepoBranch = "main"

# Ephemeral directory for downloaded script execution
$WorkspaceRoot  = Join-Path -Path $env:TEMP -ChildPath "U40Tech"
$ToolsDirectory = Join-Path -Path $WorkspaceRoot -ChildPath "Tools"

# Dedicated persistent directory for execution logs (survives UI purge)
$PersistentLogDir = Join-Path -Path $env:TEMP -ChildPath "u40TechLog"
$HistoryFile      = Join-Path -Path $PersistentLogDir -ChildPath "script_history.json"

# Ensure directories exist
if (-not (Test-Path -Path $ToolsDirectory)) {
    New-Item -ItemType Directory -Path $ToolsDirectory -Force | Out-Null
}
if (-not (Test-Path -Path $PersistentLogDir)) {
    New-Item -ItemType Directory -Path $PersistentLogDir -Force | Out-Null
}

# System Identity Inspection
$CompInfo     = Get-CimInstance Win32_ComputerSystem
$ComputerName = $env:COMPUTERNAME
$DomainName   = if ($CompInfo.PartOfDomain) { $CompInfo.Domain } else { "WORKGROUP ($($CompInfo.Domain))" }

# ------------------------------------------------------------
# 2. PERSISTENT EXECUTION LOGGING ENGINE
# ------------------------------------------------------------
function Get-ScriptHistoryMap {
    if (-not (Test-Path -Path $HistoryFile)) {
        return @{}
    }
    try {
        $RawJson = Get-Content -Path $HistoryFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($RawJson)) { return @{} }
        
        $JsonObject = $RawJson | ConvertFrom-Json
        $HistoryMap = @{}
        foreach ($Prop in $JsonObject.PSObject.Properties) {
            $HistoryMap[$Prop.Name] = $Prop.Value
        }
        return $HistoryMap
    }
    catch {
        return @{}
    }
}

function Set-ScriptLastRunTimestamp {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptName,
        [datetime]$Timestamp = (Get-Date)
    )

    # Retry loop to handle temporary file access locks during rapid I/O
    $MaxRetries = 3
    $RetryCount = 0
    $Written    = $false

    while (-not $Written -and $RetryCount -lt $MaxRetries) {
        try {
            if (-not (Test-Path -Path $PersistentLogDir)) {
                New-Item -ItemType Directory -Path $PersistentLogDir -Force | Out-Null
            }

            $HistoryMap = Get-ScriptHistoryMap
            $HistoryMap[$ScriptName] = $Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
            
            $JsonOutput = $HistoryMap | ConvertTo-Json -Depth 2
            Set-Content -Path $HistoryFile -Value $JsonOutput -Force -ErrorAction Stop
            $Written = $true
        }
        catch {
            $RetryCount++
            Start-Sleep -Milliseconds 100
        }
    }
}

function Sync-GitHubRepositoryTools {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Branch,
        [string]$LocalTargetDir
    )

    Write-Host "[>] Querying GitHub Repository API ($Owner/$Repo)..." -ForegroundColor Cyan

    $ApiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/Tools?ref=$Branch"
    $UserAgent = "U40Tech-PowerShell-Host"

    try {
        $Response = Invoke-RestMethod -Uri $ApiUrl -Headers @{ "User-Agent" = $UserAgent } -Method Get -ErrorAction Stop
        $ScriptFiles = $Response | Where-Object { $_.type -eq "file" -and $_.name -like "*.ps1" }

        if (-not $ScriptFiles) {
            Write-Host "[!] No script objects returned by API manifest." -ForegroundColor Yellow
            return
        }

        foreach ($FileObj in $ScriptFiles) {
            $DownloadUrl = $FileObj.download_url
            $FileName    = $FileObj.name
            $Destination = Join-Path -Path $LocalTargetDir -ChildPath $FileName

            Invoke-RestMethod -Uri $DownloadUrl -OutFile $Destination -ErrorAction Stop
            Unblock-File -Path $Destination -ErrorAction SilentlyContinue
            Write-Host "    [+] Downloaded and Cached: $FileName" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "    [-] GitHub API call failed ($($_.Exception.Message)). Using local cache if available." -ForegroundColor Red
    }
}

# ------------------------------------------------------------
# 3. MODERN GUI LAYOUT SYSTEM
# ------------------------------------------------------------
$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = "U40Tech - Unified Systems Management Console"
$MainForm.Size = New-Object System.Drawing.Size(1150, 720)
$MainForm.StartPosition = "CenterScreen"
$MainForm.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
$MainForm.ForeColor = [System.Drawing.Color]::White
$MainForm.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

# --- TOP SYSTEM HEADER PANEL ---
$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Dock = "Top"
$HeaderPanel.Height = 60
$HeaderPanel.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 35)
$MainForm.Controls.Add($HeaderPanel)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "U40TECH MANAGEMENT CONSOLE"
$TitleLabel.Location = New-Object System.Drawing.Point(15, 12)
$TitleLabel.Size = New-Object System.Drawing.Size(350, 20)
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$TitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$HeaderPanel.Controls.Add($TitleLabel)

$SubTitleLabel = New-Object System.Windows.Forms.Label
$SubTitleLabel.Text = "Host: $ComputerName   |   Domain/Scope: $DomainName"
$SubTitleLabel.Location = New-Object System.Drawing.Point(15, 33)
$SubTitleLabel.Size = New-Object System.Drawing.Size(600, 20)
$SubTitleLabel.Font = New-Object System.Drawing.Font("Consolas", 9)
$SubTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$HeaderPanel.Controls.Add($SubTitleLabel)

# Top Right Action Buttons
$RefreshButton = New-Object System.Windows.Forms.Button
$RefreshButton.Text = "Refresh Scripts"
$RefreshButton.Size = New-Object System.Drawing.Size(130, 34)
$RefreshButton.Location = New-Object System.Drawing.Point(850, 13)
$RefreshButton.FlatStyle = "Flat"
$RefreshButton.FlatAppearance.BorderSize = 1
$RefreshButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RefreshButton.ForeColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RefreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$HeaderPanel.Controls.Add($RefreshButton)

$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Text = "Exit & Purge"
$ExitButton.Size = New-Object System.Drawing.Size(130, 34)
$ExitButton.Location = New-Object System.Drawing.Point(995, 13)
$ExitButton.FlatStyle = "Flat"
$ExitButton.FlatAppearance.BorderSize = 1
$ExitButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255, 75, 75)
$ExitButton.ForeColor = [System.Drawing.Color]::FromArgb(255, 90, 90)
$ExitButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$HeaderPanel.Controls.Add($ExitButton)

# --- SPLIT CONTAINER FOR MAIN BODY ---
$SplitPanel = New-Object System.Windows.Forms.SplitContainer
$SplitPanel.Dock = "Fill"
$SplitPanel.SplitterDistance = 380
$SplitPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 42)
$MainForm.Controls.Add($SplitPanel)
$SplitPanel.BringToFront()

# Left Panel Header
$SidebarLabel = New-Object System.Windows.Forms.Label
$SidebarLabel.Text = "AVAILABLE TOOLS & LAST RUN TIME"
$SidebarLabel.Dock = "Top"
$SidebarLabel.Height = 35
$SidebarLabel.TextAlign = "MiddleCenter"
$SidebarLabel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$SidebarLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$SidebarLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$SplitPanel.Panel1.Controls.Add($SidebarLabel)

# Left Panel ListView
$ToolListView = New-Object System.Windows.Forms.ListView
$ToolListView.Dock = "Fill"
$ToolListView.View = [System.Windows.Forms.View]::Details
$ToolListView.FullRowSelect = $true
$ToolListView.GridLines = $true
$ToolListView.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 22)
$ToolListView.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$ToolListView.BorderStyle = "None"
$ToolListView.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::Nonclickable

[void]$ToolListView.Columns.Add("Script Name", 210)
[void]$ToolListView.Columns.Add("Last Executed", 150)

$SplitPanel.Panel1.Controls.Add($ToolListView)
$ToolListView.BringToFront()

# Right Panel Header
$ConsoleLabel = New-Object System.Windows.Forms.Label
$ConsoleLabel.Text = "EXECUTION OUTPUT TERMINAL"
$ConsoleLabel.Dock = "Top"
$ConsoleLabel.Height = 35
$ConsoleLabel.TextAlign = "MiddleLeft"
$ConsoleLabel.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$ConsoleLabel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$ConsoleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$ConsoleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$SplitPanel.Panel2.Controls.Add($ConsoleLabel)

# Right Panel Terminal Output Box
$TerminalOutput = New-Object System.Windows.Forms.RichTextBox
$TerminalOutput.Dock = "Fill"
$TerminalOutput.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 12)
$TerminalOutput.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
$TerminalOutput.Font = New-Object System.Drawing.Font("Consolas", 10)
$TerminalOutput.ReadOnly = $true
$TerminalOutput.BorderStyle = "None"
$SplitPanel.Panel2.Controls.Add($TerminalOutput)
$TerminalOutput.BringToFront()

# Bottom Action Panel
$ActionPanel = New-Object System.Windows.Forms.Panel
$ActionPanel.Dock = "Bottom"
$ActionPanel.Height = 50
$ActionPanel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$SplitPanel.Panel2.Controls.Add($ActionPanel)
$ActionPanel.BringToFront()

$RunButton = New-Object System.Windows.Forms.Button
$RunButton.Text = "Execute Selected Tool"
$RunButton.Size = New-Object System.Drawing.Size(200, 32)
$RunButton.Location = New-Object System.Drawing.Point(10, 9)
$RunButton.FlatStyle = "Flat"
$RunButton.FlatAppearance.BorderSize = 1
$RunButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RunButton.ForeColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RunButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$ActionPanel.Controls.Add($RunButton)

$ClearButton = New-Object System.Windows.Forms.Button
$ClearButton.Text = "Clear Console"
$ClearButton.Size = New-Object System.Drawing.Size(120, 32)
$ClearButton.Location = New-Object System.Drawing.Point(220, 9)
$ClearButton.FlatStyle = "Flat"
$ClearButton.FlatAppearance.BorderSize = 1
$ClearButton.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
$ClearButton.ForeColor = [System.Drawing.Color]::LightGray
$ClearButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$ActionPanel.Controls.Add($ClearButton)

# ------------------------------------------------------------
# 4. HELPER FUNCTIONS & RUNTIME CONTROLLERS
# ------------------------------------------------------------
function Append-TerminalText {
    param(
        [string]$Message,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(210, 210, 210)
    )
    $TerminalOutput.SelectionStart = $TerminalOutput.TextLength
    $TerminalOutput.SelectionLength = 0
    $TerminalOutput.SelectionColor = $Color
    $TerminalOutput.AppendText("$Message`r`n")
    $TerminalOutput.ScrollToCaret()
}

function Populate-ToolList {
    $ToolListView.Items.Clear()
    $ToolsList  = Get-ChildItem -Path $ToolsDirectory -Filter "*.ps1" -ErrorAction SilentlyContinue
    $HistoryMap = Get-ScriptHistoryMap

    if (-not $ToolsList) {
        Append-TerminalText "[!] No .ps1 tools found in workspace directory." ([System.Drawing.Color]::Yellow)
    }
    else {
        foreach ($Tool in $ToolsList) {
            $Item = New-Object System.Windows.Forms.ListViewItem($Tool.Name)
            $Item.Tag = $Tool.FullName

            $LastRun = if ($HistoryMap.ContainsKey($Tool.Name)) { $HistoryMap[$Tool.Name] } else { "Never" }
            [void]$Item.SubItems.Add($LastRun)

            [void]$ToolListView.Items.Add($Item)
        }
        Append-TerminalText "[+] Loaded $($ToolsList.Count) tool script(s). Execution log directory: $PersistentLogDir" ([System.Drawing.Color]::LightGreen)
    }
}

function Invoke-SelectedScript {
    if ($ToolListView.SelectedItems.Count -eq 0) {
        Append-TerminalText "[!] Select a tool script from the grid prior to execution." ([System.Drawing.Color]::Orange)
        return
    }

    $SelectedItem = $ToolListView.SelectedItems[0]
    $ScriptName   = $SelectedItem.Text
    $ScriptPath   = $SelectedItem.Tag

    Append-TerminalText "`r`n============================================================" ([System.Drawing.Color]::FromArgb(0, 212, 255))
    Append-TerminalText "[>] Executing: $ScriptName" ([System.Drawing.Color]::FromArgb(0, 212, 255))
    Append-TerminalText "============================================================" ([System.Drawing.Color]::FromArgb(0, 212, 255))

    $RunButton.Enabled     = $false
    $RefreshButton.Enabled = $false
    $ToolListView.Enabled  = $false

    # Update Log Timestamp
    $ExecutionTime = Get-Date
    Set-ScriptLastRunTimestamp -ScriptName $ScriptName -Timestamp $ExecutionTime
    $SelectedItem.SubItems[1].Text = $ExecutionTime.ToString("yyyy-MM-dd HH:mm:ss")

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
        if (-not [string]::IsNullOrWhiteSpace($Event.SourceEventArgs.Data)) {
            $MainForm.Invoke([Action[string, System.Drawing.Color]]{
                param($str, $clr) Append-TerminalText $str $clr
            }, $Event.SourceEventArgs.Data, [System.Drawing.Color]::LightGray)
        }
    }

    $ErrEvent = {
        if (-not [string]::IsNullOrWhiteSpace($Event.SourceEventArgs.Data)) {
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

    Append-TerminalText "[+] Tool execution finalized. Exit Code: $($Process.ExitCode)" ([System.Drawing.Color]::LightGreen)

    $RunButton.Enabled     = $true
    $RefreshButton.Enabled = $true
    $ToolListView.Enabled  = $true
}

function Exit-AndPurgeWorkspace {
    Append-TerminalText "[>] Terminating processes and purging temporary workspace context..." ([System.Drawing.Color]::Yellow)

    Get-Process -Name "Rapr" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # Safely purge temporary workspace while preserving $env:TEMP\u40TechLog
    try {
        if (Test-Path -Path $WorkspaceRoot) {
            Remove-Item -Path $WorkspaceRoot -Recurse -Force -ErrorAction Stop
            Write-Host "[+] Temp workspace successfully purged: $WorkspaceRoot" -ForegroundColor Green
            Write-Host "[+] Persistent log retained: $PersistentLogDir" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[-] Warning: Failed to wipe temp workspace directory ($($_.Exception.Message))" -ForegroundColor Red
    }

    $MainForm.Close()
}

# ------------------------------------------------------------
# 5. EVENT HANDLERS & INITIALIZATION
# ------------------------------------------------------------
$RunButton.Add_Click({ Invoke-SelectedScript })
$ClearButton.Add_Click({ $TerminalOutput.Clear() })
$ToolListView.Add_DoubleClick({ Invoke-SelectedScript })

$RefreshButton.Add_Click({
    Append-TerminalText "[>] Synchronizing script objects from GitHub repository..." ([System.Drawing.Color]::Cyan)
    Sync-GitHubRepositoryTools -Owner $RepoOwner -Repo $RepoName -Branch $RepoBranch -LocalTargetDir $ToolsDirectory
    Populate-ToolList
})

$ExitButton.Add_Click({ Exit-AndPurgeWorkspace })

$MainForm.Add_Load({
    Append-TerminalText "[+] U40Tech Console Initialized." ([System.Drawing.Color]::LightGreen)
    Sync-GitHubRepositoryTools -Owner $RepoOwner -Repo $RepoName -Branch $RepoBranch -LocalTargetDir $ToolsDirectory
    Populate-ToolList
})

# Display Form
[void]$MainForm.ShowDialog()

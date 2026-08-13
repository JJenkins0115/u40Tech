# ============================================================
# Script Name:   u40Tech.ps1
# Repository:    JJenkins0115/u40Tech
# Description:   Asynchronous GUI Administrative Console
# Environment:   PowerShell 5.1+, VS Code Terminal Host, Win 10/11
# ============================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Force TLS 1.2 protocol for secure remote transfers
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
# 1. GLOBAL PATHS & ENVIRONMENT CONFIGURATION
# ------------------------------------------------------------
$RepoOwner  = "JJenkins0115"
$RepoName   = "u40Tech"
$RepoBranch = "main"

# Workspace directory
$WorkspaceRoot  = Join-Path -Path $env:TEMP -ChildPath "U40Tech"
$ToolsDirectory = Join-Path -Path $WorkspaceRoot -ChildPath "Tools"

if (-not (Test-Path -Path $ToolsDirectory)) {
    New-Item -ItemType Directory -Path $ToolsDirectory -Force | Out-Null
}

# System Identity Inspection
$CompInfo     = Get-CimInstance Win32_ComputerSystem
$ComputerName = $env:COMPUTERNAME
$DomainName   = if ($CompInfo.PartOfDomain) { $CompInfo.Domain } else { "WORKGROUP ($($CompInfo.Domain))" }

# ------------------------------------------------------------
# 2. GUI LAYOUT SYSTEM
# ------------------------------------------------------------
$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = "U40Tech - Unified Systems Management Console"
$MainForm.Size = New-Object System.Drawing.Size(1200, 750)
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
$RefreshButton.Location = New-Object System.Drawing.Point(900, 13)
$RefreshButton.FlatStyle = "Flat"
$RefreshButton.FlatAppearance.BorderSize = 1
$RefreshButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RefreshButton.ForeColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RefreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$HeaderPanel.Controls.Add($RefreshButton)

$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Text = "Exit & Purge"
$ExitButton.Size = New-Object System.Drawing.Size(130, 34)
$ExitButton.Location = New-Object System.Drawing.Point(1045, 13)
$ExitButton.FlatStyle = "Flat"
$ExitButton.FlatAppearance.BorderSize = 1
$ExitButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255, 75, 75)
$ExitButton.ForeColor = [System.Drawing.Color]::FromArgb(255, 90, 90)
$ExitButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$HeaderPanel.Controls.Add($ExitButton)

# --- SPLIT CONTAINER FOR MAIN BODY ---
$SplitPanel = New-Object System.Windows.Forms.SplitContainer
$SplitPanel.Dock = "Fill"
$SplitPanel.SplitterDistance = 420
$SplitPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 42)
$MainForm.Controls.Add($SplitPanel)
$SplitPanel.BringToFront()

# Left Panel Header
$SidebarLabel = New-Object System.Windows.Forms.Label
$SidebarLabel.Text = "TOOL DIRECTORY (CATEGORIZED)"
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

[void]$ToolListView.Columns.Add("Script Name", 390)

# ListView Groups
$GroupInline   = New-Object System.Windows.Forms.ListViewGroup("Inline Tools (Main Terminal)", [System.Windows.Forms.HorizontalAlignment]::Left)
$GroupExternal = New-Object System.Windows.Forms.ListViewGroup("Second Window Tools (Standalone)", [System.Windows.Forms.HorizontalAlignment]::Left)
[void]$ToolListView.Groups.Add($GroupInline)
[void]$ToolListView.Groups.Add($GroupExternal)

$SplitPanel.Panel1.Controls.Add($ToolListView)
$ToolListView.BringToFront()

# Context Submenu
$ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$MenuItemRunInline = $ContextMenu.Items.Add("Run in Main Terminal (Inline)")
$MenuItemRunWindow = $ContextMenu.Items.Add("Launch in Second Window")
$ToolListView.ContextMenuStrip = $ContextMenu

# Right Panel Header
$ConsoleLabel = New-Object System.Windows.Forms.Label
$ConsoleLabel.Text = "MAIN TERMINAL OUTPUT"
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
$RunButton.Size = New-Object System.Drawing.Size(180, 32)
$RunButton.Location = New-Object System.Drawing.Point(10, 9)
$RunButton.FlatStyle = "Flat"
$RunButton.FlatAppearance.BorderSize = 1
$RunButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RunButton.ForeColor = [System.Drawing.Color]::FromArgb(0, 212, 255)
$RunButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$ActionPanel.Controls.Add($RunButton)

$RunWindowButton = New-Object System.Windows.Forms.Button
$RunWindowButton.Text = "Open in Second Window"
$RunWindowButton.Size = New-Object System.Drawing.Size(180, 32)
$RunWindowButton.Location = New-Object System.Drawing.Point(200, 9)
$RunWindowButton.FlatStyle = "Flat"
$RunWindowButton.FlatAppearance.BorderSize = 1
$RunWindowButton.FlatAppearance.BorderColor = [System.Drawing.Color]::MediumSpringGreen
$RunWindowButton.ForeColor = [System.Drawing.Color]::MediumSpringGreen
$RunWindowButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$ActionPanel.Controls.Add($RunWindowButton)

$ClearButton = New-Object System.Windows.Forms.Button
$ClearButton.Text = "Clear Console"
$ClearButton.Size = New-Object System.Drawing.Size(110, 32)
$ClearButton.Location = New-Object System.Drawing.Point(390, 9)
$ClearButton.FlatStyle = "Flat"
$ClearButton.FlatAppearance.BorderSize = 1
$ClearButton.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
$ClearButton.ForeColor = [System.Drawing.Color]::LightGray
$ClearButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$ActionPanel.Controls.Add($ClearButton)

# ------------------------------------------------------------
# 3. HELPER & EXECUTION FUNCTIONS
# ------------------------------------------------------------
function Append-TerminalText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()][string]$Message,
        [Parameter(Mandatory = $false, Position = 1)][System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(210, 210, 210)
    )

    if ($null -eq $MainForm -or $MainForm.IsDisposed -or -not $MainForm.IsHandleCreated) { return }

    [string]$SafeMessage = $Message
    [System.Drawing.Color]$SafeColor = $Color

    $null = $MainForm.BeginInvoke([Action]{
        try {
            $TerminalOutput.SelectionStart = $TerminalOutput.TextLength
            $TerminalOutput.SelectionLength = 0
            $TerminalOutput.SelectionColor = $SafeColor
            $TerminalOutput.AppendText("$SafeMessage`r`n")
            $TerminalOutput.ScrollToCaret()
        }
        catch {}
    })
}

function Populate-ToolList {
    [CmdletBinding()]
    param()

    $ToolListView.Items.Clear()
    $ToolsList = Get-ChildItem -Path $ToolsDirectory -Filter "*.ps1" -ErrorAction SilentlyContinue

    if (-not $ToolsList) {
        Append-TerminalText -Message "[!] No .ps1 tools found in workspace directory." -Color ([System.Drawing.Color]::Yellow)
        return
    }

    foreach ($Tool in $ToolsList) {
        $Item = New-Object System.Windows.Forms.ListViewItem($Tool.Name)
        $Item.Tag = $Tool.FullName

        $FirstLines = Get-Content -Path $Tool.FullName -TotalCount 5 -ErrorAction SilentlyContinue
        $IsSecondWindowMode = $FirstLines | Where-Object { $_ -like "*ExecutionMode:*SecondWindow*" }

        if ($IsSecondWindowMode) {
            $Item.Group = $ToolListView.Groups[1]
        } else {
            $Item.Group = $ToolListView.Groups[0]
        }

        [void]$ToolListView.Items.Add($Item)
    }
    Append-TerminalText -Message "[+] Loaded $($ToolsList.Count) tool script(s) across categories." -Color ([System.Drawing.Color]::LightGreen)
}

function Invoke-SelectedScriptInline {
    if ($ToolListView.SelectedItems.Count -eq 0) {
        Append-TerminalText -Message "[!] Select a tool script prior to execution." -Color ([System.Drawing.Color]::Orange)
        return
    }

    $SelectedItem = $ToolListView.SelectedItems[0]
    $ScriptName   = $SelectedItem.Text
    $ScriptPath   = $SelectedItem.Tag

    Append-TerminalText -Message "`r`n============================================================" -Color ([System.Drawing.Color]::FromArgb(0, 212, 255))
    Append-TerminalText -Message "[>] Executing Inline (Main Terminal): $ScriptName" -Color ([System.Drawing.Color]::FromArgb(0, 212, 255))
    Append-TerminalText -Message "============================================================" -Color ([System.Drawing.Color]::FromArgb(0, 212, 255))

    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = "powershell.exe"
    $ProcessInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessInfo
    $Process.EnableRaisingEvents = $true

    $null = Register-ObjectEvent -InputObject $Process -EventName "OutputDataReceived" -Action {
        param($evtSender, $evtArgs)
        if ($null -ne $evtArgs -and -not [string]::IsNullOrWhiteSpace($evtArgs.Data)) {
            Append-TerminalText -Message $evtArgs.Data -Color ([System.Drawing.Color]::LightGray)
        }
    }

    $null = Register-ObjectEvent -InputObject $Process -EventName "ErrorDataReceived" -Action {
        param($evtSender, $evtArgs)
        if ($null -ne $evtArgs -and -not [string]::IsNullOrWhiteSpace($evtArgs.Data)) {
            Append-TerminalText -Message $evtArgs.Data -Color ([System.Drawing.Color]::Coral)
        }
    }

    $null = Register-ObjectEvent -InputObject $Process -EventName "Exited" -Action {
        param($evtSender, $evtArgs)
        Append-TerminalText -Message "[+] Execution completed. Exit Code: $($evtSender.ExitCode)" -Color ([System.Drawing.Color]::LightGreen)
    }

    [void]$Process.Start()
    $Process.BeginOutputReadLine()
    $Process.BeginErrorReadLine()
}

function Invoke-SelectedScriptInSecondWindow {
    if ($ToolListView.SelectedItems.Count -eq 0) {
        Append-TerminalText -Message "[!] Select a tool script prior to execution." -Color ([System.Drawing.Color]::Orange)
        return
    }

    $SelectedItem = $ToolListView.SelectedItems[0]
    $ScriptName   = $SelectedItem.Text
    $ScriptPath   = $SelectedItem.Tag

    Append-TerminalText -Message "[>] Launching in dedicated process window: $ScriptName" -Color ([System.Drawing.Color]::MediumSpringGreen)

    Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$ScriptPath`""
}

function Sync-GitHubRepositoryToolsAsync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$Repo,

        [Parameter(Mandatory = $true)]
        [string]$Branch,

        [Parameter(Mandatory = $true)]
        [string]$LocalTargetDir
    )

    $RefreshButton.Enabled = $false
    $RunButton.Enabled     = $false

    Append-TerminalText -Message "[>] Initiating background repository sync..." -Color ([System.Drawing.Color]::Cyan)

    $ScriptBlock = {
        param($Owner, $Repo, $Branch, $LocalTargetDir, $MainForm, $TerminalControl)

        function Report-Progress {
            param([string]$Msg, [string]$ColorHex = "#D2D2D2")
            if ($null -ne $MainForm -and -not $MainForm.IsDisposed) {
                $null = $MainForm.BeginInvoke([Action]{
                    $TerminalControl.SelectionStart = $TerminalControl.TextLength
                    $TerminalControl.SelectionLength = 0
                    $TerminalControl.SelectionColor = [System.Drawing.ColorTranslator]::FromHtml($ColorHex)
                    $TerminalControl.AppendText("$Msg`r`n")
                    $TerminalControl.ScrollToCaret()
                })
            }
        }

        try {
            $ApiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/Tools?ref=$Branch"
            $Response = Invoke-RestMethod -Uri $ApiUrl -Headers @{ "User-Agent" = "U40Tech-Host" } -Method Get -ErrorAction Stop
            $ScriptFiles = $Response | Where-Object { $_.type -eq "file" -and $_.name -like "*.ps1" }

            foreach ($FileObj in $ScriptFiles) {
                $Destination = Join-Path -Path $LocalTargetDir -ChildPath $FileObj.name
                Invoke-RestMethod -Uri $FileObj.download_url -OutFile $Destination -ErrorAction Stop
                Unblock-File -Path $Destination -ErrorAction SilentlyContinue
                Report-Progress -Msg "    [+] Downloaded: $($FileObj.name)" -ColorHex "#90EE90"
            }
            Report-Progress -Msg "[+] Sync completed successfully." -ColorHex "#90EE90"
        }
        catch {
            Report-Progress -Msg "    [-] Sync failed: $($_.Exception.Message)" -ColorHex "#FF6347"
        }
    }

    # Create background PowerShell runspace
    $PowerShell = [powershell]::Create()
    $null = $PowerShell.AddScript($ScriptBlock)
    $null = $PowerShell.AddArgument($Owner)
    $null = $PowerShell.AddArgument($Repo)
    $null = $PowerShell.AddArgument($Branch)
    $null = $PowerShell.AddArgument($LocalTargetDir)
    $null = $PowerShell.AddArgument($MainForm)
    $null = $PowerShell.AddArgument($TerminalOutput)

    $AsyncResultHandle = $PowerShell.BeginInvoke()

    # Configure polling timer
    $Timer = New-Object System.Windows.Forms.Timer
    $Timer.Interval = 200

    # Store handles in Tag dictionary to prevent dynamic scope lookup failures
    $Timer.Tag = @{
        PowerShell    = $PowerShell
        AsyncResult   = $AsyncResultHandle
        RefreshButton = $RefreshButton
        RunButton     = $RunButton
    }

    # Strict-mode compliant delegate callback using param($sender, $e)
    $Timer.Add_Tick({
        param($sender, $e)

        $TimerObj = [System.Windows.Forms.Timer]$sender
        $State    = [hashtable]$TimerObj.Tag

        if ($State.AsyncResult.IsCompleted) {
            # Stop timer immediately to prevent re-entrant ticks
            $TimerObj.Stop()
            $TimerObj.Dispose()

            try {
                $null = $State.PowerShell.EndInvoke($State.AsyncResult)
            }
            catch {
                Append-TerminalText -Message "[-] Runspace completion error: $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
            }
            finally {
                $State.PowerShell.Dispose()

                # Re-enable UI controls safely
                $State.RefreshButton.Enabled = $true
                $State.RunButton.Enabled     = $true

                Populate-ToolList
            }
        }
    })

    $Timer.Start()
}

function Exit-AndPurgeWorkspace {
    Append-TerminalText -Message "[>] Purging temporary workspace..." -Color ([System.Drawing.Color]::Yellow)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    try {
        if (Test-Path -Path $WorkspaceRoot) {
            Remove-Item -Path $WorkspaceRoot -Recurse -Force -ErrorAction Stop
        }
    }
    catch {}

    $MainForm.Close()
}

# ------------------------------------------------------------
# 4. EVENT BINDINGS
# ------------------------------------------------------------
$RunButton.Add_Click({ Invoke-SelectedScriptInline })
$RunWindowButton.Add_Click({ Invoke-SelectedScriptInSecondWindow })
$MenuItemRunInline.Add_Click({ Invoke-SelectedScriptInline })
$MenuItemRunWindow.Add_Click({ Invoke-SelectedScriptInSecondWindow })

$ClearButton.Add_Click({ $TerminalOutput.Clear() })

$ToolListView.Add_DoubleClick({
    if ($ToolListView.SelectedItems.Count -gt 0) {
        $Item = $ToolListView.SelectedItems[0]
        if ($Item.Group.Header -like "*Second Window*") {
            Invoke-SelectedScriptInSecondWindow
        } else {
            Invoke-SelectedScriptInline
        }
    }
})

$RefreshButton.Add_Click({
    Sync-GitHubRepositoryToolsAsync -Owner $RepoOwner -Repo $RepoName -Branch $RepoBranch -LocalTargetDir $ToolsDirectory
})

$ExitButton.Add_Click({ Exit-AndPurgeWorkspace })

$MainForm.Add_Load({
    Append-TerminalText -Message "[+] Console Initialized." -Color ([System.Drawing.Color]::LightGreen)
    Sync-GitHubRepositoryToolsAsync -Owner $RepoOwner -Repo $RepoName -Branch $RepoBranch -LocalTargetDir $ToolsDirectory
})

# Display Management Console
[void]$MainForm.ShowDialog()

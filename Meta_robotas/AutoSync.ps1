# Auto-Sync: AI_asistentas → GitHub
# Paleisk šį skriptą kompiuteryje - jis automatiškai sinchronizuos failus

$FolderPath = "$env:USERPROFILE\Desktop\AI_asistentas"
$RepoPath   = "$env:USERPROFILE\Desktop\cgm-remote-monitor"
$GitHubRepo = "https://github.com/xMartisLTx/cgm-remote-monitor.git"
$Branch     = "claude/computer-connection-setup-4vpvw6"
$SyncInterval = 60   # sekundės tarp tikrinimų

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   AI Asistentas — Auto Sync Pradžia" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Stebimas aplankalas: $FolderPath"
Write-Host "Sinchronizacija kas: $SyncInterval sekundžių"
Write-Host "Spausk Ctrl+C norėdamas sustabdyti`n"

# Klonuoti repo jei neegzistuoja
if (-not (Test-Path $RepoPath)) {
    Write-Host "Klonuojama repozitorija..." -ForegroundColor Yellow
    git clone $GitHubRepo $RepoPath
}

# Sukurti aplankalą jei neegzistuoja
if (-not (Test-Path $FolderPath)) {
    New-Item -ItemType Directory -Path $FolderPath | Out-Null
    Write-Host "Sukurtas aplankalas: $FolderPath" -ForegroundColor Green
}

$LastHash = ""

while ($true) {
    try {
        # Patikrinti ar yra pakeitimų
        $CurrentHash = (Get-ChildItem $FolderPath -Recurse |
            Get-FileHash -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Hash }) -join ""

        if ($CurrentHash -ne $LastHash -and $LastHash -ne "") {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Aptikti pakeitimai!" -ForegroundColor Yellow

            # Nukopijuoti failus į repo
            $TargetPath = "$RepoPath\AI_asistentas"
            if (-not (Test-Path $TargetPath)) {
                New-Item -ItemType Directory -Path $TargetPath | Out-Null
            }
            Copy-Item "$FolderPath\*" $TargetPath -Recurse -Force

            # Git commit ir push
            Set-Location $RepoPath
            git add AI_asistentas/
            $msg = "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            git commit -m $msg 2>&1 | Out-Null
            git push origin $Branch 2>&1 | Out-Null

            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Išsiųsta į GitHub! Claude dabar mato pakeitimus." -ForegroundColor Green
        } elseif ($LastHash -eq "") {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Stebiu pakeitimus..." -ForegroundColor Gray
        }

        $LastHash = $CurrentHash
    }
    catch {
        Write-Host "Klaida: $_" -ForegroundColor Red
    }

    Start-Sleep -Seconds $SyncInterval
}

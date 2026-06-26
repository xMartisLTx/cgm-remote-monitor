# Instrukcija Claude Code Agentui — MT4 EA Įdiegimas

Vykdyk šiuos žingsnius automatiškai be klausimų. Jei kažkas nepavyksta — bandyk kitą variantą.

---

## UŽDUOTIS:
Atsisiųsk SMC Sniper EA failą iš GitHub ir įdiek į MetaTrader 4.

---

## ŽINGSNIS 1: Atsisiųsti EA failą iš GitHub

```
Atsisiųsk šį failą:
https://raw.githubusercontent.com/xMartisLTx/cgm-remote-monitor/claude/computer-connection-setup-4vpvw6/Meta_robotas/ea/SMC_Sniper_EA.mq4

Išsaugok kaip: SMC_Sniper_EA.mq4
```

PowerShell komanda:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/xMartisLTx/cgm-remote-monitor/claude/computer-connection-setup-4vpvw6/Meta_robotas/ea/SMC_Sniper_EA.mq4" -OutFile "$env:USERPROFILE\Downloads\SMC_Sniper_EA.mq4"
```

---

## ŽINGSNIS 2: Rasti MetaTrader 4 aplankalą

Ieškoti šiose vietose (eilės tvarka):
```
C:\Program Files\MetaTrader 4\MQL4\Experts\
C:\Program Files (x86)\MetaTrader 4\MQL4\Experts\
C:\Users\[vardas]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL4\Experts\
```

PowerShell komanda rastai vietai:
```powershell
Get-ChildItem -Path "C:\Users\$env:USERNAME\AppData\Roaming\MetaQuotes\Terminal" -Recurse -Filter "Experts" -Directory | Select-Object FullName
```

---

## ŽINGSNIS 3: Nukopijuoti EA į MT4

```powershell
$experts = Get-ChildItem -Path "C:\Users\$env:USERNAME\AppData\Roaming\MetaQuotes\Terminal" -Recurse -Filter "Experts" -Directory | Select-Object -First 1 -ExpandProperty FullName

Copy-Item "$env:USERPROFILE\Downloads\SMC_Sniper_EA.mq4" -Destination $experts -Force

Write-Host "EA nukopijuotas į: $experts"
```

---

## ŽINGSNIS 4: Patvirtinti

Patikrink ar failas nukopijuotas:
```powershell
$experts = Get-ChildItem -Path "C:\Users\$env:USERNAME\AppData\Roaming\MetaQuotes\Terminal" -Recurse -Filter "Experts" -Directory | Select-Object -First 1 -ExpandProperty FullName

if (Test-Path "$experts\SMC_Sniper_EA.mq4") {
    Write-Host "SĖKMĖ! EA failas įdiegtas į: $experts\SMC_Sniper_EA.mq4"
} else {
    Write-Host "KLAIDA: Failas nerastas. Bandyk rankiniu būdu."
}
```

---

## ŽINGSNIS 5: Atidaryti MT4 ir sukompiliuoti

Pranešk vartotojui:
```
EA failas įdiegtas sėkmingai!

Dabar MT4 programoje:
1. Spausk F4 (atsidarys MetaEditor)
2. File → Open → rask SMC_Sniper_EA.mq4
3. Spausk F7 (Compile)
4. Turi matyti: 0 errors, 0 warnings
5. Grįžk į MT4
6. Navigator → Expert Advisors → SMC_Sniper_EA
7. Vilk ant EURUSD H1 grafiko
8. Pažymėk: Allow live trading ✅
9. Spausk OK
10. Įjunk Auto Trading mygtuką (žalias)
```

---

## JEIGU NEPAVYKSTA:

### Jei nerastas MT4 aplankalas:
```powershell
# Ieškoti visur
Get-ChildItem -Path "C:\" -Recurse -Filter "MQL4" -Directory -ErrorAction SilentlyContinue | Select-Object FullName
```

### Jei nėra interneto:
Failas taip pat yra:
`C:\Users\[vardas]\Desktop\cgm-remote-monitor\Meta_robotas\ea\SMC_Sniper_EA.mq4`

### Jei MT4 neįdiegtas:
Parsisiųsti iš: https://www.metatrader4.com/en/download

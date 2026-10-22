# Windows wrapper: runs refresh.sh with Git Bash. Needs Git for Windows + Python 3 on PATH.
$bash = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $bash)) { Write-Error "Git Bash not found. Install Git for Windows."; exit 1 }
& $bash "$PSScriptRoot/refresh.sh"

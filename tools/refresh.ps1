# Windows wrapper: runs refresh.sh with Git Bash. Needs Git for Windows + Python 3 on PATH.
# refresh.sh also regenerates the root DOCS.md support playbook from the refreshed mirror.
$bash = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $bash)) { Write-Error "Git Bash not found. Install Git for Windows."; exit 1 }
& $bash "$PSScriptRoot/refresh.sh"
# Safety net: refresh.sh already runs this on success. If it stopped early, still
# refresh DOCS.md from whatever is already mirrored in source/.
if ($LASTEXITCODE -ne 0 -and (Get-Command python -ErrorAction SilentlyContinue)) {
  Write-Warning "refresh.sh exited with code $LASTEXITCODE; refreshing DOCS.md from the existing mirror."
  & python (Join-Path $PSScriptRoot "..\tools\build_support_docs.py")
}

# One-click docs update on Windows.
#   .\tools\update-docs.ps1            refresh from RSG repos, rebuild, preview at http://127.0.0.1:8000
#   .\tools\update-docs.ps1 -NoRefresh just rebuild and preview your own edits
#   .\tools\update-docs.ps1 -Publish   also commit and push (GitHub then publishes the site)
param([switch]$NoRefresh, [switch]$Publish)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
if (-not (Get-Command mkdocs -ErrorAction SilentlyContinue)) { pip install mkdocs-material }
if (-not $NoRefresh) { & "$PSScriptRoot\refresh.ps1" }
python tools/build_docs.py
if ($Publish) {
  git add -A
  git commit -m "Update docs $(Get-Date -Format yyyy-MM-dd)"
  git push
  Write-Host "Pushed. The site rebuilds in about 2 minutes: https://rexshackgaming.github.io/rsg-redm-brain/"
} else {
  Write-Host "Preview at http://127.0.0.1:8000 (Ctrl+C to stop)"
  mkdocs serve
}

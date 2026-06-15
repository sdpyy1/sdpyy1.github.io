$msg = $args -join ' '
if ([string]::IsNullOrWhiteSpace($msg)) {
    Write-Host "用法: .\push.ps1 <commit message>" -ForegroundColor Yellow
    exit 1
}

Write-Host ">>> git add ." -ForegroundColor Cyan
git add .

Write-Host ">>> git commit -m `"$msg`"" -ForegroundColor Cyan
git commit -m "$msg"

Write-Host ">>> git pull --rebase" -ForegroundColor Cyan
git pull --rebase
if ($LASTEXITCODE -ne 0) {
    Write-Host "冲突！请手动解决后再 git push" -ForegroundColor Red
    exit 1
}

Write-Host ">>> git push" -ForegroundColor Cyan
git push
if ($LASTEXITCODE -eq 0) {
    Write-Host "Done!" -ForegroundColor Green
}

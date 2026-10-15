param(
  [Parameter(Mandatory = $true)][string]$Archive
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) { throw 'Archive not found' }
if ((git rev-parse --is-inside-work-tree) -ne 'true') { throw 'Run this from the root of a Git repository.' }
$root = (git rev-parse --show-toplevel).Trim()
if ((Resolve-Path '.').Path.TrimEnd('\','/') -ne (Resolve-Path $root).Path.TrimEnd('\','/')) {
  throw 'Run this script at the repository root.'
}
$remote = (git remote get-url origin).Trim()
if ($remote -notmatch 'tonykark1/credit-risk(?:\.git)?$') { throw "Unexpected Git remote: $remote" }
if ((git status --porcelain).Length -gt 0) { throw 'Working tree is not clean. Commit or stash changes first.' }
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Git fetch failed.' }
git switch sba-credit-risk-migration-20261015
if ($LASTEXITCODE -ne 0) {
  git switch --track origin/sba-credit-risk-migration-20261015
  if ($LASTEXITCODE -ne 0) { throw 'Cannot switch to migration branch.' }
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('sba-upload-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  Expand-Archive -LiteralPath (Resolve-Path $Archive).Path -DestinationPath $work
  if (-not (Test-Path (Join-Path $work 'data/loans.csv'))) { throw 'SBA data/loans.csv is missing from the archive.' }
  if (-not (Test-Path (Join-Path $work 'analysis.R'))) { throw 'SBA analysis.R is missing from the archive.' }
  $manifest = Get-Content -LiteralPath (Join-Path $work 'data/provenance.json') -Raw | ConvertFrom-Json
  $hash = (Get-FileHash -LiteralPath (Join-Path $work 'data/loans.csv') -Algorithm SHA256).Hash.ToLower()
  if ($hash -ne $manifest.curated_sha256.ToLower()) { throw 'Loan CSV checksum mismatch; aborting.' }
  Get-ChildItem -LiteralPath $root -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force
  Copy-Item -Path (Join-Path $work '*') -Destination $root -Recurse -Force
  Copy-Item -Path (Join-Path $work '.github') -Destination $root -Recurse -Force
  Copy-Item -Path (Join-Path $work '.gitignore') -Destination $root -Force
  git add -A
  if ($LASTEXITCODE -ne 0) { throw 'Git add failed.' }
  git commit -m 'Replace South German Credit exercise with SBA 112256-loan validation project'
  if ($LASTEXITCODE -ne 0) { throw 'Commit failed.' }
  git push -u origin sba-credit-risk-migration-20261015
  if ($LASTEXITCODE -ne 0) { throw 'Git push failed.' }
  Write-Host 'SBA project pushed. Review PR https://github.com/tonykark1/credit-risk/pull/1 and its GitHub Actions checks.'
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
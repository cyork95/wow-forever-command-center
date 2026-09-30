# Copies docs/wiki into the GitHub wiki repo and pushes it.
# CurseForge links to https://github.com/cyork95/wow-forever-command-center/wiki
# That site is a separate git repo, not a folder in this one.
$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo "docs\wiki"
$wikiUrl = "https://github.com/cyork95/wow-forever-command-center.wiki.git"
$wikiHome = "https://github.com/cyork95/wow-forever-command-center/wiki/_new"
$work = Join-Path ([System.IO.Path]::GetTempPath()) "dossier-wiki"

# The wiki git repo does not exist until someone saves the first page on GitHub.
gh api -X PATCH repos/cyork95/wow-forever-command-center -F has_wiki=true --jq ".has_wiki" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not turn on Wikis. Check that gh is signed in to cyork95/wow-forever-command-center."
}

if (-not (Test-Path $source)) {
    throw "Wiki source not found: $source"
}

$pages = @(Get-ChildItem -Path $source -Filter "*.md" -File)
if ($pages.Count -eq 0) {
    throw "No markdown pages in $source"
}

if (Test-Path $work) {
    Remove-Item -Recurse -Force $work
}

git clone $wikiUrl $work
$cloned = $LASTEXITCODE -eq 0

if (-not $cloned) {
    if (Test-Path $work) {
        Remove-Item -Recurse -Force $work
    }

    New-Item -ItemType Directory -Force -Path $work | Out-Null
    Push-Location $work
    git init -b master
    if ($LASTEXITCODE -ne 0) { throw "git init failed" }
    git remote add origin $wikiUrl
    Pop-Location
}

Get-ChildItem -Path $work -File | Remove-Item -Force
Copy-Item -Path (Join-Path $source "*.md") -Destination $work

Push-Location $work
try {
    git add -A
    if ($LASTEXITCODE -ne 0) { throw "git add failed" }

    $dirty = git status --porcelain
    if (-not $dirty) {
        Write-Host "Wiki is already up to date."
        return
    }

    git commit -m "Publish the Dossier player wiki."
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }

    git push -u origin HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "git push failed. GitHub creates the wiki repo only after the first page is saved in the browser. Open $wikiHome while signed in, save a page titled Home, then run this script again."
    }
}
finally {
    Pop-Location
}

Write-Host "Published https://github.com/cyork95/wow-forever-command-center/wiki"

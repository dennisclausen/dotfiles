# Isolated subprocess assertions. No real profile or local overrides are loaded.
param([string] $Repository, [string] $Work, [string] $ProfilePath)
$ErrorActionPreference = 'Stop'
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
$gitApplication = Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1
$PROFILE = [pscustomobject]@{ CurrentUserAllHosts = $ProfilePath }
# A semicolon is valid in the fixture home but separates PATH entries on Windows.
# Keep only the executable search directory outside that home.
$env:PATH = Join-Path (Split-Path -Parent $Work) 'profile-tools'
[void][IO.Directory]::CreateDirectory($env:PATH)
$local = Join-Path (Split-Path -Parent $ProfilePath) 'dotfiles.local.ps1'
[IO.File]::WriteAllText($local, '$global:DotfilesOverrideCount++; function global:customDotfilesTest { "local" }')
$global:DotfilesOverrideCount = 0
$beforePath = $env:PATH
$builtins = @{}; foreach ($name in @('ls', 'cat', 'cp', 'mv', 'gc', 'md', 'diff')) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { $builtins[$name] = $command.Definition }
}
function v { 'existing user editor' }
. $ProfilePath
. $ProfilePath
Assert ((v) -ceq 'existing user editor') 'Profile replaced existing user function'
Assert ($global:DotfilesOverrideCount -eq 1) 'Local override loaded more than once'
Assert ($global:ExistingProfileWasLoaded -eq 1) 'Existing profile customization did not run'
Assert ((customDotfilesTest) -eq 'local') 'Local override unavailable'
Assert ($env:PATH -ceq $beforePath) 'Profile changed PATH'
$global:LASTEXITCODE = 19
$plainPrompt = (prompt) -replace '\x1b\[[0-9;]*m', ''
Assert ($plainPrompt -like "* at * in *`n$ *" -and $plainPrompt -notlike '* on *') 'Prompt without Git is incorrect'
Assert ($LASTEXITCODE -eq 19) 'Prompt changed native exit status without Git'
foreach ($name in @('..', '...', '....', '.....', 'dl', 'll', 'l', 'la', 'lsd', 'g', 'ga', 'subsub', 'rgi', 'mkd', 'tmpd', 'fd', 'ffind', 'fode', 'cwd', 'croot')) {
    Assert ([bool](Get-Command $name -CommandType Function)) "Missing helper $name"
}
foreach ($name in $builtins.Keys) { Assert ((Get-Command $name).Definition -ceq $builtins[$name]) "Built-in changed: $name" }
Assert (-not (Get-Command prikey -ErrorAction SilentlyContinue)) 'Private key shortcut exists'
$listing = Join-Path $Work "listing [x] & quote's"
[void][IO.Directory]::CreateDirectory($listing)
[IO.File]::WriteAllText((Join-Path $listing 'file.txt'), 'test')
$hiddenFile = Join-Path $listing '.hidden'
[IO.File]::WriteAllText($hiddenFile, 'test')
if ($IsWindows) { [IO.File]::SetAttributes($hiddenFile, [IO.FileAttributes]::Hidden) }
$result = @(ll $listing)
Assert ($result.Count -eq 2 -and $result[0] -is [IO.FileInfo]) 'll fallback must return native objects including hidden files'
$missingFailed = $false
try { rgi 'missing' } catch { $missingFailed = $_ -like '*rg is required*' }
Assert $missingFailed 'Missing dependency did not produce useful diagnostic'

# Real application stubs prove argument forwarding without dependency installation.
function New-Stub([string] $Name, [string] $WindowsBody, [string] $UnixBody) {
    if ($IsWindows) { [IO.File]::WriteAllText((Join-Path $env:PATH "$Name.cmd"), "@echo off`r`n$WindowsBody`r`n") }
    else {
        $path = Join-Path $env:PATH $Name
        [IO.File]::WriteAllText($path, "#!/bin/sh`n$UnixBody`n")
        [IO.File]::SetUnixFileMode($path, [IO.UnixFileMode]'UserRead,UserWrite,UserExecute')
    }
}
New-Stub eza 'echo %*' 'printf "%s\n" "$@"'
$listingArgs = @(ll $listing)
if ($IsWindows) { Assert ($listingArgs.Count -eq 1 -and $listingArgs[0] -ceq "-la `"$listing`"") 'll eza argument boundaries changed' }
else { Assert ($listingArgs[0] -ceq '-la' -and $listingArgs[1] -ceq $listing) 'll eza argument boundaries changed' }
New-Stub git 'exit /b 23' 'exit 23'
g status
Assert ($LASTEXITCODE -eq 23) 'Git exit code lost at module boundary'
$nested = Join-Path $Work "new dir [x] & quote's"
mkd $nested
Assert ((Get-Location).Path -ceq $nested) 'mkd path handling'
..
Assert ((Get-Location).Path -ceq $Work) 'Navigation failed'
Write-Output 'PASS: repeated profile loading, local customization, built-ins, helpers, missing tools, ll fallback/eza, native exit codes'

# Real local Git repositories exercise branch/status parsing without global config.
$env:PATH = Split-Path -Parent $gitApplication.Source
$env:GIT_CONFIG_GLOBAL = Join-Path $Work 'no-global-gitconfig'
$env:GIT_CONFIG_NOSYSTEM = '1'
$promptRepo = Join-Path $Work 'prompt repo [x]'
& $gitApplication -c init.defaultBranch=prompt-test init --quiet $promptRepo
Assert ($LASTEXITCODE -eq 0) 'Prompt repository setup failed'
Set-Location -LiteralPath $promptRepo
$plainPrompt = (prompt) -replace '\x1b\[[0-9;]*m', ''
Assert ($plainPrompt -match ' on prompt-test\n\$ ') 'Unborn branch missing from prompt'
$file = Join-Path $promptRepo 'test.txt'
[IO.File]::WriteAllText($file, 'first')
Assert (((prompt) -replace '\x1b\[[0-9;]*m', '') -match 'prompt-test \[\?\]') 'Untracked prompt marker missing'
& $gitApplication add -- test.txt
Assert ($LASTEXITCODE -eq 0) 'Prompt staging setup failed'
Assert (((prompt) -replace '\x1b\[[0-9;]*m', '') -match 'prompt-test \[\+\]') 'Staged prompt marker missing'
& $gitApplication -c user.name=Test -c user.email=test@example.invalid -c core.hooksPath=disabled-hooks commit --quiet -m initial
Assert ($LASTEXITCODE -eq 0) 'Prompt commit setup failed'
[IO.File]::WriteAllText($file, 'second')
$index = Join-Path $promptRepo '.git/index'
$indexBefore = (Get-FileHash -LiteralPath $index).Hash
$indexTime = [IO.File]::GetLastWriteTimeUtc($index)
$global:LASTEXITCODE = 37
Assert (((prompt) -replace '\x1b\[[0-9;]*m', '') -match 'prompt-test \[!\]') 'Modified prompt marker missing'
Assert ($LASTEXITCODE -eq 37) 'Git prompt changed native exit status'
Assert ((Get-FileHash -LiteralPath $index).Hash -ceq $indexBefore -and
    [IO.File]::GetLastWriteTimeUtc($index) -eq $indexTime) 'Prompt modified Git index'
& $gitApplication -c user.name=Test -c user.email=test@example.invalid stash push --quiet
Assert ($LASTEXITCODE -eq 0) 'Prompt stash setup failed'
Assert (((prompt) -replace '\x1b\[[0-9;]*m', '') -match 'prompt-test \[\$\]') 'Stash prompt marker missing'
& $gitApplication checkout --quiet --detach
Assert ($LASTEXITCODE -eq 0) 'Detached prompt setup failed'
Assert (((prompt) -replace '\x1b\[[0-9;]*m', '') -match ' on [a-f0-9]{7} \[\$\]') 'Detached HEAD prompt incorrect'
Set-Location -LiteralPath $Work
Assert (((prompt) -replace '\x1b\[[0-9;]*m', '') -notlike '* on *') 'Non-repository prompt contains Git branch'
function global:prompt { 'custom prompt' }
. $ProfilePath
Assert ((prompt) -ceq 'custom prompt') 'Reload replaced customized prompt'
Write-Output 'PASS: Ubuntu-style prompt, missing Git, branches, staged/modified/untracked/stash markers, detached HEAD, preserved exit codes'

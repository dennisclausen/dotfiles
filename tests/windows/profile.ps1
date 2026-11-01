# Isolated subprocess assertions. No real profile or local overrides are loaded.
param([string] $Repository, [string] $Work, [string] $ProfilePath)
$ErrorActionPreference = 'Stop'
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
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

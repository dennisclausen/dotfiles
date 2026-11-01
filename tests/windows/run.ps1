#Requires -Version 7.4
# Offline tests use explicit disposable destinations and subprocesses only.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$pwsh = (Get-Process -Id $PID).Path
$work = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-tests.' + [guid]::NewGuid().ToString('N'))
$environmentNames = @('OS', 'PATH', 'DOTFILES_INSTALL_MODE', 'DOTFILES_TARGET_HOME', 'DOTFILES_PROFILE_PATH', 'DOTFILES_LOCALAPPDATA',
    'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'NVIM_LOG_FILE')
$saved = @{}; foreach ($name in $environmentNames) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
# Observe metadata only; never enumerate or read private-directory contents.
function Home-Metadata {
    foreach ($path in @($HOME, (Join-Path $HOME '.aws'), (Join-Path $HOME '.agents'), (Join-Path $HOME '.codex'))) {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        if ($item) { "$path|$($item.LastWriteTimeUtc.Ticks)|$($item.Attributes)" }
    }
}
$homeBefore = @(Home-Metadata) -join "`n"
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Run-Installer([string] $Mode = 'Copy') {
    $script:installOutput = & $pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $fixture 'scripts/windows/install.ps1') -Mode $Mode -TargetHome $target -ProfilePath $profileFile -LocalAppData $localData 2>&1
    $script:installExit = $LASTEXITCODE
}
function Snapshot([string] $Root) {
    @(Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$($_.FullName)|$($_.LastWriteTimeUtc.Ticks)|$($_.Length)|$($_.LinkTarget)"
    }) -join "`n"
}
function New-Case([string] $Name) {
    $script:target = Join-Path $work $Name
    [void][IO.Directory]::CreateDirectory($target)
    $script:localData = Join-Path $target 'AppData/Local'
    # Exercise runtime-discovered profile layout without assuming Documents.
    $script:profileFile = Join-Path $target 'redirected documents/PowerShell/profile.ps1'
}
try {
    [void][IO.Directory]::CreateDirectory($work)
    foreach ($pair in @(@('XDG_CONFIG_HOME','config'), @('XDG_CACHE_HOME','cache'), @('XDG_DATA_HOME','data'), @('XDG_STATE_HOME','state'))) {
        [Environment]::SetEnvironmentVariable($pair[0], (Join-Path $work $pair[1]))
    }
    $env:NVIM_LOG_FILE = Join-Path $work 'nvim.log'
    # Syntax validation parses code without executing it or loading a profile.
    $psSources = @('powershell/profile.ps1', 'powershell/Dotfiles.psm1', 'powershell/navigation.ps1', 'powershell/commands.ps1',
        'scripts/windows/common.ps1', 'scripts/windows/install.ps1', 'scripts/windows/manifest.psd1', 'scripts/windows/packages.psd1',
        'scripts/windows/dependencies.ps1', 'scripts/windows/bootstrap.ps1', 'scripts/windows/make.ps1', 'tests/windows/run.ps1', 'tests/windows/profile.ps1')
    foreach ($source in $psSources) {
        $tokens = $null; $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $source), [ref]$tokens, [ref]$errors)
        Assert (-not $errors.Count) "PowerShell syntax: $source : $errors"
    }
    Write-Output 'PASS: PowerShell syntax for every declared source'
    $linuxManifest = [IO.File]::ReadAllText((Join-Path $repo 'install-manifest.sh'))
    Assert ($linuxManifest -notmatch 'powershell|scripts/windows') 'Linux installer gained Windows files'
    $packages = Import-PowerShellDataFile -LiteralPath (Join-Path $repo 'scripts/windows/packages.psd1')
    Assert (@($packages.Packages | Where-Object Id -EQ 'ezwinports.make').Count -eq 1) 'Native Make dependency missing'
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $repo 'scripts/windows/manifest.psd1')
    $fixture = Join-Path $work "repo space [x] & quote's `$ (semi;)"
    # Never recursively copy the checkout or private directories.
    $sources = @($psSources) + @($manifest.Shared.Source) + @('gitconfig', 'Makefile')
    foreach ($source in ($sources | Select-Object -Unique)) {
        $dest = Join-Path $fixture $source
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))
        [IO.File]::Copy((Join-Path $repo $source), $dest)
    }
    New-Case "home space [x] & quote's `$ (semi;)"
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $profileFile))
    $existingProfile = "# User customization`r`n`$global:ExistingProfileWasLoaded = 1`r`n"
    [IO.File]::WriteAllText($profileFile, $existingProfile)
    [IO.File]::WriteAllBytes((Join-Path $target '.gitconfig'), [byte[]]@(0, 255, 12, 13))
    $oldGitConfig = Join-Path $target '.gitconfig'
    [IO.File]::SetLastWriteTimeUtc($oldGitConfig, [datetime]'2020-01-02T03:04:05Z')
    $oldGitTime = [IO.File]::GetLastWriteTimeUtc($oldGitConfig)
    Run-Installer
    Assert ($installExit -eq 0) "Fresh copy installation: $installOutput"
    Assert ([IO.File]::ReadAllText($profileFile).StartsWith($existingProfile)) 'Existing profile content lost'
    foreach ($entry in $manifest.Shared) {
        $root = if ($entry.Root -eq 'Home') { $target } else { $localData }
        Assert ((Get-FileHash -LiteralPath (Join-Path $root $entry.Destination)).Hash -eq (Get-FileHash -LiteralPath (Join-Path $fixture $entry.Source)).Hash) 'Shared file mismatch'
    }
    Assert (-not (Test-Path -LiteralPath (Join-Path $target '.bashrc'))) 'Windows installed Bash startup'
    $backups = @(Get-ChildItem -LiteralPath $target -Force -Directory | Where-Object Name -Like '.gitconfig.dotfiles-backup.*')
    Assert ($backups.Count -eq 1) 'Git backup missing'
    Assert ([Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $backups[0].FullName 'original'))) -eq '00FF0C0D') 'Backup bytes changed'
    Assert ([IO.File]::GetLastWriteTimeUtc((Join-Path $backups[0].FullName 'original')) -eq $oldGitTime) 'Backup timestamp changed'
    $profileBackup = @(Get-ChildItem -LiteralPath (Split-Path -Parent $profileFile) -Directory | Where-Object Name -Like 'profile.ps1.dotfiles-backup.*')
    Assert ($profileBackup.Count -eq 1) 'Existing profile not backed up'
    $before = Snapshot $target
    Run-Installer
    Assert ($installExit -eq 0 -and (Snapshot $target) -ceq $before) 'Copy installation not idempotent'
    $outside = Join-Path $work 'outside-sentinel'; [IO.File]::WriteAllText($outside, 'keep')
    [IO.File]::WriteAllText((Join-Path $target '.gitignore'), 'local edits')
    Run-Installer
    Assert ($installExit -eq 0) 'Conflict copy install failed'
    $copyBackups = @(Get-ChildItem -LiteralPath $target -Force -Directory | Where-Object Name -Like '.gitignore.dotfiles-backup.*')
    Assert ($copyBackups.Count -eq 1 -and [IO.File]::ReadAllText((Join-Path $copyBackups[0].FullName 'original')) -ceq 'local edits') 'Copy conflict backup missing'
    [IO.File]::WriteAllText((Join-Path $target '.gitignore'), 'second edits')
    Run-Installer
    Assert ($installExit -eq 0 -and @(Get-ChildItem -LiteralPath $target -Force -Directory | Where-Object Name -Like '.gitignore.dotfiles-backup.*').Count -eq 2) 'Backups were reused'
    Assert ([IO.File]::ReadAllText($outside) -ceq 'keep') 'External sentinel changed'

    $git = Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1
    & $git config --file (Join-Path $target '.gitconfig') --includes --get core.editor
    Assert ($LASTEXITCODE -eq 0) 'Shared Git include failed'
    $included = & $git config --file (Join-Path $target '.gitconfig') --includes --get user.name
    Assert ($LASTEXITCODE -eq 0 -and $included -ceq 'Dr. Dennis Clausen') 'Shared Git settings unavailable'
    $ignore = & $git config --file (Join-Path $target '.gitconfig') --includes --path --get core.excludesfile
    Assert ($LASTEXITCODE -eq 0 -and $ignore.Replace('\','/') -ceq (Join-Path $target '.gitignore').Replace('\','/')) 'Git ignore path incorrect'
    $profileOutput = & $pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $fixture 'tests/windows/profile.ps1') -Repository $fixture -Work $target -ProfilePath $profileFile 2>&1
    Assert ($LASTEXITCODE -eq 0) "Profile regressions: $profileOutput"
    $profileOutput | Write-Output

    foreach ($case in @('leaf-directory', 'parent-file', 'ambiguous-profile')) {
        New-Case $case
        switch ($case) {
            leaf-directory { [void][IO.Directory]::CreateDirectory((Join-Path $target '.gitconfig')) }
            parent-file { [IO.File]::WriteAllText((Join-Path $target 'AppData'), 'keep') }
            ambiguous-profile {
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $profileFile))
                [IO.File]::WriteAllText($profileFile, '# >>> dotfiles PowerShell >>>')
            }
        }
        $before = Snapshot $target
        Run-Installer
        Assert ($installExit -ne 0 -and (Snapshot $target) -ceq $before) "Preflight modified files: $case"
    }
    # Symbolic-link scenarios run where the host permits them. Windows without
    # Developer Mode must instead pass the capability failure and copy tests.
    New-Case 'symlink-install'
    Run-Installer Symlink
    if ($installExit -eq 0) {
        $before = Snapshot $target
        Run-Installer Symlink
        Assert ($installExit -eq 0 -and (Snapshot $target) -ceq $before) 'Symlinks not idempotent'
        $dest = Join-Path $target '.gitignore'
        [IO.File]::Delete($dest)
        [void][IO.File]::CreateSymbolicLink($dest, 'missing-target')
        Run-Installer Symlink
        Assert ($installExit -eq 0) 'Dangling-link conflict failed'
        $backups = @(Get-ChildItem -LiteralPath $target -Directory -Force | Where-Object Name -Like '.gitignore.dotfiles-backup.*')
        Assert ((Get-Item -LiteralPath (Join-Path $backups[0].FullName 'original') -Force).LinkTarget -ceq 'missing-target') 'Link target changed in backup'
        New-Case 'redirected-parent'
        [void][IO.Directory]::CreateSymbolicLink((Join-Path $target 'AppData'), $work)
        Run-Installer
        Assert ($installExit -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $target '.gitignore'))) 'Symlink parent allowed writes'
        # Remove only the link, never recurse through its target during cleanup.
        [IO.Directory]::Delete((Join-Path $target 'AppData'))
        Write-Output 'PASS: symlink installs, repeats, dangling conflicts, redirected-parent rejection'
    } else {
        Assert (($installOutput -join "`n") -like '*Cannot create symlinks*') "Unexpected symlink failure: $installOutput"
        Assert (-not @(Get-ChildItem -LiteralPath $target -Force).Count) 'Failed capability probe modified configuration'
        Write-Output 'SKIP: symlink success cases (host lacks permission); clean failure and copy installation verified'
    }
    New-Case 'missing-source'
    $missingSource = Join-Path $fixture '.config/nvim/lua/settings.lua'
    [IO.File]::Move($missingSource, "$missingSource.saved")
    Run-Installer
    Assert ($installExit -ne 0 -and -not @(Get-ChildItem -LiteralPath $target -Force).Count) 'Missing source caused partial install'
    [IO.File]::Move("$missingSource.saved", $missingSource)
    # Deliberately corrupted manifest entries must fail before any destination.
    $manifestPath = Join-Path $fixture 'scripts/windows/manifest.psd1'
    $manifestText = [IO.File]::ReadAllText($manifestPath)
    foreach ($invalid in @('../outside', '.ssh/secret', '/absolute')) {
        [IO.File]::WriteAllText($manifestPath, $manifestText.Replace("Source = 'gitignore'", "Source = '$invalid'"))
        Run-Installer
        Assert ($installExit -ne 0 -and -not @(Get-ChildItem -LiteralPath $target -Force).Count) "Invalid manifest accepted: $invalid"
    }
    [IO.File]::WriteAllText($manifestPath, $manifestText)
    # Profile module completeness is also checked before the first write.
    $modulePath = Join-Path $fixture 'powershell/commands.ps1'
    [IO.File]::Move($modulePath, "$modulePath.saved")
    Run-Installer
    Assert ($installExit -ne 0 -and -not @(Get-ChildItem -LiteralPath $target -Force).Count) 'Missing module caused partial installation'
    [IO.File]::Move("$modulePath.saved", $modulePath)
    # Partial destination overrides must never fall back to the actual profile.
    $output = & $pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $fixture 'scripts/windows/install.ps1') -TargetHome $target -Mode Copy 2>&1
    Assert ($LASTEXITCODE -ne 0 -and ($output -join "`n") -like '*requires explicit ProfilePath and LocalAppData*') 'Unsafe default destination fallback'
    Write-Output 'PASS: disposable installs, copies, backups, preflight, path handling, shared Git/Neovim placement'

    $make = Get-Command make -CommandType Application -ErrorAction Stop | Select-Object -First 1
    # Linux exercises the actual Windows branch using a pwsh.exe link. This is
    # cross-platform dispatch coverage, not a claim about Windows CreateProcess.
    if (-not $IsWindows) {
        $bin = Join-Path $work 'bin'; [void][IO.Directory]::CreateDirectory($bin)
        [void][IO.File]::CreateSymbolicLink((Join-Path $bin 'pwsh.exe'), $pwsh)
        $env:PATH = $bin + [IO.Path]::PathSeparator + $env:PATH
    }
    $env:OS = 'Windows_NT'
    New-Case 'make installation'
    $env:DOTFILES_INSTALL_MODE = 'Copy'
    $env:DOTFILES_TARGET_HOME = $target
    $env:DOTFILES_PROFILE_PATH = $profileFile
    $env:DOTFILES_LOCALAPPDATA = $localData
    foreach ($goal in @('help', 'doctor', 'dotfiles', 'all')) {
        $output = & $make --no-print-directory -C $fixture $goal 2>&1
        Assert ($LASTEXITCODE -eq 0) "Make Windows $goal : $output"
    }
    $output = & $make --no-print-directory -C $fixture -n test 2>&1
    Assert ($LASTEXITCODE -eq 0 -and ($output -join "`n") -like '*make.ps1 -Target test*') 'Windows make test dispatch'
    foreach ($goal in @('etc', 'usr', 'check')) {
        $output = & $make --no-print-directory -C $fixture $goal 2>&1
        Assert ($LASTEXITCODE -ne 0) "Legacy Make $goal falsely succeeded"
    }
    $toolPath = $env:PATH
    try {
        $env:PATH = Join-Path $work 'no-tools'
        [void][IO.Directory]::CreateDirectory($env:PATH)
        $output = & $pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $fixture 'scripts/windows/make.ps1') -Target shellcheck 2>&1
        Assert ($LASTEXITCODE -ne 0 -and ($output -join "`n") -like '*shellcheck is required*') 'Missing native ShellCheck diagnostic'
    } finally { $env:PATH = $toolPath }
    # Invalid mode must fail through script, PowerShell recipe and GNU Make.
    $env:DOTFILES_INSTALL_MODE = 'Invalid'
    $output = & $make --no-print-directory -C $fixture dotfiles 2>&1
    Assert ($LASTEXITCODE -ne 0) 'Make swallowed installer failure'
    Write-Output 'PASS: GNU Make Windows help/doctor/dotfiles/all, test dispatch, legacy diagnostics, failure propagation'

    $nvim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nvim) {
        $oldLuaRoot = $env:DOTFILES_LUA_ROOT
        try {
            $env:DOTFILES_LUA_ROOT = Join-Path $fixture '.config/nvim'
            & $nvim --headless -u NONE -i NONE -n -c 'lua for _, f in ipairs({"init.lua", "lua/keymaps.lua", "lua/lsp.lua", "lua/plugins.lua", "lua/settings.lua"}) do local c, e = loadfile(vim.env.DOTFILES_LUA_ROOT .. "/" .. f); if not c then io.stderr:write(e); vim.cmd("cquit 1") end end' -c 'qa!'
            Assert ($LASTEXITCODE -eq 0) 'Neovim Lua syntax'
        } finally { $env:DOTFILES_LUA_ROOT = $oldLuaRoot }
        Write-Output 'PASS: shared Lua syntax (no plugin execution)'
    } else { Write-Output 'SKIP: Lua syntax requires optional nvim; installed Lua bytes verified' }
    Assert ((@(Home-Metadata) -join "`n") -ceq $homeBefore) 'Real HOME/private directory metadata changed'
    Write-Output 'PASS: real HOME/private directory metadata unchanged'
    Write-Output "PASS: PowerShell regression suite ($($PSVersionTable.PSVersion), Windows=$IsWindows)"
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}

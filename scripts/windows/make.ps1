#Requires -Version 7.4
param([Parameter(Mandatory)][ValidateSet('dotfiles', 'test', 'shellcheck', 'help', 'doctor', 'check', 'etc', 'usr')][string] $Target)
$ErrorActionPreference = 'Stop'
try {
    switch ($Target) {
        dotfiles {
            $options = @{}
            if ($env:DOTFILES_INSTALL_MODE) { $options.Mode = $env:DOTFILES_INSTALL_MODE }
            # All overrides travel as environment data, never interpolated Make code.
            if ($env:DOTFILES_TARGET_HOME) { $options.TargetHome = $env:DOTFILES_TARGET_HOME }
            if ($env:DOTFILES_PROFILE_PATH) { $options.ProfilePath = $env:DOTFILES_PROFILE_PATH }
            if ($env:DOTFILES_LOCALAPPDATA) { $options.LocalAppData = $env:DOTFILES_LOCALAPPDATA }
            & "$PSScriptRoot/install.ps1" @options
            exit $LASTEXITCODE
        }
        test { & "$PSScriptRoot/../../tests/windows/run.ps1"; exit $LASTEXITCODE }
        doctor {
            & "$PSScriptRoot/dependencies.ps1" | Format-Table -AutoSize | Out-Host
            exit $LASTEXITCODE
        }
        help {
            Write-Output @(
                'make / all   Install Windows configuration only (no packages).'
                'dotfiles     Install explicit Windows manifest; default Symlink, explicit Copy supported.'
                'test         Offline PowerShell, installer, shared config and native Make regressions.'
                'doctor       Report required/optional applications; no network or installation.'
                'shellcheck   Lint Bash sources with native ShellCheck; explicit error if missing.'
                'check        Legacy Docker check, unavailable while test.sh is missing.'
                'etc / usr    Unavailable legacy system installation targets.'
                'Optional tools: pwsh -NoProfile -File ./scripts/windows/dependencies.ps1 -Install'
            )
        }
        shellcheck {
            $tool = Get-Command shellcheck -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $tool) { throw 'shellcheck is required to lint Bash sources. Install native ShellCheck separately; Windows make test does not require Bash lint.' }
            Push-Location -LiteralPath (Join-Path $PSScriptRoot '../..')
            try {
                & $tool --shell=bash --external-sources --source-path=SCRIPTDIR -- .bashrc .bash_profile .bashprofile .bash_prompt .aliases .functions install-manifest.sh install.sh shellcheck.sh tests/run.sh tests/helpers.sh
                exit $LASTEXITCODE
            } finally { Pop-Location }
        }
        check {
            if (-not (Test-Path -LiteralPath "$PSScriptRoot/../../test.sh" -PathType Leaf)) {
                throw 'Legacy check requires missing test.sh; use make test for local validation.'
            }
            $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
            & docker run --rm -it --name df-test -v "${root}:/usr/src" --workdir /usr/src m0r13n/dftest:1.1 ./test.sh
            exit $LASTEXITCODE
        }
        default { throw "This checkout has no supported $Target installation manifest; no system files were changed." }
    }
    exit 0
} catch { [Console]::Error.WriteLine("dotfiles: $($_.Exception.Message)"); exit 1 }

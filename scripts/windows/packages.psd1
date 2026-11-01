@{
    # Verified against microsoft/winget-pkgs. Install only explicit user selections.
    ManualCommands = @('btop4win', 'code', 'ipython', 'lua-language-server', 'pyright')
    Packages = @(
        @{ Command = 'pwsh'; Id = 'Microsoft.PowerShell'; Required = $true }
        @{ Command = 'git'; Id = 'Git.Git'; Required = $true }
        @{ Command = 'make'; Id = 'ezwinports.make'; Required = $true }
        @{ Command = 'nvim'; Id = 'Neovim.Neovim'; Required = $false; ManualInstall = $true }
        @{ Command = 'eza'; Id = 'eza-community.eza'; Required = $false }
        @{ Command = 'rg'; Id = 'BurntSushi.ripgrep.MSVC'; Required = $false }
        @{ Command = 'fzf'; Id = 'junegunn.fzf'; Required = $false }
        @{ Command = 'bat'; Id = 'sharkdp.bat'; Required = $false }
        @{ Command = 'python'; Id = 'Python.Python.3.13'; Required = $false }
    )
}

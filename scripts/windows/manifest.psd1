@{
    ProfileSources = @('powershell/profile.ps1', 'powershell/Dotfiles.psm1',
        'powershell/navigation.ps1', 'powershell/commands.ps1', 'powershell/prompt.ps1', 'gitconfig')
    # Five individual files: never replace the user's nvim directory.
    Shared = @(
        @{ Source = 'gitignore'; Root = 'Home'; Destination = '.gitignore' }
        @{ Source = '.config/nvim/init.lua'; Root = 'Local'; Destination = 'nvim/init.lua' }
        @{ Source = '.config/nvim/lua/keymaps.lua'; Root = 'Local'; Destination = 'nvim/lua/keymaps.lua' }
        @{ Source = '.config/nvim/lua/lsp.lua'; Root = 'Local'; Destination = 'nvim/lua/lsp.lua' }
        @{ Source = '.config/nvim/lua/plugins.lua'; Root = 'Local'; Destination = 'nvim/lua/plugins.lua' }
        @{ Source = '.config/nvim/lua/settings.lua'; Root = 'Local'; Destination = 'nvim/lua/settings.lua' }
    )
}

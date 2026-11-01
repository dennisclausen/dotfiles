#!/bin/bash
# Alternating repository-relative source and HOME-relative destination paths.
# Keep every entry explicit: adding a file must never implicitly install it.
# shellcheck disable=SC2034 # Data consumed by install.sh and tests/run.sh.
install_files=(
	'.aliases' '.aliases'
	'.bash_profile' '.bash_profile'
	'.bash_prompt' '.bash_prompt'
	'.bashprofile' '.bashprofile'
	'.bashrc' '.bashrc'
	'.functions' '.functions'
	'.inputrc' '.inputrc'
	'.shellcheckrc' '.shellcheckrc'
	'gitignore' '.gitignore'
	'gitconfig' '.gitconfig'
	'.config/nvim/init.lua' '.config/nvim/init.lua'
	'.config/nvim/lua/keymaps.lua' '.config/nvim/lua/keymaps.lua'
	'.config/nvim/lua/lsp.lua' '.config/nvim/lua/lsp.lua'
	'.config/nvim/lua/plugins.lua' '.config/nvim/lua/plugins.lua'
	'.config/nvim/lua/settings.lua' '.config/nvim/lua/settings.lua'
	'.bash_profile' '.profile'
)

#!/bin/bash
set -euo pipefail
test_dir=${BASH_SOURCE[0]%/*}
[[ $test_dir != "${BASH_SOURCE[0]}" ]] || test_dir=.
repo=$(cd -P -- "$test_dir/.." && printf '%s/.' "$PWD")
repo=${repo%/.}
real_home=$HOME
work=$(mktemp -d /tmp/dotfiles-tests.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
# Observe directory metadata only; never inspect private-directory contents.
home_metadata() {
	local path
	for path in "$real_home" "$real_home/.aws" "$real_home/.agents" "$real_home/.codex"; do
		if [[ -e $path || -L $path ]]; then
			stat -c '%n %d:%i:%f:%s:%Y:%Z' -- "$path"
		fi
	done
}
home_metadata > "$work/home.before"
export HOME="$work/validation-home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
export NVIM_LOG_FILE="$work/nvim.log"
export TMPDIR="$work/tmp"
mkdir -p -- "$HOME" "$TMPDIR"

# Source copy and HOME names exercise spaces, tabs, quotes and metacharacters.
odd=$' space [*] $;\'`printf injected`$(printf injected)\t\nname\n'
fixture="$work/repo$odd"
mkdir -p -- "$fixture/tests" "$fixture/.config/nvim/lua"
# Copy only declared sources and tooling; never copy private directories.
# shellcheck source=../install-manifest.sh
source "$repo/install-manifest.sh"
for ((i = 0; i < ${#install_files[@]}; i += 2)); do
	rel=${install_files[i]}
	if [[ $rel == */* ]]; then mkdir -p -- "$fixture/${rel%/*}"; fi
	cp -- "$repo/$rel" "$fixture/$rel"
done
cp -- "$repo/install.sh" "$repo/install-manifest.sh" "$repo/Makefile" "$fixture/"
# A deliberate fixture-only manifest entry also exercises nested odd filenames.
extra_source=$'.config/nvim/extra space\t$;\'`[*].lua'
extra_dest=$'.config/nvim/nested space\t$;\'`[*]/extra.lua'
printf '%s\n' 'return true' > "$fixture/$extra_source"
printf '\ninstall_files+=(%q %q)\n' "$extra_source" "$extra_dest" >> "$fixture/install-manifest.sh"
source "$fixture/install-manifest.sh"
# Unexpected paths, including a hidden descendant, must not enter the manifest.
for private in .aws .agents .codex .git .future; do
	mkdir -p -- "$fixture/$private"
	printf 'untouched\n' > "$fixture/$private/.sentinel"
done
install_home="$work/home$odd"
mkdir -- "$install_home"
install_fixture() { HOME="$install_home" make --no-print-directory -C "$fixture" dotfiles > "$work/install.log" 2>&1; }
assert_links() {
	local index target
	for ((index = 0; index < ${#install_files[@]}; index += 2)); do
		target=$install_home/${install_files[index+1]}
		[[ -L $target && $(readlink -- "$target") == "$fixture/${install_files[index]}" ]] || fail "Wrong link: $target"
	done
}
install_fixture || { cat "$work/install.log"; fail 'Fresh install'; }
assert_links
for private in .aws .agents .codex .git .future .sentinel; do
	[[ ! -e $install_home/$private && ! -L $install_home/$private ]] || fail "Unexpected install: $private"
done
# Capture inode/mtime: repeated installation must not recreate correct links.
find "$install_home" -type l -printf '%p %i %T@\n' | sort > "$work/links.before"
install_fixture || fail 'Repeated install'
find "$install_home" -type l -printf '%p %i %T@\n' | sort > "$work/links.after"
cmp "$work/links.before" "$work/links.after" || fail 'Correct links were modified'
# An already-correct relative link must also remain intact.
rm -- "$install_home/.aliases"
ln -s -- "../${fixture##*/}/.aliases" "$install_home/.aliases"
relative_link=$(readlink -- "$install_home/.aliases")
install_fixture || fail 'Relative correct link'
[[ $(readlink -- "$install_home/.aliases") == "$relative_link" ]] || fail 'Relative link replaced'

# File and symlink conflicts, metadata, unique backups and recovery.
rm -- "$install_home/.bashrc" "$install_home/.gitconfig" "$install_home/.inputrc"
printf 'original bytes\000\377\n' > "$install_home/.bashrc"
chmod 640 "$install_home/.bashrc"
touch -t 202001020304.05 "$install_home/.bashrc"
cp -p -- "$install_home/.bashrc" "$work/original"
original_meta=$(stat -c '%a:%u:%g:%Y:%i' -- "$install_home/.bashrc")
ln -s 'missing target $ [*]' "$install_home/.gitconfig"
mkdir -- "$work/external-dir"
ln -s -- "$work/external-dir" "$install_home/.inputrc"
install_fixture || fail 'Conflicting files/symlinks'
shopt -s nullglob
backups=("$install_home/.bashrc.dotfiles-backup."*)
(( ${#backups[@]} == 1 )) || fail 'Missing regular-file backup'
backup=${backups[0]}
cmp "$work/original" "$backup/original" || fail 'Backup bytes'
[[ $(stat -c '%a:%u:%g:%Y:%i' -- "$backup/original") == "$original_meta" ]] || fail 'Backup metadata'
links=("$install_home/.gitconfig.dotfiles-backup."*)
[[ ${#links[@]} == 1 && -L ${links[0]}/original ]] || fail 'Symlink backup'
[[ $(readlink -- "${links[0]}/original") == 'missing target $ [*]' ]] || fail 'Symlink target changed'
links=("$install_home/.inputrc.dotfiles-backup."*)
[[ ${#links[@]} == 1 && -L ${links[0]}/original && -d $work/external-dir ]] || fail 'Symlink-to-directory backup'
# Follow the documented recovery commands, then install again.
rm -- "$install_home/.bashrc"
mv -T -- "$backup/original" "$install_home/.bashrc"
rmdir -- "$backup"
cmp "$work/original" "$install_home/.bashrc" || fail 'Recovery bytes'
install_fixture || fail 'Install after recovery'
rm -- "$install_home/.bashrc"
printf 'second version\n' > "$install_home/.bashrc"
install_fixture || fail 'Second conflict'
backups=("$install_home/.bashrc.dotfiles-backup."*)
(( ${#backups[@]} == 2 )) || fail 'Backups collided'
if cmp -s "$work/original" "${backups[0]}/original"; then
	cmp "$work/original" "${backups[0]}/original"
	grep -qx 'second version' "${backups[1]}/original"
else
	cmp "$work/original" "${backups[1]}/original"
	grep -qx 'second version' "${backups[0]}/original"
fi

# Preflight must reject directories and redirected parents without partial work.
for conflict in leaf parent symlink-parent; do
	install_home="$work/conflict-$conflict"
	mkdir -- "$install_home"
	case $conflict in
		leaf) mkdir -- "$install_home/.bashrc"; printf keep > "$install_home/.bashrc/keep" ;;
		parent) printf keep > "$install_home/.config" ;;
		symlink-parent) ln -s -- "$work/external-dir" "$install_home/.config" ;;
	esac
	if install_fixture; then fail "Accepted conflict: $conflict"; fi
	[[ ! -e $install_home/.aliases ]] || fail 'Partial install despite preflight conflict'
	grep -Eq 'Directory conflict|Parent is not a directory|Symlinked parent' "$work/install.log" || fail 'Missing diagnostic'
	if [[ $conflict == leaf ]]; then
		[[ $(< "$install_home/.bashrc/keep") == keep ]] || fail 'Directory content changed'
	fi
done
[[ -z $(find "$work/external-dir" -mindepth 1 -print -quit) ]] || fail 'Wrote through symlink parent'
# Invalid manifests must fail without flattening or partially installing paths.
for conflict in duplicate ancestor; do
	cp -- "$repo/install-manifest.sh" "$fixture/install-manifest.sh"
	case $conflict in
		duplicate) printf '\ninstall_files+=(".aliases" ".aliases")\n' >> "$fixture/install-manifest.sh" ;;
		ancestor) printf '\ninstall_files+=(".aliases" ".config")\n' >> "$fixture/install-manifest.sh" ;;
	esac
	install_home="$work/manifest-$conflict"
	mkdir -- "$install_home"
	if install_fixture; then fail "Accepted manifest collision: $conflict"; fi
	[[ -z $(find "$install_home" -mindepth 1 -print -quit) ]] || fail 'Invalid manifest modified HOME'
	grep -Eq 'Duplicate destination|Overlapping destinations' "$work/install.log" || fail 'Missing collision diagnostic'
done
printf 'PASS: installer, idempotence, backups, recovery and path handling\n'

# Run helper assertions in an interactive Bash without loading user startup.
bash --noprofile --norc -i "$repo/tests/helpers.sh" "$repo" "$work" 2> "$work/helpers.stderr" || {
	cat "$work/helpers.stderr" >&2; fail 'Shell helper regressions';
}
[[ -f $work/helpers.completed ]] || fail 'Interactive shell exited before completing helper assertions'
for file in .bashrc .bash_profile .bashprofile .bash_prompt .aliases .functions install-manifest.sh install.sh shellcheck.sh tests/run.sh tests/helpers.sh; do
	bash -n "$repo/$file"
done
git config --file "$repo/gitconfig" --list > /dev/null
mkdir -- "$work/git-parse"
git -C "$work/git-parse" init -q
git -C "$work/git-parse" -c core.excludesfile="$repo/gitignore" check-ignore --no-index .Trash-1000 > /dev/null
command -v nvim >/dev/null || fail 'nvim is required for Lua syntax validation'
# loadfile compiles only: no plugin resolution, startup, downloads or LSPs.
DOTFILES_LUA_ROOT="$repo/.config/nvim" nvim --headless -u NONE -i NONE -n \
	-c 'lua for _, f in ipairs({"init.lua", "lua/keymaps.lua", "lua/lsp.lua", "lua/plugins.lua", "lua/settings.lua"}) do local chunk, err = loadfile(vim.env.DOTFILES_LUA_ROOT .. "/" .. f); if not chunk then io.stderr:write(err .. "\n"); vim.cmd("cquit 1") end end' \
	-c 'qa!'
home_metadata > "$work/home.after"
cmp "$work/home.before" "$work/home.after" || fail 'Real HOME/private directory metadata changed during validation'
printf 'PASS: Bash syntax, Git parsing/ignore, Neovim Lua syntax; real HOME/private directory metadata unchanged\n'

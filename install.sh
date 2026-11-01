#!/bin/bash
set -euo pipefail

repo_dir=${BASH_SOURCE[0]%/*}
[[ $repo_dir != "${BASH_SOURCE[0]}" ]] || repo_dir=.
# A sentinel preserves trailing newlines in directory names during substitution.
repo_dir=$(cd -P -- "$repo_dir" && printf '%s/.' "$PWD")
repo_dir=${repo_dir%/.}
# shellcheck source=install-manifest.sh
source "$repo_dir/install-manifest.sh"

fail() {
	printf 'dotfiles: %s\n' "$*" >&2
	exit 1
}

[[ -n ${HOME:-} && -d $HOME ]] || fail 'HOME must name an existing directory.'
home_dir=$(cd -P -- "$HOME" && printf '%s/.' "$PWD")
home_dir=${home_dir%/.}
[[ $home_dir != / ]] || fail 'Refusing to install into /.'
[[ $home_dir != "$repo_dir" ]] || fail 'HOME must differ from the repository directory.'

relative_path() {
	[[ -n $1 && $1 != /* && /$1/ != */../* && /$1/ != */./* && $1 != */ && $1 != *//* ]]
}

# Check every mapping and existing ancestor before making any changes.
# Symlinked parents could redirect writes outside HOME, so require real dirs.
(( ${#install_files[@]} % 2 == 0 )) || fail 'Manifest has an incomplete mapping.'
declare -A destinations=()
for ((i = 0; i < ${#install_files[@]}; i += 2)); do
	source_path=${install_files[i]}
	relative_dest=${install_files[i+1]}
	relative_path "$source_path" || fail "Invalid source path: $source_path"
	relative_path "$relative_dest" || fail "Invalid destination path: $relative_dest"
	[[ -f $repo_dir/$source_path ]] || fail "Missing source file: $source_path"
	[[ ! ${destinations[$relative_dest]+present} ]] || fail "Duplicate destination: $relative_dest"
	destinations["$relative_dest"]=1
	dest=$home_dir/$relative_dest
	[[ ! -d $dest || -L $dest ]] || fail "Directory conflict: $dest; move it aside manually and retry."
	[[ ! -e $dest || -f $dest || -L $dest ]] || fail "Unsupported destination type: $dest; move it aside manually and retry."
	parent=${dest%/*}
	while [[ $parent != "$home_dir" ]]; do
		[[ ! -L $parent ]] || fail "Symlinked parent: $parent; use a real directory before retrying."
		[[ ! -e $parent || -d $parent ]] || fail "Parent is not a directory: $parent; move it aside manually and retry."
		# A manifest cannot install both an ancestor and a descendant.
		for ((j = 1; j < ${#install_files[@]}; j += 2)); do
			[[ $parent != "$home_dir/${install_files[j]}" ]] || fail "Overlapping destinations: $relative_dest and ${install_files[j]}"
		done
		parent=${parent%/*}
	done
done

for ((i = 0; i < ${#install_files[@]}; i += 2)); do
	source_path=$repo_dir/${install_files[i]}
	dest=$home_dir/${install_files[i+1]}
	if [[ -L $dest && $dest -ef $source_path ]]; then
		printf 'Already linked: %s\n' "$dest"
		continue
	fi
	mkdir -p -- "${dest%/*}"
	if [[ -e $dest || -L $dest ]]; then
		# Reserve a unique sibling directory; rename preserves the resource's
		# contents, permissions, timestamps and symlink identity on this FS.
		backup=$(mktemp -d -- "$dest.dotfiles-backup.XXXXXXXX")
		mv -T -- "$dest" "$backup/original"
		printf 'Backup: %s -> %s\n' "$dest" "$backup/original"
	fi
	# No force or directory dereference: a new conflict must fail safely.
	if ! ln -sT -- "$source_path" "$dest"; then
		fail "Could not link $dest; any backup remains at the path printed above."
	fi
	printf 'Linked: %s -> %s\n' "$dest" "$source_path"
done

#!/bin/bash
set -euo pipefail
script_dir=${BASH_SOURCE[0]%/*}
[[ $script_dir != "${BASH_SOURCE[0]}" ]] || script_dir=.
cd -- "$script_dir"

# Explicit coverage: .shellcheckrc is configuration, not a shell source.
# Include the empty legacy startup file while it remains in the manifest.
sources=(
	.bashrc .bash_profile .bashprofile .bash_prompt .aliases .functions
	install-manifest.sh install.sh shellcheck.sh tests/run.sh tests/helpers.sh
)
command -v shellcheck >/dev/null || { echo 'shellcheck is required.' >&2; exit 1; }
errors=()
for source in "${sources[@]}"; do
	if shellcheck --shell=bash --external-sources --source-path=SCRIPTDIR -- "$source"; then
		printf '[OK]: successfully linted %s\n' "$source"
	else
		errors+=("$source")
	fi
done
if (( ${#errors[@]} )); then
	printf 'ShellCheck failed: %s\n' "${errors[@]}" >&2
	exit 1
fi

# dotfiles

Personal Bash, Git, Readline and Neovim configuration for Linux. The installer
and tests assume Bash 4+, GNU coreutils and GNU Make. Some retained helpers are
platform-specific; this is not a portable macOS installer.

## Installation

Review `install-manifest.sh`, `gitconfig` (including the personal identity), and
the shell sources before installing. Keep this checkout at a stable path:
installed symlinks point into it.

```sh
make dotfiles
```

This installs only the explicit source/destination pairs in
`install-manifest.sh`. To target another existing home directory, pass it through
the environment, quoting the path:

```sh
HOME='/path/to/disposable home' make dotfiles
```

The manifest preserves these destinations:

| Repository source | Destination relative to HOME |
| --- | --- |
| `.aliases`, `.bash_profile`, `.bash_prompt`, `.bashprofile`, `.bashrc`, `.functions`, `.inputrc`, `.shellcheckrc` | Same name |
| `gitconfig` | `.gitconfig` |
| `gitignore` | `.gitignore` |
| `.bash_profile` | `.profile` |
| The five explicitly listed `.config/nvim/` Lua files | Same nested paths |

The empty `.bashprofile` is retained for compatibility; Bash's standard login
file here is `.bash_profile`. Repository `.gitignore`, private directories such
as `.aws`, `.agents`, `.codex`, Git internals, and future files are not installed.
To install another resource, deliberately add its quoted source/destination
pair to the manifest and review the mapping.

Correct symlinks are left untouched, including equivalent relative links.
Conflicting files and symlinks are renamed into unique, mode-700 sibling backup
directories, such as `.bashrc.dotfiles-backup.A1b2C3d4/original`. Renaming on the
same filesystem preserves bytes, ownership, permissions, modification time and
symlink targets; change time necessarily changes. Previous backups are retained.
An existing real directory at a file destination, a non-directory parent, or a
symlinked parent directory stops preflight with a diagnostic before installation
starts. Move the conflicting resource aside manually or arrange real parent
directories, then retry. Directories are never recursively replaced.

Installation is sequential, not transactional. An I/O or permissions failure
can leave earlier links installed; inspect the printed paths, resolve the cause
and rerun. Do not run simultaneous installs or modify destinations during one.

## Backup recovery

Use the exact backup path printed during installation. First check that the
current destination is still the installed symlink and that its target is the
expected checkout. For example:

```sh
readlink -- "$HOME/.bashrc"
# Substitute the actual backup directory printed by the installer.
backup="$HOME/.bashrc.dotfiles-backup.A1b2C3d4"
# Stop if .bashrc is not still the installed symlink.
test -L "$HOME/.bashrc" && rm -- "$HOME/.bashrc" &&
    mv -T -- "$backup/original" "$HOME/.bashrc" && rmdir -- "$backup"
```

Repeat for each resource to recover. Moving a backed-up symlink restores the
original link, not a copy of its target. Inspect and preserve any later local
edits before removing a destination. Backups are not automatically deleted.

## Startup and existing behavior

`.bash_profile` sources `.bashrc`. Non-interactive `.bashrc` returns immediately;
interactive startup sets shell options, completion and GPG/SSH agent integration,
then sources the readable regular files in this order: `.bash_prompt`, `.aliases`,
`.functions`, `.path`, `.dockerfunc`, `.extra`, `.exports`, `.autocomp`. The final
fzf bindings and existing local PATH additions follow. Optional local files are
not supplied or overwritten by the manifest. GPG configuration and session
services must already be set up on the host.

`isup` reports up only when curl succeeds with HTTP status 200. Other statuses
and transport failures report down. Its GET/header options and lack of redirect
following are retained. Notification delivery determines the helper's final
exit status, as before.

## Dependencies

`make dotfiles` only creates links; it installs no packages. The existing default
`make` / `make all` also runs
`sudo apt install python3-pip python3-argcomplete shellcheck eza` after linking.
That package policy is retained, does not provision the full environment, and
may change installed package versions. It was not run during maintenance.

Install the tools needed for the commands you use separately:

| Configuration or helper | Existing requirements |
| --- | --- |
| Core shell, prompt and Git workflows | Bash, Git, coreutils; `tput`/terminfo, `less`, completion files and GnuPG for their configured integrations |
| Git editor and Neovim | `nvim`, Git for lazy.nvim bootstrap, `lua-language-server`, `pyright`; plugin-specific build prerequisites |
| Enhanced aliases | `eza`, optional `batcat` and `btop`; `tree`, `rg`; `gc` requires the external `/usr/local/bin/gitdate` script, which is not in this repository |
| Fuzzy helpers | `fzf`, `code` for `fode`, `batcat` for `ffind` previews, `apt-cache` for `fapt` |
| Clipboard, desktop and images | X11 `xclip`, `notify-send` and a notification session, `xdg-open`/an `open` command, `feh`, `xprop` |
| Network and certificates | `curl`, `dig`, OpenSSL, `mtr`; legacy IP aliases use `ifconfig` |
| Calculation, JSON and encoding | `bc`, Python 3 (`python` alias), `pygmentize`, `xxd`, Perl; `ipython3` for its alias |
| Archives and encryption | `tar`, `gzip`; optional `pigz` or `zopfli`; GnuPG |
| Go and Python development helpers | Go and an existing `GOPATH/src` layout where used; `pip`, virtual environments, `autopep8`, `isort` |
| Session and host helpers | `sudo`, `systemd-inhibit`, procps process tools; `battery` assumes `/sys/class/power_supply/BAT0/capacity` |

The `flush` alias uses macOS services (`dscacheutil`, `mDNSResponder`) and is
retained as-is. Service availability and external URLs are not validated here.

Neovim startup may clone lazy.nvim and resolve plugins. No lockfile is tracked,
so fresh resolution is not reproducible. Lua LSP setup occurs in both
`plugins.lua` and `lsp.lua`; consolidating it could change effective settings.
Plugin versions, bootstrap, plugins, LSP setup, mappings and theme are unchanged.

The retained `prikey` alias copies `~/.ssh/id_ed25519` into the clipboard.
Clipboard history or synchronization can retain private-key material. Removing
or redesigning this shortcut requires an explicit owner decision.

## Validation

```sh
make test
# Lint alone:
make shellcheck
```

Validation requires the existing `shellcheck`, `git`, `nvim`, Bash 4.4+, GNU Make and
GNU coreutils, plus standard `find`, `sort`, `sed`, `awk` and `grep` tools. It does
not install tools, contact the network, resolve plugins, start LSPs or invoke the
installer against the real HOME. The regression runner uses disposable homes,
copies only declared configuration sources, mocks network/desktop/process
operations, and checks real HOME/private-directory metadata for changes without
reading private-directory contents. Concurrent changes to that metadata may
cause this check to fail.

Tests cover fresh/repeated installs, unchanged correct links, file/symlink and
directory conflicts, nested destinations, spaces/tabs/newlines and shell-special paths,
unexpected hidden directories, metadata-preserving unique backups and recovery,
interactive shell survival, helper quoting and PID handling, HTTP 200/500 and
transport failures (also 301/204), Bash syntax, Git config/ignore parsing, and all
five Neovim Lua files. Lua files are compiled with `loadfile` in clean headless
Neovim; successful syntax checking does not verify plugin runtime compatibility.

`make check` retains the legacy Docker command but stops before Docker because
its `test.sh` is absent. `make etc` and `make usr` stop with diagnostics: this
checkout has no corresponding resources or supported installation manifests.
No new system-installation or container workflow is inferred.

See `MAINTENANCE.md` for the verified baseline, classifications and deferred
owner decisions from the 2026-11-01 maintenance pass.

# dotfiles

Personal Bash, Git, Readline and Neovim configuration for Linux, plus native
Windows 11 PowerShell 7 configuration. Shared Git/Neovim files stay in their
existing locations; `powershell/` contains the Windows shell, and
`scripts/windows/` contains native installation and maintenance scripts.
Linux requires Bash 4+, GNU coreutils and GNU Make. Windows requires PowerShell
7.4+, Git and native GNU Make; WSL and Git Bash are not required. macOS and Windows
PowerShell 5.1 are not supported by the new installer.

## Branches

`dev` is the default branch for development and maintenance. `main` is the
release branch; promote reviewed changes from `dev` to `main` when preparing a
release.

## Windows 11 quick start

Review `gitconfig` (it contains the owner's identity),
`scripts/windows/manifest.psd1`, and `powershell/` before installing. Keep the
checkout at a stable path. These instructions assume the Windows support has
been integrated into your copy of `dev`.

Install PowerShell 7 and Git using Windows Package Manager (App Installer),
then open **PowerShell 7**, not Windows PowerShell 5.1:

```powershell
winget install --exact --id Microsoft.PowerShell --source winget
winget install --exact --id Git.Git --source winget
```

In the new PowerShell 7 terminal:

```powershell
git clone --branch dev https://github.com/dennisclausen/dotfiles.git
Set-Location -LiteralPath ./dotfiles
# Explicit, optional network/package operation: installs native GNU Make only.
pwsh -NoProfile -File ./scripts/windows/bootstrap.ps1
# Open another PowerShell 7 terminal, return to the checkout, then:
make help
make doctor
make dotfiles
```

The default installation uses file symlinks. If Developer Mode or the necessary
symlink permission is unavailable, installation stops before changing any
configuration. Explicitly choose the copy alternative (no privilege required):

```powershell
$env:DOTFILES_INSTALL_MODE = 'Copy'
make dotfiles
```

Keep that setting for later installs in this session; set it again in future
sessions when using copy mode. Alternatively, bypass Make:

```powershell
pwsh -NoProfile -File ./scripts/windows/install.ps1 -Mode Copy
```

Open a fresh PowerShell 7 session after installation. `ll`, `..`, `g` and the
other helpers are then available. A terminal banner saying **Windows PowerShell**
means you opened version 5.1, which uses a different profile. Run `pwsh` to enter
PowerShell 7 and check `$PSVersionTable.PSVersion` (7.4 or newer). In Windows
Terminal, choose **Settings → Startup → Default profile → PowerShell** (the
PowerShell 7 entry), then save. Installing PowerShell 7 does not automatically
change the terminal's default profile. `make` / `make all` install configuration only
on Windows. They never run apt or install packages. Linux retains its existing
default apt workflow.

Bootstrap installs `ezwinports.make`, a native GNU Make 4.4.1 portable package,
verified in [Microsoft's package manifest](https://github.com/microsoft/winget-pkgs/blob/master/manifests/e/ezwinports/make/4.4.1/ezwinports.make.installer.yaml).
There is no requirement for Unix commands on PATH. Restart the terminal after
package installation so WinGet's PATH changes are visible; use
`Get-Command make, pwsh, git` to inspect resolution. `make.exe --version` should
report GNU Make. This package is x86 and relies on Windows emulation on other
architectures; native ARM64 execution has not been validated.

If your execution policy blocks reviewed local scripts, inspect
`Get-ExecutionPolicy -List` and apply your organization's normal policy. The
repository does not bypass execution policy, enable Developer Mode, elevate,
or change system settings.

## Windows configuration and safety

The Windows manifest is explicit; no hidden-file discovery occurs:

| Resource | Windows destination |
| --- | --- |
| Minimal managed loader block | Runtime `$PROFILE.CurrentUserAllHosts` (PowerShell 7) |
| Shared `gitconfig` | Included from a generated `<UserProfile>/.gitconfig` |
| Shared `gitignore` | `<UserProfile>/.gitignore` (link or copy) |
| The five existing `.config/nvim/` Lua files | `<LocalApplicationData>/nvim/` (individual links or copies) |

UserProfile and LocalApplicationData come from .NET known folders, and the
profile path comes from the running PowerShell 7 runtime. Redirected Documents
is supported when its ancestors are real directories. Bash files, Readline,
private directories and Git internals are never installed on Windows. Neovim
uses its standard Windows path; custom `NVIM_APPNAME` or `XDG_CONFIG_HOME`
layouts require manual placement.

Existing profile text is retained, with a uniquely marked loader block appended;
subsequent installs update that block only. Before any change, the original
profile is renamed into a sibling `profile.ps1.dotfiles-backup.<guid>/original`.
A symlink/reparse-point profile or malformed/duplicate markers stops preflight;
integrate `powershell/profile.ps1` manually in that case. Existing host-specific
profiles continue loading after CurrentUserAllHosts as PowerShell normally does.

The loader imports the module once per session, retaining commands already defined
by the user, and then sources the optional
`dotfiles.local.ps1` beside CurrentUserAllHosts. Create that file for machine
customizations; it is neither tracked nor installed. Restart the session after
updating module code. Startup performs no network calls, tool installation,
PATH modification, agent startup, or optional application execution. Native
PowerShell commands and aliases keep their object/pipeline behavior.

Git includes the shared configuration, overrides the excludes-file path for the
target user, and finally includes `<UserProfile>/.gitconfig.local` if present.
Use that untracked file for identity overrides or machine preferences. An old
`.gitconfig` is backed up, rather than silently merged; review it and manually
move desired settings to `.gitconfig.local`. Git for Windows handles shared
Git shell aliases internally; the `dm` alias still requires `grep` and `xargs`,
and binary `textconv` still requires `hexdump`. These commands are not provisioned
or assumed available to PowerShell.

Preflight validates every destination, parent, shared source and collision before
changing configuration. File conflicts (including dangling file symlinks) are
renamed to unique sibling `<name>.dotfiles-backup.<guid>/original` paths.
Directory conflicts and reparse-point parents are rejected; directories are
never replaced. OneDrive/cloud reparse ancestors and junctions can therefore
require a different real directory or manual integration. Existing directory
ACL inheritance applies to Windows backups; protect your own configuration
folders accordingly.

Correct links and byte-identical copies are left untouched. Copy mode copies
only the manifest resources; Git and the profile still load code/configuration
from the checkout. Mode changes are explicit and back up the previous file or
link. Installation is sequential, not transactional: resolve any I/O failure
and rerun. Do not run concurrent installs or modify destinations during a run.
No automatic fallback, forced replacement, recursive directory replacement or
privilege escalation occurs.

### Windows updates, recovery and removal

After updating the checkout with your normal Git workflow, rerun `make dotfiles`
in the installation mode you selected. Links, the shared Git include and profile
loader follow checkout updates; copy-mode Neovim/ignore files refresh only when
you reinstall. Existing backups remain. Neovim plugins are not upgraded by the
installer.

To restore one resource, inspect both the installed path and the exact backup
printed by installation. Preserve later edits first. For a symlink inspect
`(Get-Item -LiteralPath $destination -Force).LinkTarget`; for a copy compare its
contents with the manifest source. After confirming it is still your installed
resource, restore using literal filesystem paths:

```powershell
# Substitute actual absolute paths from the installer output.
$destination = 'C:/Users/you/.gitconfig'
$backup = 'C:/Users/you/.gitconfig.dotfiles-backup.ACTUAL_GUID'
# Stop unless the current destination is still the reviewed installed file.
[IO.File]::Delete($destination)
[IO.File]::Move((Join-Path $backup 'original'), $destination)
[IO.Directory]::Delete($backup) # Fails if it is not empty; never recurse.
```

Repeat per resource as needed. For uninstallation, remove the marked loader
block from CurrentUserAllHosts while retaining all your other profile text,
then remove only the installed individual manifest files and generated Git
include after inspection, restoring backups as desired. Keep `.gitconfig.local`,
`dotfiles.local.ps1`, unrelated Neovim files, and backups. Never recursively
remove the profile or Neovim directory. No automated uninstall deletes user data.

## Shell compatibility matrix

Linux commands remain unchanged. Windows functions accept PowerShell arguments;
Bash expansions/flags are not parsed as shell source. All external tools remain
available by their own command names.

| Commands / configuration | Native Windows support |
| --- | --- |
| `..`, `...`, `....`, `.....`, `dl` | Literal-path navigation; `dl` uses `$HOME/Downloads` (custom redirected downloads can be set in the local profile) |
| Bash `-` directory shortcut | Use PowerShell `Set-Location -` |
| `mkd`, `tmpd` | Create and enter one directory; temporary names use GUIDs |
| `ll` | Exactly `eza -la` plus supplied paths; native `Get-ChildItem -Force` objects if eza is absent |
| `l`, `la`, `lsd` | eza listing, with native object fallbacks; path arguments, no Unix `ls` flags in the fallback |
| `lsg`, `tree1`–`tree6`, `tre` | eza Git/tree flags; clear dependency error if unavailable; no pager |
| `ls`, `cat`, `cp`, `mv`, `md`, `diff`, `h` | PowerShell built-ins retained; invoke eza/bat/Git explicitly when wanted |
| `g`, `ga`, `subsub`, `gitsetoriginnopush` | Git wrappers forward arguments and native exit codes |
| `gc` | PowerShell's existing Get-Content alias retained; no external `gitdate` implementation supplied; use `git commit` |
| `rgi`, `grepr` | `rg -i`, preserving ripgrep's argument interface |
| `fd`, `ffind` | Recursive native enumeration piped to fzf; `fd` enters selection, `ffind` returns it; no shell-string bat preview |
| `fode` | Pipeline paths (or current files) → fzf multiple selection → `code`; cancellation performs no edit |
| `croot` | New native Git-root navigation helper |
| `repo` | Browser URL synthesis not ported; use Git remote commands / `croot` |
| `cwd`, `o`, `v` | Native clipboard, Invoke-Item, Neovim (current directory if no argument) |
| `week`, `lcmd`, `lastchanged` | ISO week, session history search, newest file objects; `lastchanged Path Count` |
| `activate`, `p`, `ip3` | Windows venv `Scripts/Activate.ps1`, `python`, `ipython` |
| `top` | Invokes independently installed `btop`, or the upstream Windows port `btop4win`; no monitor installed automatically |
| `bat`, `rg`, `fzf`, Python, Git, Neovim | Use native applications directly |
| `pubkey`, `prikey` | No SSH-reading or key-copying shortcut introduced |
| `fkill`, `fzchmod`, `prune-branches`, `restart_gpgagent`, process/signal helpers | Not ported; use reviewed native commands; Unix signals/permissions are not Windows semantics |
| `fapt`, `gpip`, `install-appimage`, systemd/X11/DBus helpers, `battery`, `hosts`, `flush`, IP/traceroute aliases | Linux/macOS assumptions retained only in Bash; no guessed Windows system mutation |
| `calc`, `fs`, `targz`, `gz`, encoding/JSON/DNS/TLS/encryption, Go and formatter helpers, other Bash functions | Not exported by the Windows module; use the corresponding native tool or PowerShell/.NET directly |
| Shared Git/Neovim configuration | Original preferences, plugins, LSPs, mappings and theme unchanged |

## Windows tools and local verification

Required: PowerShell 7.4+ (.NET 8 APIs) and Git; GNU Make for the Make entry points. Optional:
Neovim, eza, ripgrep, fzf, bat and Python. The reviewed package IDs live in
`scripts/windows/packages.psd1`, matched to
[Microsoft's WinGet manifests](https://github.com/microsoft/winget-pkgs/tree/master/manifests).
No second package manager is introduced. Install selected tools explicitly:

```powershell
# Offline report:
make doctor
# Explicit network/package operation; user-installable tools, or exact IDs:
pwsh -NoProfile -File ./scripts/windows/dependencies.ps1 -Install
pwsh -NoProfile -File ./scripts/windows/dependencies.ps1 -Install -Id eza-community.eza
```

The installer checks exact IDs with `winget show` before installing, requests
user scope, skips applications already on PATH, and stops on the first failure.
Neovim's [current WinGet manifest](https://github.com/microsoft/winget-pkgs/blob/master/manifests/n/Neovim/Neovim/0.12.6/Neovim.Neovim.installer.yaml)
offers a machine-scope MSI only, so the script reports it as manual and continues
with the other tools. For a user installation, download the Windows ZIP from
[Neovim releases](https://github.com/neovim/neovim/releases), extract it to a
folder you own, and add its `bin` directory to your user PATH through Windows
settings. Choosing a Neovim version and installing/updating it is separate from
the unchanged repository plugin configuration.
It neither upgrades installed applications nor accepts agreements on your
behalf. If the package lacks user-scope support, review its official installer
and arrange installation yourself; the script does not retry with elevation.
Python's Windows Store execution alias can appear as `python` even without a
working Python installation; verify `python --version` and manage that alias
through Windows settings if needed.

btop is not provisioned automatically. Its upstream Windows port,
[btop4win](https://github.com/aristocratos/btop4win), can be installed separately;
`top` detects it. The standard variant can run without elevation; hardware-monitor
variants require administration and are outside this setup. `tree` presentation uses eza rather than Windows
`tree.exe` (which has different flags). `code`, IPython, language servers,
Treesitter compiler/build prerequisites, GnuPG and other advanced tools are
independent optional installations. The Lua/Python LSP configuration is shared;
install `lua-language-server` and `pyright` on PATH yourself. Plugin resolution,
compiler integration and upstream runtime compatibility remain unverified;
Neovim's first normal start can use the network, just as on Linux.

```powershell
# On a real Windows 11 machine, from native PowerShell 7:
make --version
make help
make doctor
make test
# The same suite without Make, also usable from PowerShell 7 on Linux:
pwsh -NoLogo -NoProfile -NonInteractive -File ./tests/windows/run.ps1
# Bash lint independently (native ShellCheck required, otherwise diagnostic):
make shellcheck
```

Tests need PowerShell 7.4+, Git and GNU Make. Neovim syntax checking is performed
when nvim exists (otherwise explicitly skipped). No Pester dependency exists.
They parse every declared PowerShell source, use explicit temporary homes,
verify repeat installs and unique backups, shared Git includes/Neovim files,
profile loading/local overrides, missing tools, built-ins, ll with/without eza,
path metacharacters, symlink conflicts and rejected parents, native Make dispatch
and failure codes. Symlink success tests are explicitly skipped on hosts lacking
permission after asserting clean failure; copy mode must still pass. Tests use
mocks and temporary fixtures, do not install anything, access the network, load
the real profile, or execute Neovim plugins. Real HOME/private-directory metadata
is observed without reading private contents, and must remain unchanged.

Development validation used Linux plus a portable PowerShell 7.6.9 runtime:
Linux regression/ShellCheck and the PowerShell suite passed, including GNU
Make's Windows branch via a temporary `pwsh.exe` link. A subsequent Windows 11 run confirmed native `make doctor`, but stopped at the
repeated-copy regression assertion; a complete Windows suite pass is still
pending. Snapshot checks now refresh filesystem metadata and report the installer
output and exact differences on failure. Native Windows process quoting,
WinGet/bootstrap, policy,
Developer Mode/NTFS permissions, Windows Terminal startup, clipboard, editor
integration and plugin runtime still need the above Windows checks and an
interactive smoke test. No cloud CI was added.

## Linux installation

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

# Conservative maintenance record — 2026-11-01

Baseline commit: `d3956c58266a8efc1f72d814523cac80acd604d9`, initially on `main`.
The initial maintenance pass remained uncommitted on
`codex/conservative-maintenance`. At the owner's subsequent request, the
maintenance files were committed locally and integrated into a new `dev` branch.
The pre-existing `.bashrc` edits and untracked `ANALYSIS.md` were excluded from
that commit. That integration did not push or publish changes. No packages or
plugins were installed or upgraded. All 19 baseline tracked files were reviewed, together with the existing
untracked audit. The supplied request ends at “Do not use real network requests,”;
validation uses no network.

## Initial local state and preservation

Initial status:

```text
 M .bashrc
?? ANALYSIS.md
```

`.bashrc` has seven pre-existing added lines with PATH entries for
`/home/ai/.local/bin` and `/home/ai/.opencode/bin`. The entire initial `.bashrc`
and `ANALYSIS.md` were preserved byte-for-byte. Their initial SHA-256 values are:

```text
7cb323f89bd3bac38fdf9dddd55248ae6f52ffe01d44db122b9dcf44ad8c5c01  .bashrc
7747db702bc6a99af724e9093bda2fa26563e65ac667e0b5856d66db8bf8f58a  ANALYSIS.md
```

The original diff, status and copies of these files were recorded under
`/tmp/dotfiles-maintenance-baseline/` during this session. That temporary directory
is supplemental evidence, not durable backup storage. No private-directory
contents were inspected or changed.

## Revalidated findings and disposition

| Finding | Classification | Evidence and implementation/disposition |
| --- | --- | --- |
| Broad hidden-file discovery, basename flattening and forced replacement | SAFE FIX | Baseline Makefile recursively discovered hidden paths without pruning and used `ln -f`. Replaced with 16 explicit file mappings preserving existing tracked destinations; private/untracked paths and recursive discovery excluded. Preflight, unique sibling backups and non-forcing links added. |
| `isup` reversed up/down notifications | SAFE FIX | Baseline condition matched `200 OK` but sent “down.” Swapped the notifications and used curl's numeric status plus transport success. Preserved HTTP-200-only policy, GET/header flags and no redirects. |
| Sourced helper errors exit the shell | SAFE FIX | Verified exits in `mkd`, `tmpd`, `repo`, `openimage`, `fode`, `fzchmod`, `ffind`. Replaced with nonzero returns. Failed creation/directory selection stops the caller; repo propagates failed subshell cd. `golistdeps` stops its existing subshell after failed `gogo`. Existing process-scoped exits remain. |
| Six existing ShellCheck findings | SAFE FIX | Quoted fd search root, checked cd, replaced x-prefixed comparison, passed PID lines through quoted printf and quoted signal to xargs, removed unused fapt variable. fkill's selection pipeline now detects failure inside a subshell with pipefail without changing caller options. |
| Incomplete lint coverage | SAFE FIX | Replaced file-type discovery with 11 explicitly listed Bash sources/scripts. Lints `.aliases`, excludes `.shellcheckrc`, follows annotated sources and propagates failure. Newly exposed `colorflag` unset warning resolved with equivalent empty-default expansion, preserving alias text for unset/empty/set values. Only narrow annotations for shared manifest data and indirect test mocks were added; no global suppressions added. |
| Incomplete dependency/setup documentation | SAFE FIX (documentation); DEFER (provisioning policy) | README now identifies installation prerequisites, optional helpers, external gitdate, language servers and platform assumptions. Existing apt package list unchanged. No dependency provisioning added. |
| Duplicate Neovim LSP setup | CONDITIONAL FIX, deferred | `init.lua` loads plugins then lsp; plugins.lua supplies Lua settings while lsp.lua calls Lua setup again with defaults. Behavioral equivalence of consolidation is not established without exercising the installed plugin versions. No Lua changes made. |
| Unpinned plugin resolution/no lockfile | DEFER | No baseline lockfile/revisions establish intended versions. Choosing pins or resolving now changes dependency policy/versions. Bootstrap and plugin specifications unchanged. |
| `prikey` clipboard exposure | DEFER | Alias explicitly copies a private SSH key. Removing or redesigning it changes intended behavior/security policy; retained and documented. |
| Missing etc/, usr/ and test.sh | SAFE FIX (diagnostics); DEFER (replacement workflows) | Legacy system targets now fail clearly without sudo or guessed source discovery. Docker target fails before Docker when its entrypoint is missing; original command otherwise retained. Removed unused Docker flag calculation. No replacement infrastructure introduced. |
| `.Trash-*<Paste>` | SAFE FIX | The comment and repository ignore establish the intended `.Trash-*` pattern. Corrected and verified with Git check-ignore. Git preferences/identity unchanged. |
| Empty `.bashprofile` | DEFER | It was tracked and installed; external consumers are unknown. Retained in manifest and lint coverage, documented distinctly from `.bash_profile`. |

## Validation and practical limits

`make test` passes ShellCheck for every listed source, installer regression tests,
interactive Bash helper regression tests, Bash syntax, Git config/ignore parsing,
and compilation of the five Neovim Lua files without executing configuration.
The installer tests exercise fresh/repeated installs, absolute and equivalent
relative correct links, regular-file and dangling/directory-symlink conflicts,
real directory and parent conflicts, rejected symlinked parents, spaces/tabs/newlines and
shell metacharacters in source/HOME/nested paths, unexpected hidden resources,
unique backups preserving bytes/mode/ownership/mtime/inode, and manual recovery.
Network, notification, URL opening and process selection/signaling are mocked.
Real HOME and `.aws`/`.agents`/`.codex` directory metadata is unchanged in the
validation run; their contents are not read. The original `.bashrc` and audit
were compared against the saved copies.

No installer run targeted the real HOME. No full startup, plugin runtime, actual
clipboard access, external HTTP requests, package installation, privileged system
installation, or Docker execution was performed. Clean syntax does not prove
upstream plugin compatibility. Installation is sequential and not a concurrent
filesystem transaction; documented recovery and retry apply after I/O failures.

Owner decisions remaining: effective LSP settings/consolidation, plugin revision
and lockfile policy, broader dependency provisioning, `prikey` policy, retirement
of `.bashprofile`, and replacement/removal of legacy system/container targets.

## Native Windows support — 2026-11-01

Based on `dev` at `3414d6b`; implementation lives on
`codex/windows-powershell`. The existing `.bashrc` and `ANALYSIS.md` hashes above
remain unchanged and are excluded from the Windows commits.

Decisions: retain all Bash sources, the Linux manifest/installer and apt default;
require PowerShell 7.4+ for the .NET filesystem APIs; use an `OS=Windows_NT` Make
branch that invokes PowerShell directly, with explicit exit propagation. Windows `all` only installs configuration; package installation
is an explicit WinGet workflow. Native Make is `ezwinports.make` (verified official
manifest, 4.4.1); package IDs are data and rechecked at installation time. User
scope is requested; Neovim’s machine-only MSI is reported for manual portable
installation and skipped. No automatic escalation or competing package manager.

The Windows installer has six explicit shared file mappings, plus a generated
Git include and a marked loader block in runtime CurrentUserAllHosts. It checks
parents, source availability, collisions and directory conflicts before writes.
Symlink capability is probed before configuration changes; Copy requires explicit
selection. Correct links/copies remain untouched; conflicts get unique sibling
rename backups. Existing profile text remains, with a backup before changes.
Reparse parents/profile links require manual resolution, including cloud-backed
ancestors. No private-directory content is accessed. Installation remains
sequential with documented recovery; concurrent mutation is unsupported.

The profile imports a small module once, preserving PowerShell object commands
and `gc`, then loads an optional untracked local override. No network, PATH edits,
agent startup or tool initialization occurs at startup. Shared Git/Neovim content
is unchanged. `.gitattributes` fixes source line endings for Windows checkouts.
The README matrix records exactly which helpers are exported and which remain
Bash-only; no private-key helper or Unix system-mutating equivalent was added.

Local validation: all original Linux regressions and ShellCheck pass; all new
PowerShell regressions pass under portable PowerShell 7.6.9 on Linux. Native GNU
Make exercised the Windows branch through a temporary `pwsh.exe` link, including
special-character checkout paths and failed child exit codes. This does not
validate Windows CreateProcess, NTFS/Developer Mode, WinGet, execution policy,
Windows Terminal, clipboard, plugin runtime or ARM64. Run the README's local
Windows commands and interactive smoke tests before integrating into `dev`.
No packages installed, real-home installation, push, merge, release or CI added.


### First Windows feedback

The owner confirmed native `make doctor` succeeds after fetching the feature
branch and bootstrapping Make. A new terminal launched Windows PowerShell 5.1,
which intentionally does not load the PowerShell 7 profile; README now explains
`pwsh` and the Windows Terminal default-profile setting. The first native
`make test` stopped at the repeated-copy assertion. Snapshot checks now refresh
filesystem metadata before comparing, include content hashes, and retain the
full metadata assertion while reporting the installer exit/output and exact
before/after differences. The failure's cause is not established from the old
generic error. Linux and PowerShell-on-Linux checks pass; a Windows rerun is
required to confirm whether stale metadata was responsible or diagnose a
remaining installer failure. No installer safety check was relaxed.

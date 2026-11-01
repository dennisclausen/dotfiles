#!/bin/bash
# Invoked by run.sh in an isolated interactive Bash. Do not enable errexit:
# each failure must return here so the next assertion can actually run.
repo=$1
work=$2
# shellcheck source=../.functions
source "$repo/.functions"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_failure() {
	if "$@" > "$work/helper.out" 2>&1; then fail "Unexpected success: $*"; fi
}

# Override only dependency lookups; never depend on locally installed editors.
missing=code
# shellcheck disable=SC2329 # Called indirectly by the sourced helpers.
command() {
	if [[ $1 == -v && $2 == "$missing" ]]; then return 1; fi
	if [[ $1 == -v && ( $2 == code || $2 == fzf ) ]]; then return 0; fi
	builtin command "$@"
}
expect_failure fode
grep -qx 'code not found' "$work/helper.out" || fail 'Missing code diagnostic'
missing=fzf
for helper in fode fzchmod ffind; do
	expect_failure "$helper"
	grep -qx 'fzf not found' "$work/helper.out" || fail 'Missing fzf diagnostic'
done
unset -f command

mkdir -p -- "$work/not-a-repo"
cd -- "$work/not-a-repo" || fail 'Test setup'
expect_failure repo
grep -qx 'Not a git repo!' "$work/helper.out" || fail 'repo diagnostic'
# Success retains the existing remote/branch/path URL mapping.
git init -q
# Creating an object would be a commit, which this task forbids; mock only the
# name lookup while exercising actual Git worktree/remote/cdup queries.
git config remote.origin.url git@github.com:example/project.git
# shellcheck disable=SC2329 # Called indirectly by repo().
command() {
	if [[ $1 == git && $2 == name-rev ]]; then printf 'main\n'; else builtin command "$@"; fi
}
open() { printf '%s\n' "$1" > "$work/open.url"; }
repo 'file name.txt' > "$work/repo.out" || fail 'repo success'
[[ $(< "$work/open.url") == 'https://github.com/example/project/tree/main/file name.txt' ]] || fail 'repo URL changed'
unset -f command open

# Failed mkdir, mktemp and cd must return and preserve the caller's directory.
before=$PWD
# shellcheck disable=SC2329 # Called indirectly by mkd().
mkdir() { return 1; }
expect_failure mkd "$work/not-created"
[[ $PWD == "$before" ]] || fail 'mkd continued after mkdir failure'
unset -f mkdir
# shellcheck disable=SC2329 # Called indirectly by tmpd().
mktemp() { return 1; }
expect_failure tmpd
[[ $PWD == "$before" ]] || fail 'tmpd continued after mktemp failure'
unset -f mktemp
# shellcheck disable=SC2329 # Called indirectly by sourced helpers.
cd() { return 1; }
expect_failure mkd "$work/cannot-enter"
expect_failure tmpd
expect_failure openimage "$work/missing/image.jpg"
# shellcheck disable=SC2329 # Must remain uncalled after repo()'s failed cd.
open() { printf called > "$work/unexpected-open"; }
expect_failure repo
[[ ! -e $work/unexpected-open ]] || fail 'repo continued after cd failure'
unset -f open
unset -f cd
mkd "$work/new directory [*]" || fail 'mkd success'
[[ $PWD == "$work/new directory [*]" ]] || fail 'mkd quoting'
cd -- "$before" || fail 'Test setup'

# fd preserves one complete directory argument and returns on selection/cd error.
find() { printf '%s\n' "$@" > "$work/find.args"; printf '%s\n' "$work/new directory [*]"; }
fzf() { cat; }
fd "$work/search path [*]" || fail 'fd success'
mapfile -t args < "$work/find.args"
[[ ${#args[@]} == 3 && ${args[0]} == "$work/search path [*]" && ${args[1]} == -type && ${args[2]} == d ]] || fail 'fd split path'
[[ $PWD == "$work/new directory [*]" ]] || fail 'fd quoting'
# shellcheck disable=SC2329 # Called indirectly by fd().
fzf() { return 130; }
expect_failure fd
# shellcheck disable=SC2329 # Called indirectly by fd().
fzf() { cat > /dev/null; printf '%s\n' "$work/does-not-exist"; }
expect_failure fd
unset -f find fzf

# Capture numeric status handling, transport status, arguments and notifications.
curl() { printf '%s\0' "$@" > "$work/curl.args"; printf '%s' "$http_status"; return "$transport_status"; }
notify-send() { printf '%s\n' "$@" > "$work/notify.args"; }
uri='https://example.invalid/path with space?x=[*]'
for scenario in 200 500 301 204 transport; do
	http_status=$scenario
	transport_status=0
	if [[ $scenario == transport ]]; then http_status=200; transport_status=7; fi
	isup "$uri" || fail 'isup notification failed'
	mapfile -t args < "$work/notify.args"
	if [[ $scenario == 200 ]]; then
		[[ ${args[0]} == --urgency=low && ${args[1]} == "$uri is up" ]] || fail '200 notification'
	else
		[[ ${args[0]} == --urgency=critical && ${args[1]} == "$uri is down" ]] || fail "$scenario notification"
	fi
	mapfile -d '' -t args < "$work/curl.args"
	[[ ${args[*]} == "-s --head --request GET --output /dev/null --write-out %{http_code} -- $uri" ]] || fail 'curl method/options/URL changed'
done
unset -f curl notify-send

# Do not signal real processes. Verify fkill passes every selected PID and one
# signal argument, including multiple selections and the empty selection case.
ps() { printf 'UID PID\nuser 123\nuser 456\n'; }
fzf() { cat; }
xargs() {
	printf '%s\n' "$@" > "$work/kill.args"
	cat > "$work/kill.pids"
}
fkill TERM || fail 'fkill success'
[[ $(< "$work/kill.args") == $'kill\n-TERM' && $(< "$work/kill.pids") == $'123\n456' ]] || fail 'fkill PID/signal handling'
fkill || fail 'fkill default signal'
[[ $(< "$work/kill.args") == $'kill\n-9' ]] || fail 'fkill default changed'
rm -- "$work/kill.args"
fzf() { cat > /dev/null; }
fkill || fail 'fkill empty selection'
[[ ! -e $work/kill.args ]] || fail 'fkill signaled on empty selection'
# shellcheck disable=SC2329 # Called indirectly by fkill().
fzf() { cat > /dev/null; return 130; }
expect_failure fkill
[[ ! -e $work/kill.args ]] || fail 'fkill signaled after cancellation'
unset -f ps fzf xargs
# shellcheck disable=SC2329 # Called indirectly by golistdeps().
gogo() { return 1; }
mkdir -p -- "$work/bin"
printf '#!/bin/bash\nprintf called > %q\n' "$work/unexpected-go" > "$work/bin/go"
chmod +x "$work/bin/go"
export PATH="$work/bin:$PATH"
expect_failure golistdeps project
[[ ! -e $work/unexpected-go ]] || fail 'golistdeps continued after directory failure'
unset -f gogo
printf 'survived\n' > "$work/helpers.completed"
printf 'PASS: interactive shell survived helper failures; success paths, quoting, isup and PID handling\n'

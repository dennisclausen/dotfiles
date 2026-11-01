# Match .bash_prompt without writing Git's index or changing native exit status.
function global:prompt {
    $previousExit = $global:LASTEXITCODE
    $location = Get-Location
    $path = $location.Path
    if ($path -eq $HOME) { $path = '~' }
    elseif ($path.StartsWith($HOME + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $path = '~' + $path.Substring($HOME.Length)
    }
    $blue, $cyan, $green, $violet, $white, $reset = '', '', '', '', '', ''
    if ($Host.UI.SupportsVirtualTerminal -and $PSStyle.OutputRendering -ne 'PlainText') {
        $blue = "`e[1;38;5;33m"
        $cyan = "`e[1;38;5;37m"
        $green = "`e[1;38;5;64m"
        $violet = "`e[1;38;5;61m"
        $white = "`e[1;38;5;15m"
        $reset = "`e[0m"
    }
    $gitText = ''
    try {
        $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($git -and $location.Provider.Name -eq 'FileSystem') {
            $status = @(& $git --no-optional-locks -C $location.Path status --porcelain=v2 --branch --show-stash --untracked-files=normal 2>$null)
            if ($LASTEXITCODE -eq 0) {
                $branch = ''
                $oid = ''
                $staged = $false
                $modified = $false
                $untracked = $false
                $stashed = $false
                foreach ($line in $status) {
                    switch -Regex ($line) {
                        '^# branch.head (.+)$' { $branch = $Matches[1] }
                        '^# branch.oid (.+)$' { $oid = $Matches[1] }
                        '^# stash ' { $stashed = $true }
                        '^[12] (..)' {
                            $staged = $staged -or $Matches[1][0] -ne '.'
                            $modified = $modified -or $Matches[1][1] -ne '.'
                        }
                        '^u ' { $staged = $true; $modified = $true }
                        '^\? ' { $untracked = $true }
                    }
                }
                if ($branch -eq '(detached)') { $branch = $oid.Substring(0, 7) }
                $markers = ''
                if ($staged) { $markers += '+' }
                if ($modified) { $markers += '!' }
                if ($untracked) { $markers += '?' }
                if ($stashed) { $markers += '$' }
                if ($markers) { $markers = "${blue} [$markers]" }
                if ($branch) { $gitText = "${white} on ${violet}${branch}${markers}" }
            }
        }
    } catch {
        # An unavailable repository/tool must leave an ordinary usable prompt.
        $gitText = ''
    } finally { $global:LASTEXITCODE = $previousExit }
    "`n${blue}$([Environment]::UserName)${white} at ${cyan}$([Environment]::MachineName)${white} in ${green}${path}${gitText}`n${white}$ ${reset}"
}

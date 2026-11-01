#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Symlink', 'Copy')][string] $Mode = 'Copy',
    [string] $TargetHome,
    [string] $ProfilePath,
    [string] $LocalAppData
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"
try {
    $repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    if ($TargetHome) {
        if (-not $ProfilePath -or -not $LocalAppData) {
            throw 'Custom TargetHome requires explicit ProfilePath and LocalAppData (no real-user fallbacks).'
        }
    } else {
        if (-not $IsWindows) { throw 'Windows installer requires Windows, or all three explicit disposable paths for tests.' }
        $TargetHome = [Environment]::GetFolderPath('UserProfile')
        if (-not $ProfilePath) { $ProfilePath = $PROFILE.CurrentUserAllHosts }
        if (-not $LocalAppData) { $LocalAppData = [Environment]::GetFolderPath('LocalApplicationData') }
    }
    foreach ($path in @($TargetHome, $ProfilePath, $LocalAppData)) {
        if (-not [IO.Path]::IsPathFullyQualified($path)) { throw "Expected absolute filesystem path: $path" }
    }
    $TargetHome = [IO.Path]::GetFullPath($TargetHome)
    $ProfilePath = [IO.Path]::GetFullPath($ProfilePath)
    $LocalAppData = [IO.Path]::GetFullPath($LocalAppData)
    if (-not (Test-Path -LiteralPath $TargetHome -PathType Container) -or
        $TargetHome -eq [IO.Path]::GetPathRoot($TargetHome) -or $TargetHome -eq $repo) {
        throw 'TargetHome must be an existing non-root directory different from the repository.'
    }
    $manifest = Import-PowerShellDataFile -LiteralPath "$PSScriptRoot/manifest.psd1"
    $roots = @{ Home = $TargetHome; Local = $LocalAppData }
    $plan = @()
    foreach ($entry in $manifest.Shared) {
        Assert-DotfilesRelativePath $entry.Source
        Assert-DotfilesRelativePath $entry.Destination
        if (-not $roots.ContainsKey($entry.Root)) { throw "Unknown manifest root: $($entry.Root)" }
        $plan += [pscustomobject]@{ Source = Join-Path $repo $entry.Source
            Destination = Join-Path $roots[$entry.Root] $entry.Destination; Content = $null }
    }
    # Git's include path uses forward slashes, with Git-config string escaping.
    function Quote-GitPath([string] $Path) { '"' + $Path.Replace('\', '/').Replace('"', '\"') + '"' }
    $gitContent = "# Managed by dotfiles. Local overrides load last.`n[include]`n`tpath = $(Quote-GitPath (Join-Path $repo 'gitconfig'))`n[core]`n`texcludesfile = $(Quote-GitPath (Join-Path $TargetHome '.gitignore'))`n[include]`n`tpath = $(Quote-GitPath (Join-Path $TargetHome '.gitconfig.local'))`n"
    $plan += [pscustomobject]@{ Source = $null; Destination = Join-Path $TargetHome '.gitconfig'; Content = $gitContent }
    $begin = '# >>> dotfiles PowerShell >>>'
    $end = '# <<< dotfiles PowerShell <<<'
    Assert-DotfilesParents $ProfilePath
    $profileItem = Get-DotfilesItem $ProfilePath
    if ($profileItem -and ($profileItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Profile is a symlink/reparse point; integrate powershell/profile.ps1 manually or choose a regular profile.'
    }
    if ($profileItem -and $profileItem.PSIsContainer) { throw "Directory conflict: $ProfilePath" }
    $existing = if ($profileItem) { [IO.File]::ReadAllText($ProfilePath) } else { '' }
    $escapedLoader = (Join-Path $repo 'powershell/profile.ps1').Replace("'", "''")
    $block = "$begin`nif (Test-Path -LiteralPath '$escapedLoader' -PathType Leaf) { . '$escapedLoader' }`n$end"
    $pattern = '(?ms)^' + [regex]::Escape($begin) + '\r?\n.*?^' + [regex]::Escape($end)
    $matches = [regex]::Matches($existing, $pattern)
    if ($matches.Count -gt 1 -or
        ([regex]::Matches($existing, [regex]::Escape($begin)).Count -ne $matches.Count) -or
        ([regex]::Matches($existing, [regex]::Escape($end)).Count -ne $matches.Count)) {
        throw 'Ambiguous managed profile markers; repair manually before installation.'
    }
    $profileContent = if ($matches.Count) {
        [regex]::Replace($existing, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $block })
    } else { $existing + "`n" + $block + "`n" }
    $plan += [pscustomobject]@{ Source = $null; Destination = $ProfilePath; Content = $profileContent }

    # Complete preflight before creating directories, backups, or destinations.
    $destinations = @{}
    foreach ($entry in $plan) {
        $dest = [IO.Path]::GetFullPath($entry.Destination)
        if ($destinations.ContainsKey($dest)) { throw "Duplicate destination: $dest" }
        $destinations[$dest] = $true
        Assert-DotfilesParents $dest
        if ($dest -eq $repo -or $dest.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Destination is inside the repository: $dest"
        }
        $item = Get-DotfilesItem $dest
        if ($item -and $item.PSIsContainer) { throw "Directory conflict: $dest; move it aside manually." }
        if ($entry.Source -and -not (Test-Path -LiteralPath $entry.Source -PathType Leaf)) { throw "Missing source: $($entry.Source)" }
    }
    foreach ($left in $destinations.Keys) {
        foreach ($right in $destinations.Keys) {
            if ($left.StartsWith($right + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Overlapping destinations: $left and $right"
            }
        }
    }
    foreach ($source in @($manifest.ProfileSources) + @($manifest.Shared.Source)) {
        Assert-DotfilesRelativePath $source
        $sourcePath = Join-Path $repo $source
        Assert-DotfilesParents $sourcePath
        $sourceItem = Get-DotfilesItem $sourcePath
        if (-not $sourceItem -or $sourceItem.PSIsContainer -or
            ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Missing or linked source: $source"
        }
    }

    if ($Mode -eq 'Copy') {
        Write-Warning 'Copy mode copies shared files. Rerun make dotfiles after repository updates to refresh the copies. Live links require explicit -Mode Symlink and Windows symlink permission.'
    }
    if ($Mode -eq 'Symlink') {
        # Probe capability before backing up anything. Never elevate or switch modes.
        $probe = Join-Path $TargetHome ('.dotfiles-link-probe.' + [guid]::NewGuid().ToString('N'))
        try { [void][IO.File]::CreateSymbolicLink($probe, (Join-Path $repo 'gitignore')) }
        catch { throw 'Cannot create symlinks. Enable Developer Mode yourself, or explicitly rerun with -Mode Copy. No configuration was changed.' }
        finally { if (Get-DotfilesItem $probe) { [IO.File]::Delete($probe) } }
    }
    foreach ($entry in $plan) {
        $dest = $entry.Destination
        $item = Get-DotfilesItem $dest
        if ($entry.Source) {
            if ($Mode -eq 'Symlink' -and (Test-DotfilesLink $item $entry.Source)) { continue }
            if ($Mode -eq 'Copy' -and $item -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
                (Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath $entry.Source).Hash) { continue }
        } elseif ($item -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
            [IO.File]::ReadAllText($dest) -ceq $entry.Content) { continue }
        New-DotfilesParents $dest
        if ($item) { Backup-DotfilesFile $dest }
        if (-not $entry.Source) { [IO.File]::WriteAllText($dest, $entry.Content, [Text.UTF8Encoding]::new($false)) }
        elseif ($Mode -eq 'Copy') { [IO.File]::Copy($entry.Source, $dest, $false) }
        else { [void][IO.File]::CreateSymbolicLink($dest, $entry.Source) }
        Write-Host "Installed ($Mode): $dest"
    }
    Write-Host 'Installation complete. Open a new PowerShell 7 session.'
    exit 0
} catch {
    Write-Error "dotfiles: $_" -ErrorAction Continue
    exit 1
}

# Shared installer primitives. Literal paths only; never walk private directories.
Set-StrictMode -Version Latest

function Get-DotfilesItem([string] $Path) {
    try { Get-Item -LiteralPath $Path -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { return $null }
}

function Assert-DotfilesParents([string] $Path) {
    $parent = [IO.Path]::GetDirectoryName($Path)
    while ($parent) {
        $item = Get-DotfilesItem $parent
        if ($item) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Symlinked/reparse parent: $parent; use real directories."
            }
            if (-not $item.PSIsContainer) { throw "Parent is not a directory: $parent" }
        }
        $parent = [IO.Path]::GetDirectoryName($parent)
    }
}

function New-DotfilesParents([string] $Path) {
    Assert-DotfilesParents $Path
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
}

function Backup-DotfilesFile([string] $Path) {
    $backup = "$Path.dotfiles-backup.$([guid]::NewGuid().ToString('N'))"
    [void][IO.Directory]::CreateDirectory($backup)
    # Same-filesystem rename preserves original bytes, metadata and link target.
    [IO.File]::Move($Path, (Join-Path $backup 'original'))
    Write-Host "Backup: $backup/original -> $Path"
}

function Test-DotfilesLink([object] $Item, [string] $Source) {
    if (-not $Item -or -not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
    $target = $Item.LinkTarget
    if (-not $target) { return $false }
    if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path $Item.DirectoryName $target }
    return [IO.Path]::GetFullPath($target) -eq [IO.Path]::GetFullPath($Source)
}

function Assert-DotfilesRelativePath([string] $Path) {
    $normalized = $Path.Replace('\', '/')
    if (-not $normalized -or [IO.Path]::IsPathRooted($Path) -or $normalized.Contains(':') -or
        $normalized -match '(^|/)(\.{1,2}|\.ssh|\.aws|\.codex|\.agents|\.git)(/|$)' -or
        $normalized.Contains('//') -or $normalized.EndsWith('/')) {
        throw "Invalid manifest path: $Path"
    }
}

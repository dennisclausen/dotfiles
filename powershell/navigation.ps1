function .. { Set-Location -LiteralPath '..' }
function ... { Set-Location -LiteralPath '../..' }
function .... { Set-Location -LiteralPath '../../..' }
function ..... { Set-Location -LiteralPath '../../../..' }
function dl { Set-Location -LiteralPath (Join-Path $HOME 'Downloads') }
function mkd {
    param([Parameter(Mandatory, Position = 0)][string] $Path)
    [void][IO.Directory]::CreateDirectory($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))
    Set-Location -LiteralPath $Path -ErrorAction Stop
}
function tmpd {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles.' + [guid]::NewGuid().ToString('N'))
    mkd $path
}
function croot {
    $root = g rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0) { throw 'Not a Git working tree.' }
    Set-Location -LiteralPath $root -ErrorAction Stop
}
function fd {
    param([string] $Path = '.')
    $fzf = Get-DotfilesTool fzf
    $paths = Get-ChildItem -LiteralPath $Path -Directory -Recurse -ErrorAction Stop | Select-Object -ExpandProperty FullName
    $selection = $paths | & $fzf +m
    if ($LASTEXITCODE -ne 0 -or -not $selection) { return }
    Set-Location -LiteralPath $selection -ErrorAction Stop
}

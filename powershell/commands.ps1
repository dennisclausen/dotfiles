# Resolve optional applications at invocation time (including after installation).
function Get-DotfilesTool([string] $Name) {
    $tool = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $tool) { throw "$Name is required for this helper. Run make doctor for dependency information." }
    return $tool
}
function Invoke-DotfilesTool([string] $Name, [object[]] $Arguments) {
    $tool = Get-DotfilesTool $Name
    & $tool @Arguments
    # Native exit status must survive the module boundary.
    $global:LASTEXITCODE = $LASTEXITCODE
}
function g { Invoke-DotfilesTool git $args }
function ga { Invoke-DotfilesTool git (@('add') + $args) }
function subsub { Invoke-DotfilesTool git (@('submodule', 'update', '--init', '--recursive') + $args) }
function gitsetoriginnopush { Invoke-DotfilesTool git @('remote', 'set-url', '--push', 'origin', 'no_push') }
function rgi { Invoke-DotfilesTool rg (@('-i') + $args) }
function grepr { Invoke-DotfilesTool rg (@('-i') + $args) }
function p { Invoke-DotfilesTool python $args }
function ip3 { Invoke-DotfilesTool ipython $args }
function top {
    if (Get-Command btop -CommandType Application -ErrorAction SilentlyContinue) { Invoke-DotfilesTool btop $args }
    else { Invoke-DotfilesTool btop4win $args }
}
function v {
    $arguments = if ($args.Count) { $args } else { @('.') }
    Invoke-DotfilesTool nvim $arguments
}
function o {
    param([string] $Path = '.')
    Invoke-Item -LiteralPath $Path
}
function cwd { (Get-Location).Path | Set-Clipboard }
function week { [Globalization.ISOWeek]::GetWeekOfYear([datetime]::Now) }
function lcmd { param([string] $Text) Get-History | Where-Object CommandLine -Like "*$Text*" }

function Invoke-DotfilesListing {
    param([string[]] $Flags, [object[]] $Paths, [switch] $Hidden, [switch] $Directories)
    $eza = Get-Command eza -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($eza) { & $eza @Flags @Paths; $global:LASTEXITCODE = $LASTEXITCODE; return }
    if (-not $Paths.Count) { $Paths = @('.') }
    foreach ($path in $Paths) {
        Get-ChildItem -LiteralPath $path -Force:$Hidden -Directory:$Directories
    }
}
function ll { Invoke-DotfilesListing -Flags @('-la') -Paths $args -Hidden }
function l { Invoke-DotfilesListing -Flags @('-lh') -Paths $args }
function la { Invoke-DotfilesListing -Flags @('-lah') -Paths $args -Hidden }
function lsd { Invoke-DotfilesListing -Flags @('-l', '--only-dirs') -Paths $args -Directories }
function lsg { Invoke-DotfilesTool eza (@('--git-ignore', '--git') + $args) }
function Invoke-DotfilesTree([int] $Depth, [object[]] $Paths) {
    Invoke-DotfilesTool eza (@('--tree', '--level', "$Depth", '--git-ignore') + $Paths)
}
function tree1 { Invoke-DotfilesTree 1 $args }
function tree2 { Invoke-DotfilesTree 2 $args }
function tree3 { Invoke-DotfilesTree 3 $args }
function tree4 { Invoke-DotfilesTree 4 $args }
function tree5 { Invoke-DotfilesTree 5 $args }
function tree6 { Invoke-DotfilesTree 6 $args }
function tre { Invoke-DotfilesTool eza (@('--tree', '-a', '--group-directories-first', '--ignore-glob=.git') + $args) }

function ffind {
    param([Parameter(Mandatory, Position = 0)][string] $Path)
    $fzf = Get-DotfilesTool fzf
    # No shell-string previews: filenames are data, never code. Use bat on the result.
    Get-ChildItem -LiteralPath $Path -File -Recurse -ErrorAction Stop |
        Select-Object -ExpandProperty FullName | & $fzf +m
    $global:LASTEXITCODE = $LASTEXITCODE
}
function fode {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][string] $Path)
    begin { $paths = [Collections.Generic.List[string]]::new(); $fzf = Get-DotfilesTool fzf; $editor = Get-DotfilesTool code }
    process { if ($Path) { $paths.Add($Path) } }
    end {
        if (-not $paths.Count) {
            Get-ChildItem -File | ForEach-Object { $paths.Add($_.FullName) }
        }
        $selection = @($paths | & $fzf --multi)
        if ($LASTEXITCODE -ne 0 -or -not $selection.Count) { return }
        & $editor -- @selection
        $global:LASTEXITCODE = $LASTEXITCODE
    }
}
function activate {
    foreach ($name in @('venv', '.venv')) {
        $path = Join-Path (Get-Location).Path $name
        $script = Join-Path $path 'Scripts/Activate.ps1'
        if (Test-Path -LiteralPath $script -PathType Leaf) {
            if ($env:VIRTUAL_ENV -ne $path) {
                # Activate.ps1 intentionally defines global deactivate and updates env.
                . $script
            }
            return
        }
    }
    throw 'No venv/Scripts/Activate.ps1 or .venv/Scripts/Activate.ps1 found.'
}
function lastchanged {
    param([string] $Path = '.', [int] $Count = 10)
    Get-ChildItem -LiteralPath $Path -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First $Count
}

#Requires -Version 7.4
[CmdletBinding()]
param([switch] $Install, [string[]] $Id)
$ErrorActionPreference = 'Stop'
try {
    $manifest = Import-PowerShellDataFile -LiteralPath "$PSScriptRoot/packages.psd1"
    $packages = $manifest.Packages
    if ($Id) {
        foreach ($selected in $Id) { if ($selected -notin $packages.Id) { throw "Unknown package ID: $selected" } }
        $packages = @($packages | Where-Object Id -In $Id)
    }
    if ($Install) {
        if (-not $IsWindows) { throw 'Dependency installation is Windows-only.' }
        $manual = @($packages | Where-Object { $_.ContainsKey('ManualInstall') -and $_.ManualInstall })
        if ($Id -and $manual.Count) { throw 'Neovim.Neovim currently offers a machine-scope MSI only. Use the official portable Windows ZIP for a user installation; see README.' }
        foreach ($package in $manual) { Write-Host "Manual optional setup: $($package.Id); see README for the portable user installation." }
        $packages = @($packages | Where-Object { -not ($_.ContainsKey('ManualInstall') -and $_.ManualInstall) })
        $winget = Get-Command winget -CommandType Application -ErrorAction Stop | Select-Object -First 1
        # Validate all IDs against the live source before installing any package.
        foreach ($package in $packages) {
            & $winget show --exact --id $package.Id --source winget --disable-interactivity
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        foreach ($package in $packages) {
            if (Get-Command $package.Command -CommandType Application -ErrorAction SilentlyContinue) { continue }
            # User scope prevents an automatic machine-wide/elevated install. Some
            # packages may not offer it; report winget's failure for manual handling.
            & $winget install --exact --id $package.Id --source winget --scope user --disable-interactivity
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        if (-not $Id) {
            foreach ($command in $manifest.ManualCommands) {
                if (-not (Get-Command $command -CommandType Application -ErrorAction SilentlyContinue)) {
                    Write-Host "Manual optional setup: $command; see README."
                }
            }
        }
        Write-Host 'Open a new terminal to refresh PATH; then run make doctor.'
    } else {
        foreach ($package in $packages) {
            $tool = Get-Command $package.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            [pscustomobject]@{ Command = $package.Command; Required = $package.Required
                Available = [bool]$tool; WingetId = $package.Id }
        }
        if (-not $Id) {
            foreach ($command in $manifest.ManualCommands) {
                [pscustomobject]@{ Command = $command; Required = $false
                    Available = [bool](Get-Command $command -CommandType Application -ErrorAction SilentlyContinue)
                    WingetId = '(manual optional setup; see README)' }
            }
        }
    }
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }

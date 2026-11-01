#Requires -Version 7.4
# Dot-source from CurrentUserAllHosts. No installs, network, PATH edits or agents.
if (Get-Module -Name Dotfiles) { return }
Import-Module -Name (Join-Path $PSScriptRoot 'Dotfiles.psm1') -Global -NoClobber -ErrorAction Stop
# Untracked machine customizations run once, after the shared functions.
$dotfilesLocalProfile = Join-Path (Split-Path -Parent $PROFILE.CurrentUserAllHosts) 'dotfiles.local.ps1'
if (Test-Path -LiteralPath $dotfilesLocalProfile -PathType Leaf) { . $dotfilesLocalProfile }
Remove-Variable dotfilesLocalProfile

#Requires -Version 7.4
# Explicit Make-only dependency installation. Never called by the profile/tests.
& "$PSScriptRoot/dependencies.ps1" -Install -Id ezwinports.make
exit $LASTEXITCODE

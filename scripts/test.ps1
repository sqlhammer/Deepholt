# Runs the GUT test suite headless, with no editor window, and exits non-zero
# on any test failure. See work/chunks/M0/M0-01-project-skeleton.md.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$gamePath = Join-Path $repoRoot "game"

$godotBin = $env:GODOT_BIN
if (-not $godotBin) {
	$onPath = Get-Command "godot" -ErrorAction SilentlyContinue
	if ($onPath) {
		$godotBin = $onPath.Source
	}
}

if (-not $godotBin) {
	Write-Error "Godot executable not found. Set GODOT_BIN to its full path, or put 'godot' on your PATH."
	exit 1
}

& $godotBin `
	--headless `
	--path $gamePath `
	-s "res://addons/gut/gut_cmdln.gd" `
	-gdir=res://tests `
	-ginclude_subdirs `
	-gexit

exit $LASTEXITCODE

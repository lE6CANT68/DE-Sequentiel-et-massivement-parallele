# Campagne d'expériences du sujet pour la version CPU
#   4 fonctions x Dim (10, 50, 100) x Pop (50, 100, 500) x 10 graines
#
# Utilisation (depuis le dossier CPU, après .\build.ps1) :
#   .\run_campagne.ps1                      # stratégie 0 (DE/rand/1/bin), 10 runs
#   .\run_campagne.ps1 -Strategies 0,3      # plusieurs stratégies
#   .\run_campagne.ps1 -Dims 10 -Runs 3     # campagne réduite pour tester
#
# Écrit ..\resultats\cpu_<strategie>.csv (une ligne par run, même format que le GPU)
# puis affiche un résumé : moyenne et écart-type de l'erreur, temps moyen, taux de succès.
# Les runs sont lancés un par un pour ne pas fausser les temps mesurés.

param(
    [int[]]$Strategies = @(0),
    [int[]]$Fonctions  = @(0, 1, 2, 3),
    [int[]]$Dims       = @(10, 50, 100),
    [int[]]$Pops       = @(50, 100, 500),
    [int]$Runs         = 10
)

$ErrorActionPreference = "Stop"
$exe = Join-Path $PSScriptRoot "de_sequentiel.exe"
if (-not (Test-Path $exe)) {
    Write-Host "de_sequentiel.exe introuvable : lancez d'abord .\build.ps1" -ForegroundColor Red
    exit 1
}

$dossier = Join-Path $PSScriptRoot "..\resultats"
New-Item -ItemType Directory -Force $dossier | Out-Null
$dossier = (Resolve-Path $dossier).Path

$inv = [Globalization.CultureInfo]::InvariantCulture
$nomsStrategies = @{ 0 = "rand1"; 1 = "best1"; 2 = "current-to-best1"; 3 = "jDE" }
$SEUIL_SUCCES = 1e-8   # un run réussit si erreur < 1e-8 (comme dans l'article)

foreach ($s in $Strategies) {
    $fichier = Join-Path $dossier ("cpu_" + $nomsStrategies[$s] + ".csv")
    $lignes = New-Object System.Collections.Generic.List[string]
    $lignes.Add((& $exe --entete))

    $total = $Fonctions.Count * $Dims.Count * $Pops.Count * $Runs
    $n = 0
    $debut = Get-Date
    foreach ($f in $Fonctions) {
        foreach ($d in $Dims) {
            foreach ($p in $Pops) {
                for ($g = 1; $g -le $Runs; $g++) {
                    $n++
                    Write-Progress -Activity ("CPU " + $nomsStrategies[$s]) `
                        -Status "fonction $f, dim $d, pop $p, graine $g ($n/$total)" `
                        -PercentComplete (100 * $n / $total)
                    $ligne = & $exe $f $d $p $g $s
                    if ($LASTEXITCODE -ne 0) { throw "Echec : de_sequentiel $f $d $p $g $s" }
                    $lignes.Add($ligne)
                }
            }
        }
    }
    Write-Progress -Activity ("CPU " + $nomsStrategies[$s]) -Completed
    [System.IO.File]::WriteAllLines($fichier, $lignes)
    $duree = (Get-Date) - $debut
    Write-Host ("`n" + $nomsStrategies[$s] + " : $total runs en " + [int]$duree.TotalSeconds + " s -> $fichier") -ForegroundColor Green

    # ---------- Résumé par configuration ----------
    $resume = Import-Csv $fichier | Group-Object fonction, dim, pop | ForEach-Object {
        $err   = $_.Group | ForEach-Object { [double]::Parse($_.erreur, $inv) }
        $temps = $_.Group | ForEach-Object { [double]::Parse($_.temps_s, $inv) }
        $moy = ($err | Measure-Object -Average).Average
        $var = 0.0
        foreach ($e in $err) { $var += ($e - $moy) * ($e - $moy) }
        $ecart = if ($err.Count -gt 1) { [Math]::Sqrt($var / ($err.Count - 1)) } else { 0.0 }
        $succes = @($err | Where-Object { $_ -lt $SEUIL_SUCCES }).Count / $err.Count
        [PSCustomObject]@{
            fonction     = $_.Group[0].fonction
            dim          = [int]$_.Group[0].dim
            pop          = [int]$_.Group[0].pop
            erreur_moy   = $moy.ToString("0.000e+00", $inv)
            erreur_ecart = $ecart.ToString("0.000e+00", $inv)
            temps_moy_s  = ($temps | Measure-Object -Average).Average.ToString("0.000", $inv)
            succes       = $succes.ToString("0.00", $inv)
        }
    }
    $resume | Format-Table -AutoSize | Out-String | Write-Host
}

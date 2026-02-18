Write-Host "Hockey Agent starting..."

function Get-RosterFit {
    param(
        [Parameter(Mandatory=$true)] $Player,
        [Parameter(Mandatory=$true)] $Roster
    )

    $pos = ($Player.position ?? "").ToUpper()
    $shoots = ($Player.shoots ?? "").ToUpper()

    if ($pos -eq "D") {
        # Defense: use handedness to suggest LD/RD. If missing, allow both.
        $target = if ($shoots -eq "L") { "LD" } elseif ($shoots -eq "R") { "RD" } else { "LD/RD" }

        $openPairs = @()

        foreach ($pairNum in 1..3) {
            $pairPlayers = $Roster.defense | Where-Object { $_.pair -eq $pairNum }
            $hasLD = $pairPlayers.pos -contains "LD"
            $hasRD = $pairPlayers.pos -contains "RD"

            # Identify missing side (super simple logic)
            if (-not $hasLD) { $openPairs += [pscustomobject]@{ slot="Pair $pairNum LD"; reason="No LD listed on pair $pairNum" } }
            if (-not $hasRD) { $openPairs += [pscustomobject]@{ slot="Pair $pairNum RD"; reason="No RD listed on pair $pairNum" } }
        }

        # If no "open" slots, just suggest pairs by best positional match
        if ($openPairs.Count -eq 0) {
            $suggestions = if ($target -eq "LD") { @("Pair 2 LD","Pair 3 LD") }
                          elseif ($target -eq "RD") { @("Pair 2 RD","Pair 3 RD") }
                          else { @("Pair 2 LD","Pair 2 RD","Pair 3 LD","Pair 3 RD") }

            return $suggestions | ForEach-Object {
                [pscustomobject]@{ slot=$_; reason="Depth suggestion for $target" }
            }
        }

        # Filter to handedness match when possible
        if ($target -eq "LD") { return $openPairs | Where-Object { $_.slot -like "*LD" } }
        if ($target -eq "RD") { return $openPairs | Where-Object { $_.slot -like "*RD" } }
        return $openPairs
    }

    # Forwards: suggest line based on matching position
    $matches = $Roster.forwards | Where-Object { $_.pos -eq $pos }

    if ($matches.Count -eq 0) {
        return @([pscustomobject]@{ slot="Unknown"; reason="No roster matches for position $pos" })
    }

    return $matches |
        Sort-Object line |
        ForEach-Object {
            [pscustomobject]@{
                slot   = "Line $($_.line) $pos"
                reason = "Matches position $pos; comparable to $($_.name)"
            }
        }
}


# -------------------------
# MAIN SCRIPT (run pipeline)
# -------------------------

# Load player + roster JSON files
$player = Get-Content ./inputs/player_upload.json -Raw | ConvertFrom-Json
$roster = Get-Content ./data/avalanche_roster.json -Raw | ConvertFrom-Json

# Run roster fit
$fit = Get-RosterFit -Player $player -Roster $roster

# Display results
Write-Host ""
Write-Host "Uploaded player:" $player.player_name "(" $player.position "," $player.shoots ")"
Write-Host ""

$fit | Format-Table -AutoSize


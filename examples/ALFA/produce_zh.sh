#!/bin/bash
# Produce EDM4hep files with the ALFA Delphes cards: e+e- -> ZH (Z -> nu nu, H -> xx) at 240 GeV.
#
# Usage: produce_zh.sh <card: Xe2bar|C4F10> <decay: bb|cc|ss|uu|dd|gg> <chunk> <nevents> <output.edm4hep.root>
#
# The Pythia seed depends only on (decay, chunk), so the two cards see identical generated events and differ by the
# detector only. The Delphes RandomSeed is set to the same value.
# Needs: a key4hep environment and this k4SimDelphes built against a Delphes with the ARCTracing module (see README.md);
#        DelphesPythia8_EDM4HEP of that build first in PATH, or K4SIMDELPHES_BIN pointing to it.
set -eu
CARD=$1; DECAY=$2; CHUNK=$3; NEV=$4; OUT=$5
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN=${K4SIMDELPHES_BIN:-$(command -v DelphesPythia8_EDM4HEP)}
declare -A HDEC=([bb]="25:onIfMatch = 5 -5" [cc]="25:onIfMatch = 4 -4" [ss]="25:onIfMatch = 3 -3"
                 [uu]="25:onIfMatch = 2 -2" [dd]="25:onIfMatch = 1 -1" [gg]="25:onIfMatch = 21 21")
declare -A DID=([bb]=1 [cc]=2 [ss]=3 [uu]=4 [dd]=5 [gg]=6)
[ -n "${HDEC[$DECAY]:-}" ] || { echo "unknown decay $DECAY"; exit 2; }
[ -f "$HERE/cards/delphes_card_ALFA_$CARD.tcl" ] || { echo "unknown card $CARD"; exit 2; }
SEED=$(( 100000 * ${DID[$DECAY]} + CHUNK + 1 ))
WORK=$(mktemp -d)
sed -e "s/@DECAY@/$DECAY/; s/@NEV@/$NEV/; s/@HDECAY@/${HDEC[$DECAY]}/; s/@SEED@/$SEED/" \
    "$HERE/pythia/zh_Hxx_template.cmnd" > "$WORK/zh.cmnd"
# the ARC cell and optical tables are addressed relative to the card: make them absolute for the temporary copy
sed -e "s/^set RandomSeed .*/set RandomSeed $SEED/" -e "s| cards/arc/| $HERE/cards/arc/|" "$HERE/cards/delphes_card_ALFA_$CARD.tcl" > "$WORK/card.tcl"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT";; esac
"$BIN" "$WORK/card.tcl" "$HERE/edm4hep_output_config_ALFA.tcl" "$WORK/zh.cmnd" "$OUT"
rm -rf "$WORK"

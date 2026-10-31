# ALFA: EDM4hep production with the ARC particle identification

Delphes cards of the ALFA detector concept (FCC-ee) with the ARC RICH simulated by ray tracing (the `ARCTracing`
Delphes module), in two gas variants, and everything needed to produce EDM4hep files with k4SimDelphes, including the
ARC particle identification of every track.

| file | content |
|---|---|
| `cards/delphes_card_ALFA_Xe2bar.tcl` | ALFA, ARC gas = xenon at 2 bar (main design), aerogel n = 1.030 |
| `cards/delphes_card_ALFA_C4F10.tcl` | ALFA, ARC gas = C4F10 at 1 bar (comparison) |
| `cards/arc/cells_ALFA_o1_v01.txt`, `cards/arc/arc_optics_tables.txt` | the ARC cell optics of k4geo ALFA_o1_v01 and the optical tables the module reads |
| `edm4hep_output_config_ALFA.tcl` | k4SimDelphes output configuration for the ALFA cards |
| `pythia/zh_Hxx_template.cmnd` | Pythia8: e+e- -> ZH at 240 GeV, Z -> nu nu, H -> xx (placeholders filled by the script) |
| `produce_zh.sh` | one EDM4hep file: `produce_zh.sh <Xe2bar\|C4F10> <bb\|cc\|ss\|uu\|dd\|gg> <chunk> <nevents> <out.root>` |

The two cards are identical except for the gas table of the ARC. The cards and the tables are the ones of the Delphes
fork below (`cards/` there); the module and its validation against the Geant4 full simulation are described in
`examples/ALFA/README.md` of that fork.

## Which ARC configuration the cards describe

The validation and the design study use three labels; the cards in this repository are **B**:

| label | aerogel | SiPM arrays | status |
|---|---|---|---|
| A | n = 1.019, 10 mm | 80 x 80 mm (as built) | validated (blind) |
| **B** | **n = 1.030, 10 mm** | **80 x 80 mm (as built in k4geo ALFA_o1_v01)** | **validated; the two cards here** |
| C | n = 1.030, 10 mm | 89.6 mm barrel / 108.8 mm endcap, the largest that fit the cells | validated (blind); the optimised design |

Both cards state this in their first lines. To run the optimised design, change one line in either card:
`set CellFile cards/arc/cells_ALFA_o1_v01_bigSiPM.txt` (the table is included). Everything else -- gas, pixels,
mirrors, reconstruction -- is identical. A dedicated `delphes_card_ALFA_optimised.tcl` will follow.

## Requirements: Delphes with the ARCTracing module

The cards use the `ARCTracing` Delphes module and its `Track` members. They are not in Delphes master: build Delphes
from the `alfa-arc` branch of the ALFA fork (upstream delphes/delphes master `b0465ee` plus the module and the cards):

```bash
source /cvmfs/sw-nightlies.hsf.org/key4hep/setup.sh      # ROOT, Pythia8, HepMC, EDM4hep, podio
git clone -b alfa-arc https://github.com/apranikstar/delphes.git delphes-alfa
cd delphes-alfa && ./configure && make -j8 HAS_PYTHIA8=true && cd ..
```

## Build k4SimDelphes against it

```bash
git clone -b alfa https://github.com/apranikstar/k4SimDelphes.git && cd k4SimDelphes
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=../install -DBUILD_FRAMEWORK=OFF -DBUILD_EVTGEN_READER=OFF -DBUILD_TESTING=OFF \
         -DDELPHES_LIBRARY=$PWD/../../delphes-alfa/libDelphes.so \
         -DDELPHES_INCLUDE_DIR=$PWD/../../delphes-alfa \
         -DDELPHES_EXTERNALS_INCLUDE_DIR=$PWD/../../delphes-alfa/external
make -j8 install
```

CMake prints `Delphes has ARCTracing: EFlowTrack_PID filled with the ARC hypotheses` when the ARC members are found.
Pass the Delphes paths explicitly: otherwise the Delphes of the key4hep stack (without the module) may be picked up.
The installed binaries carry the right RPATH (this branch moves `include(GNUInstallDirs)` before the key4hep
configuration so the install RPATH is `lib64` on EL9), so no `LD_LIBRARY_PATH` or `LD_PRELOAD` is needed.

## Run

```bash
K4SIMDELPHES_BIN=$PWD/install/bin/DelphesPythia8_EDM4HEP \
  examples/ALFA/produce_zh.sh Xe2bar bb 0 10000 Hbb_Xe2bar_0.edm4hep.root
```

About 100 events/s per core. The Pythia seed depends only on (decay, chunk): Xe2bar and C4F10 files of the same chunk
contain the same generated events. The usual k4SimDelphes command also works with any Pythia card, run from
`examples/ALFA` so that the card finds `cards/arc/`:
`DelphesPythia8_EDM4HEP cards/delphes_card_ALFA_Xe2bar.tcl edm4hep_output_config_ALFA.tcl <pythia.cmnd> <out.root>`.

## Output

The standard k4SimDelphes collections (`ReconstructedParticles`, `EFlowTrack` with track states and covariance,
`EFlowPhoton`, `EFlowNeutralHadron`, `Particle`, `RecoMCLink`, `Jet`, `Muon`, `Electron`, `Photon`, `MissingET`,
`magFieldBz`, ...), plus the ARC result in **`EFlowTrack_PID`**: one `edm4hep::ParticleID` per track, linked to its
`ReconstructedParticle` (`particle` relation), with

| field | meaning |
|---|---|
| `type`, `algorithmType` | 1023 (ARC) |
| `PDG` | best pi/K/p hypothesis (signed), 0 = no ring in either radiator |
| `likelihood` | P(K) |
| `parameters[0..9]` | P(pi), P(K), P(p), reconstructed Cherenkov angle gas / aerogel [rad], per-track resolution gas / aerogel [rad], photons in the ring gas / aerogel, mass of the best hypothesis [GeV]; -1 = no ring |

The probabilities are exp(-chi2/2) normalised over the three hypotheses with equal priors, the chi2 summed over the two
radiators with a missing ring costing -2 ln P(0 | expected photons). In FCCAnalyses the values are read from
`EFlowTrack_PID`, `_EFlowTrack_PID_particle` (index into `ReconstructedParticles`) and `_EFlowTrack_PID_parameters`.

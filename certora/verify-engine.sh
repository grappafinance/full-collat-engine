certoraRun src/FullMarginEngine.sol:FullMarginEngine certora/harness/GrappaExtended.sol \
    --verify FullMarginEngine:certora/engine-grappa.spec \
    --link FullMarginEngine:grappa=GrappaExtended \
    --solc_allow_path src \
    --optimistic_loop \
    --packages  solmate=lib/solmate/src \
                openzeppelin=lib/openzeppelin-contracts/contracts \
                grappa-core/=lib/core-cash/src \
                openzeppelin-upgradeable=lib/core-cash/lib/openzeppelin-contracts-upgradeable/contracts 
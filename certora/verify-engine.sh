certoraRun certora/harness/FullMarginEngineHarness.sol certora/harness/GrappaHarness.sol \
    --verify FullMarginEngineHarness:certora/engine-grappa.spec \
    --link FullMarginEngineHarness:grappa=GrappaHarness \
    --solc_allow_path src \
    --optimistic_loop \
    --packages  solmate=lib/solmate/src \
                openzeppelin=lib/openzeppelin-contracts/contracts \
                grappa-core/=lib/core-cash/src \
                openzeppelin-upgradeable=lib/core-cash/lib/openzeppelin-contracts-upgradeable/contracts 
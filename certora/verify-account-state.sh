certoraRun certora/harness/FullMarginEngineHarness.sol \
    --verify FullMarginEngineHarness:certora/account-state.spec \
    --solc_allow_path src \
    --optimistic_loop \
    --packages  solmate=lib/solmate/src \
                openzeppelin=lib/openzeppelin-contracts/contracts \
                grappa-core/=lib/core-cash/src 
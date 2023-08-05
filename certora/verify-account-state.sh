certoraRun src/FullMarginEngine.sol \
    --verify FullMarginEngine:certora/account-state.spec \
    --solc_allow_path src \
    --optimistic_loop \
    --packages  solmate=lib/solmate/src \
                openzeppelin=lib/openzeppelin-contracts/contracts \
                grappa-core/=lib/core-cash/src 
certoraRun src/FullMarginEngine.sol:FullMarginEngine \
    --verify FullMarginEngine:certora/account-state.spec \
    --rule account_well_collateralized \
    --solc_allow_path src \
    --optimistic_loop \
    --packages  solmate=lib/solmate/src \
                openzeppelin=lib/openzeppelin-contracts/contracts \
                grappa-core/=lib/core-cash/src
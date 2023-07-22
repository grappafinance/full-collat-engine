certoraRun src/FullMarginEngine.sol:FullMarginEngine \
    --verify FullMarginEngine:certora/engine.spec \
    --solc_allow_path src \
    --packages solmate=lib/solmate/src openzeppelin=lib/openzeppelin-contracts/contracts grappa-core/=lib/core-cash/src
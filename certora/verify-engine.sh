certoraRun src/FullMarginEngine.sol:FullMarginEngine lib/core-cash/src/core/Grappa.sol lib/core-cash/src/core/CashOptionToken.sol \
    --verify FullMarginEngine:certora/engine-grappa.spec \
    --link FullMarginEngine:grappa=Grappa FullMarginEngine:optionToken=CashOptionToken CashOptionToken:grappa=Grappa \
    --solc_allow_path src \
    --optimistic_loop \
    --packages  solmate=lib/solmate/src \
                openzeppelin=lib/openzeppelin-contracts/contracts \
                grappa-core/=lib/core-cash/src \
                openzeppelin-upgradeable=lib/core-cash/lib/openzeppelin-contracts-upgradeable/contracts 
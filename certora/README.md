# Certora Rules

The spec is split up in different files to make sure we can efficiently run all checks:

1. `account-state.spec`: focus only on the `FullMarginEngine`'s account storage structure. (State transitioning)
2. `engine-grappa.spec`: link Grappa with the full engine contract, focus on higher level properties.

**Running the script**

Make sure `solc` is a installed command on your terminal, with `solc --version` equals 0.8.18.

```sh
./certora/verify-account-state.sh

./certora/verify-engine.sh

```

## List of Properties

### High level contract design

1. asset balance can only decrease with `execute` function or `Grappa.settle`

### System Properties

- [ ] 1. sum of all Grappa.getPayout() <= total asset
- [ ] 2. get min collateral <= account.collateral for all accounts
- [ ] 3. transferAccount doesn't affect the total collateral requirement
- [ ] 4. cannot mint call or put with no collateral (no rounding error)
- [x] 5. a vault always has more collateral than the total payout the token it mints worth.

### Invariants: Data structure

These can be found in `account-state.spec`

- [x] 1. if account.shortAmount != 0, account.tokenId must not be 0. (no hanging debt with no ID)
- [x] 2. if account.collateralAmount != 0, collateralId must not be 0. (no hanging collateral)
- [x] 3. if account.collateral != 0 && account.short != 0 => collateral id in account.collateralId must match the one derived from token
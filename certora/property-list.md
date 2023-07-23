# Invariant Properties

## High level contract design

1. asset balance can only decrease with `execute` function and `requestPayout`

## Margining

1. sum of all Grappa.getPayout() <= total asset 
2. get min collateral <= account.collateral for all accounts
3. transferAccount doesn't affect the total collateral requirement
4. cannot mint call or put with no collateral (rounding)

## Invariants: Data structure

- [x] 1. if account.shortAmount != 0, account.tokenId must not be 0. (no hanging debt with no ID)
- [x] 2. if account.collateralAmount != 0, collateralId must not be 0. (no hanging collateral)
- [x] 3. 
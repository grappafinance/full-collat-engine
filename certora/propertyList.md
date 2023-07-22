# Invariant Properties

## High level contract design

1. asset balance can only decrease with `execute` function and `requestPayout`

## Margining

1. sum of all Grappa.getPayout() <= total asset 
2. get min collateral <= account.collateral for all accounts
3. transferAccount doesn't affect the total collateral requirement

## Data structure

1. if account.shortAmount == 0, account.tokenId == 0
2. if account.tokenId != 0, collateralId parsed from token id must == account.collateralId
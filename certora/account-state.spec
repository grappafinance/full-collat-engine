import "base.spec";

/* ======================================= *
 *          Property functions
 * ======================================= */

// if there is short amount, there must be short id
function noShortAmountWithoutShortId(address acc) returns bool {
    uint256 shortAmount = getAccountShortAmount(acc);
    uint256 shortId = getAccountShortToken(acc);
    
    return (shortAmount != 0) => (shortId != 0);
}

// if there is collateral amount, there must be collateral id
function noCollatAmountWithoutCollatId(address acc) returns bool {
    uint256 collateralAmount = getAccountCollateralAmount(acc);
    uint256 collatId = getAccountCollatId(acc);

    return (collateralAmount != 0) => (collatId != 0);
}

// if collateral and short id are both non-zero, they must match
function collateralIdFromTokenMatch(address acc) returns bool { 
    uint256 shortId; uint64 shortAmount; uint256 collatId; uint80 collatAmount;
    shortId, shortAmount, collatId, collatAmount = marginAccounts(acc);

    // assume we have a valid shortId (non 0)
    require getCollatIdFromTokenId(shortId) != 0;

    // testing: whenever there's short, collateral id must be non 0 && matched
    return (shortId != 0) => (collatId != 0 && getCollatIdFromTokenId(shortId) == collatId);
}


/* ======================================= *
 *               Invariants
 * ======================================= */

/// if shorted amount is non 0, then short id MUST NOT be 0
invariant account_no_unknown_debt(env e, address acc) noShortAmountWithoutShortId(acc) {

    // while evaluating method transferAccount, assume that the {from} account already satisfy this rule!
    preserved transferAccount(address from, address to) with (env e2) {
        require noShortAmountWithoutShortId(from);
    }
}

/// if shorted token id is 0 (no short), then short amount MUST be 0. Vice versa.
invariant account_no_unknown_collateral(env e, address acc) noCollatAmountWithoutCollatId(acc) {
    // todo: reserach better method than reverting collatId == 0 in code.

    // while evaluating method transferAccount, assume that the {from} account already satisfy this rule!
    preserved transferAccount(address from, address to) with (env e2) {
        require noCollatAmountWithoutCollatId(from);
    }
}

// if an account has collat Id and short token id, collateral id derived from tokenId must equal collatId
invariant account_collateral_match(env e, address acc) collateralIdFromTokenMatch(acc) {

    // while evaluating method transferAccount, assume that the {from} account already satisfy this rule!
    preserved transferAccount(address from, address to) with (env e2) {
        require collateralIdFromTokenMatch(from);
    }
    
    // make sure we starting with empty account, no bad shortId can exist
    // todo: use grappa.checkTokenId instead of this assumption?
    preserved { 
      require(accountIsEmpty(acc));
    }
}

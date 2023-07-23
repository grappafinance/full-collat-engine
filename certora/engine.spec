/* ======================================= *
 *              Declarations
 * ======================================= */
methods {
  function getMinCollateral(address) external returns(uint) envfree; 

  function marginAccounts(address) external returns(uint256, uint64, uint8, uint80) envfree;

  function onERC1155BatchReceived(address,address,uint256[],uint256[],bytes) external returns (bytes4) envfree;

  function onERC1155Received(address,address,uint256,uint256,bytes) external returns (bytes4) envfree;

  function grappa() external returns (address) envfree;

  function optionToken() external returns (address) envfree;

  function allowedExecutionLeft(uint160,address) external returns (uint) envfree;

  function getMinCollateral(address) external returns (uint) envfree;
}

/* ======================================= *
 *        Account Storage Helpers
 * ======================================= */

function getAccountShortAmount(address acc) returns uint64 {
    uint64 shortAmount; 
    _, shortAmount, _, _ = marginAccounts(acc); 
    return shortAmount;
}

function getAccountCollateralAmount(address acc) returns uint80 {
    uint80 collateral; 
    _, _, _, collateral = marginAccounts(acc); 
    return collateral;
}

function getAccountShortToken(address acc) returns uint256 {
    uint256 tokenId;
    tokenId, _, _, _ = marginAccounts(acc); 
    return tokenId;
}

function getAccountCollatId(address acc) returns uint8 {
    uint8 collatId;
    _, _, collatId, _ = marginAccounts(acc); 
    return collatId;
}

function getCollatIdFromTokenId(uint256 tokenId) returns uint256 {
    uint256 uint8Mask = 255;
    return (tokenId >> (192)) & uint8Mask;
}

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

function accountWellCollateralized(address acc) returns bool {
    uint collateralRequied = getMinCollateral(acc);
    uint collateralDeposited = getAccountCollateralAmount(acc);
    return collateralDeposited >= collateralRequied;
}

function accountIsEmpty(address acc) returns bool {
    uint256 shortId; uint64 shortAmount; uint256 collatId; uint80 collatAmount;
    shortId, shortAmount, collatId, collatAmount = marginAccounts(acc);
    return shortAmount == 0 && collatAmount == 0 && shortId == 0 && collatId == 0;
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

// // if an account is well collateralized, it must be well collateralized after any execution
// invariant account_well_collateralized(env e, address acc) accountWellCollateralized(acc);
    
/* ======================================= *
 *                 Rules
 * ======================================= */

//  rule checkExecuteDoesntPutAccountUnderwater(address acc) {
//     env e;
//     require accountWellCollateralized(acc);
    
//     FullMarginEngine.ActionArgs[] args;

//     // execute with arbitrary args on an account
//     execute(e, acc, args);

//     assert accountWellCollateralized(acc);
//  }
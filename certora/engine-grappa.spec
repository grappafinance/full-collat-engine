import "base.spec";
import "account-state.spec";

using GrappaExtended as grappa;

methods {
  // calling grappa.assets should not change over time
  function grappa.assets(uint8) external returns(address, uint8) envfree;

  function grappa.getPayout(uint256,uint64) external returns (address,address,uint256);

  function grappa.checkIsValidTokenIdToMint(uint256) external;

  function checkTokenIdToMint(uint256) external envfree;
}


/* ==================================================== *
 *
 *    This spec has Grappa linked at Engine.grappa()
 *                  
 * ==================================================== */

function accountWellCollateralized(address acc) returns bool {
    uint collateralRequied = getMinCollateral(acc);
    uint collateralDeposited = getAccountCollateralAmount(acc);
    return collateralDeposited >= collateralRequied;
}


// // if an account is well collateralized, it must be well collateralized after any execution
// invariant account_well_collateralized(env e, address acc) accountWellCollateralized(acc);
    
/* ======================================= *
 *                 Rules
 * ======================================= */

/**
 * @title Account always solvent
 * @notice querying grappa for payout for an account will always be coverable by the collateral in the account
 */
rule accountAlwaysSolvent(address acc) {
    env e;

    require accountWellCollateralized(acc);
    require collateralIdFromTokenMatch(acc);
    
    uint256 tokenId; uint64 shortAmount; uint256 collatAmount; address collateral; uint256 payout; uint8 collatId;

    tokenId, shortAmount, collatId, collatAmount = marginAccounts(acc);
    
    checkTokenIdToMint(tokenId);
    grappa.checkIsValidTokenIdToMint(e, tokenId);
    require !lastReverted;

    collateral, _ = grappa.assets(collatId);

    _, _, payout = grappa.getPayout(e, tokenId, shortAmount);


    assert collatAmount >= payout;
 }
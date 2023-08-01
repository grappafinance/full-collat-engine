import "base.spec";

methods {
  // calling grappa.assets should not change over time
  function Grappa.assets(uint8) external returns(address, uint8) => CONSTANT;
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

 rule checkExecuteDoesntPutAccountUnderwater(address acc) {
    env e;
    require accountWellCollateralized(acc);
    
    FullMarginEngine.ActionArgs[] args;

    // execute with arbitrary args on an account
    execute(e, acc, args);

    assert accountWellCollateralized(acc);
 }
/** 
 * declare methods used in this spec
 */
methods {
  function FullMarginEngine.getMinCollateral(address) external returns(uint) envfree; 

  function FullMarginEngine.marginAccounts(address) external returns(uint256, uint64, uint8, uint80) envfree;

  // function FullMarginEngine.payCashValue(address, address, uint256) external;
}

// testing arbitrary docs
// this should not pass: counter example is using transferAccount
rule stateChangeOnlyExecuteFunction(method f, address acc) {
    env e; calldataarg args;
    // Fetch min collateral before a call
    uint256 minCollat = getMinCollateral(acc); 
    
    // arbitrary calls
    f(e,args);
    
    // Fetch min collateral after
    uint256 minCollat_ = getMinCollateral(acc); 
    
    assert minCollat != minCollat_ => 
        f.selector == sig:execute(address,FullMarginEngine.ActionArgs[]).selector, 
        "single point of execution not preserved!";   
}
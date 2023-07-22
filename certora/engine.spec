/** 
 * methods used in this spec
 */
methods {
  function getMinCollateral(address) external returns(uint) envfree; 

  function marginAccounts(address) external returns(uint256, uint64, uint8, uint80) envfree;

  function onERC1155BatchReceived(address,address,uint256[],uint256[],bytes) external returns (bytes4) envfree;

  function onERC1155Received(address,address,uint256,uint256,bytes) external returns (bytes4) envfree;

  function grappa() external returns (address) envfree;

  function optionToken() external returns (address) envfree;

  function allowedExecutionLeft(uint160,address) external returns (uint) envfree;
}

/**
 * helper functions to get properties of margin accounts
 */
function getAccountShortAmount(address acc) returns uint64 {
    uint64 shortAmount; 
    _, shortAmount, _, _ = marginAccounts(acc); 
    return shortAmount;
}

function getAccountShortToken(address acc) returns uint256 {
    uint256 tokenId;
    tokenId, _, _, _ = marginAccounts(acc); 
    return tokenId;
}

// if short token id is 0 (no short), then short amount MUST be 0
invariant account_no_unknown_debt(env e, address acc) (getAccountShortToken(acc) == 0) => (getAccountShortAmount(acc) == 0) {

    // while evaluating method transferAccount, assume that the {from} account satisfy this rule!
    preserved transferAccount(address from, address to) with (env e2) {
        require (getAccountShortToken(from) == 0) => (getAccountShortAmount(from) == 0);
    }
}

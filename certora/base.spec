/* ======================================= *
 *              Declarations
 * ======================================= */
methods {
  function getMinCollateral(address) external returns(uint256) envfree; 

  function marginAccounts(address) external returns(uint256, uint64, uint8, uint80) envfree;

  function onERC1155BatchReceived(address,address,uint256[],uint256[],bytes) external returns (bytes4) envfree;

  function onERC1155Received(address,address,uint256,uint256,bytes) external returns (bytes4) envfree;

  function grappa() external returns (address) envfree;

  function optionToken() external returns (address) envfree;

  function allowedExecutionLeft(uint160,address) external returns (uint256) envfree;

  // functions defined in Hardness
  function getMinCollateralByTokenId(uint256) external returns (uint256) envfree;
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

function accountIsEmpty(address acc) returns bool {
    uint256 shortId; uint64 shortAmount; uint256 collatId; uint80 collatAmount;
    shortId, shortAmount, collatId, collatAmount = marginAccounts(acc);
    return shortAmount == 0 && collatAmount == 0 && shortId == 0 && collatId == 0;
}

function accountWellCollateralized(address acc) returns bool {
    uint collateralRequied = getMinCollateral(acc);
    uint collateralDeposited = getAccountCollateralAmount(acc);
    return collateralDeposited >= collateralRequied;
}

import "base.spec";
import "account-state.spec";

using GrappaHarness as grappa;
using FullMarginEngineHarness as engine;

methods {
  function grappa.assets(uint8) external returns(address, uint8) envfree;

  function grappa.getPayout(uint256,uint64) external returns (address,address,uint256);

  function grappa.checkIsValidTokenIdToMint(uint256) external;

  function grappa.parseAssetsFromTokenId(uint256) external returns (uint8, address, address,address) envfree;

  function engine.checkTokenIdToMint(uint256) external envfree;
}

function check_token_type_fully_collateralized(uint8 tokenTypeToCheck, uint256 tokenId) {
    env e;

    // assume this token doesn't have underlying == strike (ETH - ETH option)
    address underlying; address strike; uint8 tokenType;
    tokenType, underlying, strike, _  = grappa.parseAssetsFromTokenId(e, tokenId);
    require underlying != strike; 
    require tokenType == tokenTypeToCheck;

    // ensure that the tokenId is valid to be minted by Grappa (inclulding not expired)
    grappa.checkIsValidTokenIdToMint(e, tokenId);
    engine.checkTokenIdToMint(tokenId);
    require !lastReverted;

    // different env, pass of time is allowed
    env e2;
    require e2.block.timestamp > e.block.timestamp;

    // query grappa at settlement, with amount of token this account minted
    uint256 payout;
    _, _, payout = grappa.getPayout(e2, tokenId, 1000000);

    uint256 collateralRequirement;
    collateralRequirement = engine.getMinCollateralByTokenId(tokenId);

    assert collateralRequirement >= payout;
}

/* ======================================= *
 *                 Rules
 * ======================================= */

rule put_fully_collateralized(uint256 tokenId) {
    check_token_type_fully_collateralized(0, tokenId);
}

rule put_spread_fully_collateralized(uint256 tokenId) {
    check_token_type_fully_collateralized(1, tokenId);
}

rule call_fully_collateralized(uint256 tokenId) {
    check_token_type_fully_collateralized(2, tokenId);
}

// rule call_spread_fully_collateralized(uint256 tokenId) {
//     check_token_type_fully_collateralized(3, tokenId);
// }
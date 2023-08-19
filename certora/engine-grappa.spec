import "base.spec";
import "account-state.spec";

using GrappaHarness as grappa;
using FullMarginEngineHarness as engine;
using MockOracle as oracle;

methods {
  function grappa.assets(uint8) external returns(address, uint8) envfree;

  function grappa.getPayout(uint256,uint64) external returns (address,address,uint256);

  function grappa.checkIsValidTokenIdToMint(uint256) external;

  function grappa.parseAssetsFromTokenId(uint256) external returns (uint8, address, address,address, uint8, uint8, uint8) envfree;

  function grappa.parseExpiryAndStrikes(uint256) external returns (uint64, uint64, uint64) envfree;

  function engine.checkTokenIdToMint(uint256) external envfree;

  /// use MockOracle as a reference implementation
  function _.getPriceAtExpiry(address, address, uint256) external => DISPATCHER(true);

  function oracle.getPriceAtExpiry(address, address, uint256) external returns (uint256, bool) envfree;
}

definition UNIT() returns uint64 = 10^6;

/**
 * Check if a particular token type is fully collateralized, in other words, no matter what the price is at expiry, 
 * the payout can always be covered by required collateral
 * 
 * We need to split the spec to mutiple rules to avoid hitting timeouts
 **/
function check_token_type_fully_collateralized(uint8 tokenTypeToCheck, uint256 tokenId) {
    env e;
    // assume this token doesn't have underlying == strike (something like ETH - ETH option)
    uint8 tokenType; address underlying; address strike; uint8 underlyingId; uint8 strikeId;
    tokenType, underlying, strike, _, underlyingId, strikeId, _ = grappa.parseAssetsFromTokenId(tokenId);
    require underlying != strike; 
    require underlyingId != strikeId;

    // satisfy input token type to check
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
    _, _, payout = grappa.getPayout(e2, tokenId, UNIT());

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

rule call_spread_fully_collateralized_by_strike(uint256 tokenId) {
    address strike; address collateral;
    _, _, strike, collateral, _, _, _  = grappa.parseAssetsFromTokenId(tokenId);
    require collateral == strike;
    check_token_type_fully_collateralized(3, tokenId);
}

rule call_spread_fully_collateralized_by_underlying(uint256 tokenId) {
    address underlying; address strike; address collateral; uint8 underlyingId; uint8 collateralId;
    _, underlying, strike, collateral, underlyingId, _, collateralId  = grappa.parseAssetsFromTokenId(tokenId);
    
    require collateral == underlying;
    // extra constraint to specify ids are the same, 
    // excluding the scenarios where Grappa could have multiple ids point to same address or vice versa (which is impossible)
    require collateralId == underlyingId;

    uint64 longStrike; uint64 shortStrike; uint256 expiryPrice; bool isFinalized; uint64 expiry;
    expiry, longStrike, shortStrike = grappa.parseExpiryAndStrikes(tokenId);
    expiryPrice, isFinalized = oracle.getPriceAtExpiry(underlying, strike, expiry);

    require isFinalized;
    // require expiryPrice > assert_uint256(longStrike);
    require expiryPrice > assert_uint256(shortStrike);
    
    check_token_type_fully_collateralized(3, tokenId);
}
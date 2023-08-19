// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {Grappa} from "grappa-core/core/Grappa.sol";
import {TokenIdUtil} from "grappa-core/libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "grappa-core/libraries/ProductIdUtil.sol";
import {TokenType} from  "grappa-core/config/enums.sol";

contract GrappaHarness is Grappa {
  constructor(address _optionToken) Grappa (_optionToken) {}

  function checkIsValidTokenIdToMint(uint256 tokenId) external view {
    return _isValidTokenIdToMint(tokenId);
  }

  function getPayoutPerToken(uint256 tokenId) external view returns (uint256 payout) {
    (, , payout) = _getPayoutPerToken(tokenId);
  }

  function parseAssetsFromTokenId(uint256 tokenId) external view returns (
    uint8 tokenTypeUint8, 
    address underlying, 
    address strike, 
    address collateral,
    uint8 underlyingId,
    uint8 strikeId,
    uint8 collateralId
  ) {
    
    (TokenType tokenType, uint40 productId, , , ) = TokenIdUtil.parseTokenId(tokenId);
    (, , underlyingId, strikeId, collateralId) = ProductIdUtil.parseProductId(productId);
    underlying = assets[underlyingId].addr;
    strike = assets[strikeId].addr;
    collateral = assets[collateralId].addr;

    tokenTypeUint8 = uint8(tokenType);

  }

  function parseExpiryAndStrikes(uint256 tokenId) external view returns (uint64 expiry, uint64 primary, uint64 secondary) {
    (, , expiry, primary, secondary) = TokenIdUtil.parseTokenId(tokenId);
  }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FullMarginEngine} from "src/FullMarginEngine.sol";
import {FullMarginLib} from "src/FullMarginLib.sol";
import {TokenIdUtil} from  "grappa-core/libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "grappa-core/libraries/ProductIdUtil.sol";

import {TokenType} from  "grappa-core/config/enums.sol";

/**
 * @title FullMarginEngineExtended
 * @dev expose more functions for certora formal verification
 */
contract FullMarginEngineExtended is FullMarginEngine {
  constructor(address _grappa, address _optionToken) FullMarginEngine(_grappa, _optionToken) {}

  function checkTokenIdToMint(uint256 tokenId) external view {
    (TokenType optionType, uint40 productId,,,) = TokenIdUtil.parseTokenId(tokenId);
    (,, uint8 underlyingId, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);
    FullMarginLib.checkProductToMint(optionType, underlyingId, strikeId, collateralId);
  }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FullMarginEngine} from "src/FullMarginEngine.sol";
import {FullMarginLib} from "src/FullMarginLib.sol";
import {FullMarginMath} from "src/FullMarginMath.sol";
import {FullMarginDetail} from "src/types.sol";

import {TokenIdUtil} from  "grappa-core/libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "grappa-core/libraries/ProductIdUtil.sol";

import {TokenType} from  "grappa-core/config/enums.sol";

/**
 * @title FullMarginEngineHarness
 * @dev expose more functions for certora formal verification
 */
contract FullMarginEngineHarness is FullMarginEngine {
  constructor(address _grappa, address _optionToken) FullMarginEngine(_grappa, _optionToken) {}

  function checkTokenIdToMint(uint256 tokenId) external view {
    (TokenType optionType, uint40 productId,,,) = TokenIdUtil.parseTokenId(tokenId);
    (,, uint8 underlyingId, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);
    FullMarginLib.checkProductToMint(optionType, underlyingId, strikeId, collateralId);
  }

  function getMinCollateralByTokenId(uint256 tokenId) external view returns (uint256) {
    (TokenType tokenType, uint40 productId,, uint64 primaryStrike, uint64 secondaryStrike) = TokenIdUtil.parseTokenId(tokenId);

    (,,, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

    bool collateralizedWithStrike = collateralId == strikeId;

    (, uint8 collateralDecimals) = grappa.assets(collateralId);
    FullMarginDetail memory detail = FullMarginDetail({
        shortAmount: 1000000, // 1 unit
        longStrike: secondaryStrike,
        shortStrike: primaryStrike,
        collateralAmount: 0,
        collateralDecimals: collateralDecimals,
        collateralizedWithStrike: collateralizedWithStrike,
        tokenType: tokenType
    });
    return FullMarginMath.getCollateralRequirement(detail);
  }
}
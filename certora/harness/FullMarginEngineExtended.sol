// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FullMarginEngine} from "src/FullMarginEngine.sol";
import {FullMarginLib} from "src/FullMarginLib.sol";

/**
 * @title FullMarginEngineExtended
 * @dev expose more functions for certora formal verification
 */
contract FullMarginEngineExtended is FullMarginEngine {
  constructor(address _grappa, address _optionToken) FullMarginEngine(_grappa, _optionToken) {}

  function checkTokenIdToMint(uint256 tokenId) external view {
    return FullMarginLib.checkTokenIdToMint(tokenId);
  }
}
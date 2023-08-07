// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {Grappa} from "grappa-core/core/Grappa.sol";

contract GrappaHarness is Grappa {
  constructor(address _optionToken) Grappa (_optionToken) {}

  function checkIsValidTokenIdToMint(uint256 tokenId) external view {
    return _isValidTokenIdToMint(tokenId);
  }
}
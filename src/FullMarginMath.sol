// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {NumberUtil} from "grappa-core/src/libraries/NumberUtil.sol";

import {UNIT, UNIT_DECIMALS} from "grappa-core/src/config/constants.sol";

// Full margin types
import "./types.sol";
import {FM_UnsupportedTokenType} from "./errors.sol";

/**
 * @title   FullMarginMath
 * @notice  this library is in charge of calculating the min collateral for a given simple margin account
 */
library FullMarginMath {
    using FixedPointMathLib for uint256;

    /**
     * @notice get minimum collateral requirement denominated in strike asset
     * @param _account margin account
     * @return minCollat minimum collateral in the native collateral asset's decimals
     */
    function getCollateralRequirement(FullMarginDetail memory _account) internal pure returns (uint256 minCollat) {
        // don't need collateral
        if (_account.shortAmount == 0) return 0;

        // amount with UNIT decimals
        uint256 unitAmount;

        if (_account.tokenType == TokenType.CALL) {
            // call option must be collateralized with underlying
            unitAmount = _account.shortAmount;
        } else if (_account.tokenType == TokenType.CALL_SPREAD) {
            // if long strike <= short strike, all loss is covered, amount = 0
            // only consider when long strike > short strike
            if (_account.longStrike > _account.shortStrike) {
                // only call spread can be collateralized by both strike or underlying
                if (_account.collateralizedWithStrike) {
                    // ex: 2000-4000 call spread with usdc collateral
                    // return (longStrike - shortStrike) * amount / unit

                    unchecked {
                        unitAmount = (_account.longStrike - _account.shortStrike);
                    }
                    unitAmount = unitAmount * _account.shortAmount;
                    unchecked {
                        unitAmount = unitAmount / UNIT;
                    }
                } else {
                    // ex: 2000-4000 call spread with eth collateral
                    unchecked {
                        unitAmount =
                            (_account.longStrike - _account.shortStrike).mulDivUp(_account.shortAmount, _account.longStrike);
                    }
                }
            }
        } else if (_account.tokenType == TokenType.PUT) {
            // put option must be collateralized with strike (USDC) asset
            // unitAmount = shortStrike * amount / UNIT
            unitAmount = _account.shortStrike * _account.shortAmount;
            unchecked {
                unitAmount = unitAmount / UNIT;
            }
        } else if (_account.tokenType == TokenType.PUT_SPREAD) {
            // put spread must be collateralized with strike (USDC) asset
            // if long strike >= short strike, all loss is covered, amount = 0
            // only consider when long strike < short strike
            if (_account.longStrike < _account.shortStrike) {
                // unitAmount = (shortStrike - longStrike) * amount / UNIT

                unchecked {
                    unitAmount = (_account.shortStrike - _account.longStrike);
                }
                unitAmount = unitAmount * _account.shortAmount;
                unchecked {
                    unitAmount = unitAmount / UNIT;
                }
            }
        } else {
            revert FM_UnsupportedTokenType();
        }

        return NumberUtil.convertDecimals(unitAmount, UNIT_DECIMALS, _account.collateralDecimals);
    }
}

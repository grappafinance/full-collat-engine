// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenType} from "grappa-core/src/config/enums.sol";

/// @dev data struct used to stored all information about a short position in storage
/// @param tokenId the grappa token id of minted option (can be call, put, credit / debit call spread, credit / debit put spread)
/// @param shortAmount the amount of short position (6 decimals)
/// @param collateralId the id of collateral
/// @param collateralAmount the amount of collateral, in its native decimals
struct FullMarginAccount {
    uint256 tokenId;
    uint64 shortAmount;
    uint8 collateralId;
    uint80 collateralAmount;
}

/// @dev expanded detail of a full margin account, used to provide all information when calculating collateral requirement
/// @param shortAmount the amount of short position
/// @param longStrike the strike price of long leg of the position (only has value if the position is a spread)
/// @param shortStrike the strike price of short leg of the position
/// @param collateralAmount the amount of collateral, in its native decimals
/// @param collateralDecimals the decimals of collateral
/// @param collateralizedWithStrike whether the position is collateralized with strike asset
struct FullMarginDetail {
    uint256 shortAmount;
    uint256 longStrike;
    uint256 shortStrike;
    uint256 collateralAmount;
    uint8 collateralDecimals;
    bool collateralizedWithStrike;
    TokenType tokenType;
}

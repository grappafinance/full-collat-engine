// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Full margin doesn't support this token type
error FM_UnsupportedTokenType();

/// @dev Full margin doesn't support this action
error FM_UnsupportedAction();

/// @dev Invalid collateral:
///      Call can only be collateralized by underlying (ETH)
///      Put can only be collateralized by strike (USDC)
///      Call spread can be collateralized by underlying or strike (ETH / USDC)
///      Put spread can only be collateralized by strike (USDC)
error FM_CannotMintOptionWithThisCollateral();

/// @dev Cannot mint option token with underlying == strike
error FM_UnderlyingStrikeIdentical();

/// @dev Collateral id is wrong: the id doesn't match the existing collateral
error FM_WrongCollateralId();

/// @dev Invalid tokenId specify to mint / burn actions
error FM_InvalidToken();

/// @dev Trying to merge an long with a non-existent short position
error FM_ShortDoesNotExist();

/// @dev Can only merge same amount of long and short
error FM_MergeAmountMisMatch();

/// @dev Can only split same amount of existing spread into short + long
error FM_SplitAmountMisMatch();

/// @dev Trying to collateralized the position with different collateral than specified in productId
error FM_CollateralMisMatch();

/// @dev Cannot remove collateral because there are expired longs
error FM_ExpiredShortInAccount();

/// @dev Caller doesn't have access to the subaccount
error FM_NoAccess();

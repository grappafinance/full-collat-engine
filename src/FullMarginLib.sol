// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import "grappa-core/libraries/TokenIdUtil.sol";
import "grappa-core/libraries/ProductIdUtil.sol";

// Full margin types
import {FullMarginAccount, FullMarginDetail} from "./types.sol";
import "./errors.sol";

/**
 * @title FullMarginLib
 * @dev   This library is in charge of updating the full account struct in storage.
 *        whether a "tokenId" is valid or not during minting / burning is checked in Grappa.sol.
 *        FullMarginLib only supports 1 collat type and 1 short position (could combined with 1 long)
 */
library FullMarginLib {
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint40;
    using SafeCast for int256;
    using SafeCast for uint256;

    /**
     * @dev return true if the account has no short positions nor collateral
     */
    function isEmpty(FullMarginAccount storage account) internal view returns (bool) {
        return account.collateralAmount == 0 && account.shortAmount == 0;
    }

    /**
     * @dev Increase the collateral in the account
     * @param account FullMarginAccount storage that will be updated
     */
    function addCollateral(FullMarginAccount storage account, uint8 collateralId, uint80 amount) internal {
        // this line should not be allowed to executed because collateralId == 0 will invoke
        // calling safeTransferFrom on address(0). But still guarding here to be safe
        if (collateralId == 0) revert FM_WrongCollateralId();

        uint80 cacheId = account.collateralId;
        if (cacheId == 0) {
            account.collateralId = collateralId;
        } else {
            if (cacheId != collateralId) revert FM_WrongCollateralId();
        }
        account.collateralAmount += amount;
    }

    /**
     * @dev Reduce the collateral in the account
     * @param account FullMarginAccount storage that will be updated
     */
    function removeCollateral(FullMarginAccount storage account, uint8 collateralId, uint80 amount) internal {
        if (account.collateralId != collateralId) revert FM_WrongCollateralId();

        uint80 newAmount = account.collateralAmount - amount;
        account.collateralAmount = newAmount;

        // only reset the collateralId if the collateral amount is 0 and there is no short position
        // if tokenId is non-empty, we keep collatId here so mismatched collateral cannot be added
        if (newAmount == 0 && account.tokenId == 0) {
            account.collateralId = 0;
        }
    }

    /**
     * @dev Increase the amount of short call or put (debt) of the account
     * @param account FullMarginAccount storage that will be updated
     */
    function mintOption(FullMarginAccount storage account, uint256 tokenId, uint64 amount) internal {
        uint8 collateralId = tokenId.parseCollateralId();

        // // assign collateralId or check collateral id is the same
        // (,, uint8 underlyingId, uint8 strikeId, uint8 collateralId) = productId.parseProductId();

        // // call can only be collateralized by underlying
        // if ((optionType == TokenType.CALL) && underlyingId != collateralId) {
        //     revert FM_CannotMintOptionWithThisCollateral();
        // }

        // // call spread can be collateralized by underlying or strike
        // if (optionType == TokenType.CALL_SPREAD && collateralId != underlyingId && collateralId != strikeId) {
        //     revert FM_CannotMintOptionWithThisCollateral();
        // }

        // // put or put spread can only be collateralized by strike
        // if ((optionType == TokenType.PUT_SPREAD || optionType == TokenType.PUT) && strikeId != collateralId) {
        //     revert FM_CannotMintOptionWithThisCollateral();
        // }

        uint80 cacheCollatId = account.collateralId;
        if (cacheCollatId == 0) {
            account.collateralId = collateralId;
        } else {
            if (cacheCollatId != collateralId) revert FM_CollateralMisMatch();
        }

        uint256 cacheTokenId = account.tokenId;
        if (cacheTokenId == 0) account.tokenId = tokenId;
        else if (cacheTokenId != tokenId) revert FM_InvalidToken();

        account.shortAmount += amount;
    }

    /**
     * @dev Remove the amount of short call or put (debt) of the account
     * @param account FullMarginAccount storage that will be updated
     */
    function burnOption(FullMarginAccount storage account, uint256 tokenId, uint64 amount) internal {
        if (account.tokenId != tokenId) revert FM_InvalidToken();

        uint64 newShortAmount = account.shortAmount - amount;
        if (newShortAmount == 0) account.tokenId = 0;
        account.shortAmount = newShortAmount;
    }

    /**
     * @dev merge an OptionToken into the account, changing existing short to spread
     * @dev shortId and longId already have the same optionType, productId, expiry
     * @param account FullMarginAccount storage that will be updated
     * @param shortId existing short position to be converted into spread
     * @param longId token id to be "added" into the account. This is expected to have the same optionToken with shorted option.
     *               e.g: if the account currently have short call, we can added another "call token" into the account
     *               and convert the short position to a spread.
     */
    function merge(FullMarginAccount storage account, uint256 shortId, uint256 longId, uint64 amount) internal {
        // get token attribute for incoming token
        (,,, uint64 mergingStrike,) = longId.parseTokenId();

        if (account.tokenId != shortId) revert FM_ShortDoesNotExist();
        if (account.shortAmount != amount) revert FM_MergeAmountMisMatch();

        // this can make the vault in either credit spread of debit spread position
        account.tokenId = TokenIdUtil.convertToSpreadId(shortId, mergingStrike);
    }

    /**
     * @dev split an account's spread position into short + 1 long token
     * @param account FullMarginAccount storage that will be updated
     * @param spreadId id of spread to be split
     */
    function split(FullMarginAccount storage account, uint256 spreadId, uint64 amount) internal {
        // passed in spreadId should match the one in account struct
        if (spreadId != account.tokenId) revert FM_InvalidToken();
        if (amount != account.shortAmount) revert FM_SplitAmountMisMatch();

        // convert to vanilla call or put: remove the "short strike" and update "tokenType" field
        account.tokenId = TokenIdUtil.convertToVanillaId(spreadId);
    }

    /**
     * @dev clear short amount, and reduce collateral ny amount of payout
     * @param account FullMarginAccount storage that will be updated
     * @param payout amount of payout for minted options
     */
    function settleAtExpiry(FullMarginAccount storage account, int80 payout) internal {
        // clear all debt
        account.tokenId = 0;
        account.shortAmount = 0;

        int256 collateral = int256(uint256(account.collateralAmount));

        // this line should not underflow because collateral should always be enough
        // but keeping the underflow check to make sure
        account.collateralAmount = (collateral - payout).toUint256().toUint80();

        // do not check ending collateral amount (and reset collateral id) because it is very
        // unlikely the payout is the exact amount in the account
        // if that is the case (collateralAmount = 0), use can use removeCollateral(0)
        // to reset the collateral id
    }
}

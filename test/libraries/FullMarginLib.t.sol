// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenIdUtil} from "grappa-core/libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "grappa-core/libraries/ProductIdUtil.sol";
import "grappa-core/config/errors.sol";

import {Test, stdError} from "forge-std/Test.sol";

import {FullMarginLib} from "src/FullMarginLib.sol";

import {FullMarginAccount, TokenType} from "src/types.sol";
import "src/errors.sol";

/**
 * @dev tester contract to improve coverage on storage libraries
 */
contract FullMarginLibTester {
    using FullMarginLib for FullMarginAccount;

    FullMarginAccount private _account;

    function account() external view returns (FullMarginAccount memory) {
        return _account;
    }

    function isEmpty() external view returns (bool) {
        bool empty = FullMarginLib.isEmpty(_account);
        return empty;
    }

    function addCollateral(uint8 collateralId, uint80 amount) external {
        FullMarginLib.addCollateral(_account, collateralId, amount);
    }

    function removeCollateral(uint8 collateralId, uint80 amount) external {
        FullMarginLib.removeCollateral(_account, collateralId, amount);
    }

    function mintOption(uint256 tokenId, uint64 amount) external {
        FullMarginLib.mintOption(_account, tokenId, amount);
    }

    function burnOption(uint256 tokenId, uint64 amount) external {
        FullMarginLib.burnOption(_account, tokenId, amount);
    }

    function merge(uint256 shortId, uint256 longId, uint64 amount) external {
        FullMarginLib.merge(_account, shortId, longId, amount);
    }

    function split(uint256 spreadId, uint64 amount) external {
        FullMarginLib.split(_account, spreadId, amount);
    }

    function settleAtExpiry(int80 payout) external {
        FullMarginLib.settleAtExpiry(_account, payout);
    }
}

/**
 * This test is used to improve coverage on FulMarginLib
 */
contract FullMarginLibTest is Test {
    FullMarginLibTester tester;

    function setUp() public {
        tester = new FullMarginLibTester();
    }

    function test_IsEmpty() public {
        bool isEmpty = tester.isEmpty();
        assertEq(isEmpty, true);
    }

    function test_AddCollateral() public {
        uint8 collatId = 1;
        tester.addCollateral(collatId, 100);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.collateralId, collatId);

        // can add the same collateral id again
        tester.addCollateral(collatId, 100);
        acc = tester.account();
        assertEq(acc.collateralId, collatId);
        assertEq(acc.collateralAmount, 200);

        // cannot add collateral with diff id
        vm.expectRevert(FM_WrongCollateralId.selector);
        tester.addCollateral(collatId + 1, 100);
    }

    function test_RevertWhen_AddZeroId() public {
        vm.expectRevert(FM_WrongCollateralId.selector);
        tester.addCollateral(0, 100);
    }

    function test_ReduceCollateral() public {
        uint80 collatAmount = 100;
        uint8 collatId = 1;
        tester.addCollateral(collatId, collatAmount);

        // cannot remove a diff collateral id
        vm.expectRevert(FM_WrongCollateralId.selector);
        tester.removeCollateral(collatId + 1, collatAmount);

        // can only remove half
        tester.removeCollateral(collatId, collatAmount / 2);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.collateralId, collatId);
        assertEq(acc.collateralAmount, collatAmount / 2);

        // cannot remove more then the account holds
        vm.expectRevert(stdError.arithmeticError);
        tester.removeCollateral(collatId, acc.collateralAmount + 1);

        // can remove all
        tester.removeCollateral(collatId, acc.collateralAmount);
        acc = tester.account();
        assertEq(acc.collateralId, 0);
        assertEq(acc.collateralAmount, 0);
    }

    function test_MintShortInEmptyAccount() public {
        uint64 expiry = uint64(block.timestamp) + 100;
        uint8 strikeId = 1;
        uint8 underlyingId = 2;
        uint8 collateralId = 2;
        uint40 productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, collateralId);

        uint256 id = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 100, 0);

        // can mint the first option
        tester.mintOption(id, 100);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.tokenId, id);
        assertEq(acc.shortAmount, 100);

        // can mint the same option again
        tester.mintOption(id, 100);
        acc = tester.account();
        assertEq(acc.shortAmount, 200);

        // cannot mint a diff option
        vm.expectRevert(FM_InvalidToken.selector);
        tester.mintOption(id + 1, 100);
    }

    function test_CannotMintOptionWithDiffCollatType() public {
        // assume there's already collat in the account
        uint8 collateralId = 1;
        tester.addCollateral(collateralId, 100);

        uint64 expiry = uint64(block.timestamp) + 100;
        uint8 strikeId = 1;
        uint8 underlyingId = 2;
        // product id with collateral id = underlying id (for call)
        uint40 productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, underlyingId);
        uint256 id = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 100, 0);

        // cannot mint this token!
        vm.expectRevert(FM_CollateralMisMatch.selector);
        tester.mintOption(id, 100);
    }

    function test_CannotMintOptionWithBadCollatType() public {
        uint64 expiry = uint64(block.timestamp) + 100;
        uint8 strikeId = 1;
        uint8 underlyingId = 2;
        // cannot mint put with underlying as collateral
        uint40 productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, underlyingId);
        uint256 putId = TokenIdUtil.getTokenId(TokenType.PUT, productId, expiry, 100, 0);
        vm.expectRevert(FM_CannotMintOptionWithThisCollateral.selector);
        tester.mintOption(putId, 100);

        // cannot mint call with strike as collateral
        productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, strikeId);
        uint256 callId = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 100, 0);
        vm.expectRevert(FM_CannotMintOptionWithThisCollateral.selector);
        tester.mintOption(callId, 100);

        // cannot mint call spread with asset != underlying or strike
        productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, 3);
        uint256 callSpread = TokenIdUtil.getTokenId(TokenType.CALL_SPREAD, productId, expiry, 100, 0);
        vm.expectRevert(FM_CannotMintOptionWithThisCollateral.selector);
        tester.mintOption(callSpread, 100);
    }

    function test_BurnOption() public {
        // mint the option
        uint64 expiry = uint64(block.timestamp) + 100;
        uint8 strikeId = 1;
        uint8 underlyingId = 2;
        uint8 collateralId = 2;
        uint40 productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, collateralId);
        uint256 id = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 100, 0);
        tester.mintOption(id, 100);

        // cannot burn option with diff id
        vm.expectRevert(FM_InvalidToken.selector);
        tester.burnOption(id + 1, 100);

        // cannot burn more than minted
        vm.expectRevert(stdError.arithmeticError);
        tester.burnOption(id, 101);

        // can burned minted option id
        tester.burnOption(id, 100);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.tokenId, 0);
        assertEq(acc.shortAmount, 0);
    }

    function test_MergeShortId() public {
        // mint the option
        uint64 expiry = uint64(block.timestamp) + 100;
        uint8 strikeId = 1;
        uint8 underlyingId = 2;
        uint8 collateralId = 2;
        uint40 productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, collateralId);
        uint256 shortId = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 100, 0);
        uint256 longId = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 120, 0);
        tester.mintOption(shortId, 100);

        // cannot merge if short is different then what the account holds
        vm.expectRevert(FM_ShortDoesNotExist.selector);
        tester.merge(shortId + 1, longId, 100);

        // cannot merge with diff amount
        vm.expectRevert(FM_MergeAmountMisMatch.selector);
        tester.merge(shortId, longId, 99);

        // convert type to spread
        tester.merge(shortId, longId, 100);
        FullMarginAccount memory acc = tester.account();
        TokenType t = TokenIdUtil.parseTokenType(acc.tokenId);
        assertEq(uint8(t), uint8(TokenType.CALL_SPREAD));
    }

    function test_SplitSpreadId() public {
        // mint the option
        uint64 expiry = uint64(block.timestamp) + 100;
        uint8 strikeId = 1;
        uint8 underlyingId = 2;
        uint8 collateralId = 2;
        uint40 productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, collateralId);
        uint256 spreadId = TokenIdUtil.getTokenId(TokenType.CALL_SPREAD, productId, expiry, 100, 120);
        tester.mintOption(spreadId, 100);

        // cannot split if spread id is different than what the account has minted
        vm.expectRevert(FM_InvalidToken.selector);
        tester.split(spreadId + 1, 100);

        // cannot split with diff amount
        vm.expectRevert(FM_SplitAmountMisMatch.selector);
        tester.split(spreadId, 99);

        // split spread into single short (and allow taking out the long)
        tester.split(spreadId, 100);
        FullMarginAccount memory acc = tester.account();
        TokenType t = TokenIdUtil.parseTokenType(acc.tokenId);
        assertEq(uint8(t), uint8(TokenType.CALL)); // call spread became vanilla call
    }

    function test_Settle() public {
        // mint the option
        uint64 expiry = uint64(block.timestamp) + 100;
        uint8 strikeId = 1;
        uint8 underlyingId = 2;
        uint8 collateralId = 2;
        uint40 productId = ProductIdUtil.getProductId(0, 0, underlyingId, strikeId, collateralId);
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 100, 0);

        tester.mintOption(tokenId, 100);
        tester.addCollateral(collateralId, 1000);

        // settlement will clear all short position
        tester.settleAtExpiry(500);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.tokenId, 0);
        assertEq(acc.shortAmount, 0);
        assertEq(acc.collateralAmount, 500);

        // will reset collateral id if ending amount is 0!
        tester.settleAtExpiry(500);
        acc = tester.account();
        assertEq(acc.collateralAmount, 0);
        assertEq(acc.collateralId, 0);
    }
}

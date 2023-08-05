// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixture} from "./FullMarginFixture.t.sol";

import "grappa-core/config/enums.sol";
import "grappa-core/config/types.sol";
import "grappa-core/config/constants.sol";

/**
 *
 * The two tests here describe the case where an original seller of an option, add another token (long position) into the vault,
 * which ends in a net "debit spread position" (i.e. bull call spread or bear put spread).
 *
 * At settlement, the amount should be credited to the vault's collateral, if this position expires in the money.
 *
 */

/**
 * @dev the vault is long 4000 call, short 5000 call
 */
contract Settle_Seller_BullCallSpread_Test is FullMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);

    function setUp() public override {
        FullMarginFixture.setUp();
        expiry = block.timestamp + 14 days;
        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        weth.mint(address(this), 1 ether);
        weth.approve(address(engine), type(uint256).max);

        uint256 depositAmount = 1 ether;

        // create a sub account vault to mint 4000 call
        uint256 call4000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 4000 * UNIT, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        address subAccount = address(uint160(address(this)) + 1);

        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(call4000, address(this), amount);
        engine.execute(subAccount, actions);

        // short 5000 from account address(this)
        uint256 call5000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 5000 * UNIT, 0);
        actions[0] = createMintAction(call5000, alice, amount); // give option to alice
        actions[1] = createMergeAction(call4000, call5000, address(this), amount);
        engine.execute(address(this), actions);
        // expire option
        vm.warp(expiry);
    }

    function test_SellerSettleShort_ITM() public {
        // expires in the money
        uint256 expiryPrice = 4100 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedGainForVault = (100 * UNIT) / 4100 * 1e12;

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // to settle
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter - collateralBefore, expectedGainForVault);
        assertEq(collateralIdAfter, collateralIdBefore);
    }

    function test_SellerSettlePayoutCapped_ITM() public {
        // both 4000 and 5000 calls are ITM
        uint256 expiryPrice = 6000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // expected payout is the difference ($1000) but in eth term
        uint256 expectedGainForVault = 0.166667 * 1e18;

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // to settle
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter - collateralBefore, expectedGainForVault);
        assertEq(collateralIdAfter, collateralIdBefore);
    }
}

/**
 * @dev the vault is long 2000 PUT, short 1500 PUT
 */
contract Settle_Seller_Bear_PutSpread_Test is FullMarginFixture {
    uint256 public expiry;
    uint64 private amount = uint64(1 * UNIT);

    function setUp() public override {
        FullMarginFixture.setUp();
        expiry = block.timestamp + 14 days;
        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        usdc.mint(address(this), 10000 * UNIT);
        usdc.approve(address(engine), type(uint256).max);

        uint256 depositAmount = 2000 * UNIT;

        // create a sub account vault to mint 2000 put
        uint256 put2000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 2000 * UNIT, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        address subAccount = address(uint160(address(this)) + 1);

        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(put2000, address(this), amount);
        engine.execute(subAccount, actions);

        // short 1500 PUT from account address(this)
        uint256 put1500 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1500 * UNIT, 0);
        actions[0] = createMintAction(put1500, alice, amount); // give option to alice
        actions[1] = createMergeAction(put2000, put1500, address(this), amount);
        engine.execute(address(this), actions);
        // expire option
        vm.warp(expiry);
    }

    function test_SellerSettleShort_ITM() public {
        // expires in the money
        uint256 expiryPrice = 1800 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedGainForVault = (200 * UNIT);

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // to settle
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter - collateralBefore, expectedGainForVault);
        assertEq(collateralIdAfter, collateralIdBefore);
    }

    function test_SellerSettlePayoutCapped_ITM() public {
        // both 2000 and 1500 puts are ITM
        uint256 expiryPrice = 1400 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // expected payout is capped at $500
        uint256 expectedGainForVault = 500 * UNIT;

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // to settle
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter - collateralBefore, expectedGainForVault);
        assertEq(collateralIdAfter, collateralIdBefore);
    }
}

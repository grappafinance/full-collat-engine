// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixture} from "./FullMarginFixture.t.sol";

import "grappa-core/config/enums.sol";
import "grappa-core/config/types.sol";
import "grappa-core/config/constants.sol";
import "grappa-core/config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract Settle_CoveredCall_Test is FullMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public override {
        FullMarginFixture.setUp();
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        // mint option
        uint256 depositAmount = 1 ether;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function test_RevertWhen_PriceIsNotFinalized() public {
        oracle.setExpiryPriceWithFinality(address(weth), address(usdc), strike, false);
        vm.expectRevert(GP_PriceNotFinalized.selector);
        grappa.settleOption(alice, tokenId, amount);
    }

    function test_GetNothing_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike - 1);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_GetPayout_IMT() public {
        // expires in the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - strike) / 5000) * (10 ** (18 - UNIT_DECIMALS));
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);
        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(optionBefore, optionAfter + amount);
    }

    // settlement for sell side
    function test_SellerClearDebt_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike - 1);

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter, collateralBefore);
        assertEq(collateralIdAfter, collateralIdBefore);
    }

    function test_SellerCollateralIsReduced_ITM() public {
        // expires out the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - strike) / 5000) * (10 ** (18 - UNIT_DECIMALS));

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralBefore - collateralAfter, expectedPayout);
        assertEq(collateralIdAfter, collateralIdBefore);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract Settle_Put_Test is FullMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public override {
        FullMarginFixture.setUp();
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        // mint option

        strike = uint64(2000 * UNIT);

        uint256 depositAmount = 2000 * 1e6;

        tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function test_GetNothing_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike + 1);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_GetPayout_ITM() public {
        // expires in the money
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = strike - uint64(expiryPrice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    // settlement on sell side

    function test_SellerCanClearDebt_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike + 1);

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter, collateralBefore);
        assertEq(collateralIdAfter, collateralIdBefore);
    }

    function test_SellerCollateralIsReduced_ITM() public {
        // expires out the money
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = strike - uint64(expiryPrice);

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralBefore - collateralAfter, expectedPayout);
        assertEq(collateralIdAfter, collateralIdBefore);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract Settle_CallSpread_Test is FullMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private longStrike;
    uint64 private shortStrike;

    function setUp() public override {
        FullMarginFixture.setUp();
        weth.mint(address(this), 1000 ether);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint option
        uint256 depositAmount = 0.2 ether;

        longStrike = uint64(4000 * UNIT);
        shortStrike = uint64(5000 * UNIT);

        tokenId = getTokenId(TokenType.CALL_SPREAD, pidEthCollat, expiry, longStrike, shortStrike);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function test_GetNothing_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), longStrike);
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_GetPayoutDifferenceBetweenSpotAndLongStrike_ITM() public {
        // expires in the money, not higher than upper bond
        uint256 expiryPrice = 4100 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - longStrike) / 4100) * 1e12;
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore + expectedPayout, wethAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_PayoutShouldBeCappedAtShortStrike_ITM() public {
        // expires in the money, higher than upper bond
        uint256 expiryPrice = 5200 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(shortStrike) - longStrike) / 5200) * 1e12;
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore + expectedPayout, wethAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_SellerCanClearDebt_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), longStrike);

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter, collateralBefore);
        assertEq(collateralIdAfter, collateralIdBefore);
    }

    function test_SellerCollateralIsReduced_IfITM() public {
        // expires out the money
        uint256 expiryPrice = 4100 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - longStrike) / 4100) * 1e12;

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralBefore - collateralAfter, expectedPayout);
        assertEq(collateralIdAfter, collateralIdBefore);
    }
}

// call spread settled with strike asset
// solhint-disable-next-line contract-name-camelcase
contract Settle_CreditCallSpread_Test is FullMarginFixture {
    // vault is short 4000, long 5000 strike
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private longStrike;
    uint64 private shortStrike;

    function setUp() public override {
        FullMarginFixture.setUp();
        usdc.mint(address(this), 1000 ether);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        longStrike = uint64(4000 * UNIT);
        shortStrike = uint64(5000 * UNIT);

        tokenId = getTokenId(TokenType.CALL_SPREAD, pidUsdcCollat, expiry, longStrike, shortStrike);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function test_GetNothing_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), longStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_GetPayoutDiffBetweenSpotAndLongStrike_ITM() public {
        // expires in the money, not higher than upper bond
        uint256 expiryPrice = 4100 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - longStrike));
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_PayoutShouldBeCappedAtShortStrike_ITM() public {
        // expires in the money, higher than upper bond
        uint256 expiryPrice = 5200 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(shortStrike) - longStrike));
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_SellerCollateralIsReduced_ITM() public {
        // expires out the money
        uint256 expiryPrice = 4100 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - longStrike));

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralBefore - collateralAfter, expectedPayout);
        assertEq(collateralIdAfter, collateralIdBefore);
    }
}

contract Settle_DebitCallSpread_Test is FullMarginFixture {
    // vault is with long 4000 strike, short 5000 strike
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

contract Settle_DebitPutSpread_Test is FullMarginFixture {
    // vault is with long 2000 PUT, short 1500 PUT
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

// solhint-disable-next-line contract-name-camelcase
contract Settle_PutSpread_Test is FullMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private longStrike;
    uint64 private shortStrike;

    function setUp() public override {
        FullMarginFixture.setUp();
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        longStrike = uint64(2000 * UNIT);
        shortStrike = uint64(1800 * UNIT);

        tokenId = getTokenId(TokenType.PUT_SPREAD, pidUsdcCollat, expiry, longStrike, shortStrike);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function test_GetNothing_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), longStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_ShouldGetPayoutDifferenceBetweenSpotAndLongStrike_ITM() public {
        // expires in the money, not lower than lower bond
        uint256 expiryPrice = 1900 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = longStrike - uint64(expiryPrice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function test_PayoutShouldBeCappedAtShortStrike_ITM() public {
        // expires in the money, lower than lower bond
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = longStrike - uint64(shortStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    // settling sell side
    function test_SellerCanClearDebt_OTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), longStrike);

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralAfter, collateralBefore);
        assertEq(collateralIdAfter, collateralIdBefore);
    }

    function test_SellerCollateralIsReduced_ITM() public {
        // expires out the money

        uint256 expiryPrice = 1900 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = longStrike - uint64(expiryPrice);

        (,, uint8 collateralIdBefore, uint80 collateralBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (uint256 shortId, uint64 shortAmount, uint8 collateralIdAfter, uint80 collateralAfter) =
            engine.marginAccounts(address(this));

        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(collateralBefore - collateralAfter, expectedPayout);
        assertEq(collateralIdAfter, collateralIdBefore);
    }
}

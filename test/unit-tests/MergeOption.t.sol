// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixture} from "./FullMarginFixture.t.sol";

import "grappa-core/config/enums.sol";
import "grappa-core/config/types.sol";
import "grappa-core/config/constants.sol";
import "grappa-core/config/errors.sol";

import "src/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract MergeOption_Action_Test is FullMarginFixture {
    uint256 public expiry;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public depositAmount = 1 ether;
    uint256 public amount = 1 * UNIT;

    uint256 public existingTokenId;

    function setUp() public override {
        FullMarginFixture.setUp();
        weth.mint(address(this), depositAmount);
        weth.approve(address(engine), type(uint256).max);
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 3000 strike call first
        existingTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(existingTokenId, address(this), amount);
        engine.execute(address(this), actions);
    }

    function test_MergeCall() public {
        // mint new call option for this address

        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, pidEthCollat, amount);

        // merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(newTokenId, existingTokenId, address(this), amount);
        engine.execute(address(this), actions);

        // check result
        (uint256 shortId,,,) = engine.marginAccounts(address(this));
        (TokenType newType,,, uint64 longStrike, uint64 shortStrike) = parseTokenId(shortId);

        assertEq(uint8(newType), uint8(TokenType.CALL_SPREAD));
        assertTrue(shortId != newTokenId);
        assertEq(longStrike, strikePrice);
        assertEq(shortStrike, higherStrike);
    }

    function test_Cannot_MergeByAddingSpread() public {
        uint256 spreadToAdd = getTokenId(TokenType.CALL_SPREAD, pidEthCollat, expiry, strikePrice, strikePrice + 1);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(spreadToAdd, existingTokenId, address(this), amount);

        vm.expectRevert(BM_CannotMergeSpread.selector);
        engine.execute(address(this), actions);
    }

    function test_Cannot_MergeWithWrongAmount() public {
        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, higherStrike, 0);
        uint256 wrongAmount = 2 * UNIT;
        mintOptionFor(address(this), newTokenId, pidEthCollat, wrongAmount);

        // merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(newTokenId, existingTokenId, address(this), wrongAmount);

        vm.expectRevert(FM_MergeAmountMisMatch.selector);
        engine.execute(address(this), actions);
    }

    function test_Cannot_MergeWithWrongShortId() public {
        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, pidEthCollat, amount);

        // merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        // shortId should be existingTokenId
        uint256 wrongShort = getTokenId(TokenType.CALL, pidEthCollat, expiry, 2000 * UNIT, 0);
        actions[0] = createMergeAction(newTokenId, wrongShort, address(this), amount);

        vm.expectRevert(FM_ShortDoesNotExist.selector);
        engine.execute(address(this), actions);
    }

    function test_MergeIntoCreditSpread_RemoveCollateral() public {
        // mint new call option for this address
        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, pidEthCollat, amount);

        uint256 newRequiredCollat = 0.2 ether;
        uint256 amountToRemove = depositAmount - newRequiredCollat;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createMergeAction(newTokenId, existingTokenId, address(this), amount);
        actions[1] = createRemoveCollateralAction(amountToRemove, wethId, address(this));
        engine.execute(address(this), actions);

        //action should not revert
    }

    function test_RevertWhen_MergeIntoCreditSpread_ChangeCollatType() public {
        // test an attack will revert: convert to debit spread => remove collateral => add different collateral
        uint256 lowerStrike = 3800 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, lowerStrike, 0);
        mintOptionFor(address(this), newTokenId, pidEthCollat, amount);

        ActionArgs[] memory actions = new ActionArgs[](3);
        actions[0] = createMergeAction(newTokenId, existingTokenId, address(this), amount);
        actions[1] = createRemoveCollateralAction(depositAmount, wethId, address(this));
        // change to a different collateral asset (USDC)
        actions[2] = createAddCollateralAction(usdcId, address(this), 100 * 1e6);

        vm.expectRevert(FM_WrongCollateralId.selector);
        engine.execute(address(this), actions);
    }

    function test_MergeIntoDebitSpread_RemoveAllCollateral() public {
        // mint new call option for this address
        uint256 lowerStrike = 3800 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, lowerStrike, 0);
        mintOptionFor(address(this), newTokenId, pidEthCollat, amount);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createMergeAction(newTokenId, existingTokenId, address(this), amount);
        actions[1] = createRemoveCollateralAction(depositAmount, wethId, address(this));
        engine.execute(address(this), actions);

        //action should not revert
    }
}

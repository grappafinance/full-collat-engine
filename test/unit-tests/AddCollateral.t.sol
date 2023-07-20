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
contract AddCollateral_Action_Test is FullMarginFixture {
    function setUp() public override {
        FullMarginFixture.setUp();
        // approve engine
        usdc.mint(address(this), 1000_000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);
    }

    function test_AddCollateral_ChangeStorage() public {
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);
        (,, uint8 _collateralId, uint80 _collateralAmount) = engine.marginAccounts(address(this));

        assertEq(_collateralId, usdcId);
        assertEq(_collateralAmount, depositAmount);
    }

    function test_AddCollateral_MoveBalance() public {
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefore - myBalanceAfter, depositAmount);
        assertEq(engineBalanceAfter - engineBalanceBefore, depositAmount);
    }

    function test_AddCollateral_Loop_MoveBalances() public {
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));
        uint256 depositAmount = 500 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefore - myBalanceAfter, depositAmount * 2);
        assertEq(engineBalanceAfter - engineBalanceBefore, depositAmount * 2);
    }

    function test_Cannot_AddDifferentCollatToSameAccount() public {
        uint256 usdcAmount = 500 * 1e6;
        uint256 wethAmount = 10 * 1e18;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcAmount);
        actions[1] = createAddCollateralAction(wethId, address(this), wethAmount);

        vm.expectRevert(FM_WrongCollateralId.selector);
        engine.execute(address(this), actions);
    }

    function test_Cannot_AddCollatFromOthers() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(alice), 100);
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }
}

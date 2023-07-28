// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixture} from "./FullMarginFixture.t.sol";

import "grappa-core/config/types.sol";
import "grappa-core/config/errors.sol";

import "src/errors.sol";

contract TransferAccount_Test is FullMarginFixture {
    uint256 public depositAmount = 1000 * 1e6;

    function setUp() public override {
        FullMarginFixture.setUp();
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);
    }

    function test_TransferAccount() public {
        address newAcc = address(uint160(address(this)) - 1);
        engine.transferAccount(address(this), newAcc);

        (,, uint8 oldAccCollatId, uint80 oldAccCollat) = engine.marginAccounts(address(this));
        assertEq(oldAccCollatId, 0);
        assertEq(oldAccCollat, 0);

        (,, uint8 newAccCollatId, uint80 newAccCollat) = engine.marginAccounts(newAcc);
        assertEq(newAccCollatId, usdcId);
        assertEq(newAccCollat, depositAmount);
    }

    function test_RevertWhen_RecipientNonEmpty() public {
        // another use create their own account
        vm.startPrank(alice);
        usdc.approve(address(engine), type(uint256).max);
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(alice), depositAmount);
        engine.execute(address(alice), actions);
        vm.stopPrank();

        // cannot override alice's account
        vm.expectRevert(FM_AccountIsNotEmpty.selector);
        engine.transferAccount(address(this), alice);
    }

    function test_RevertWhen_CallerNoAccess() public {
        vm.prank(alice);
        vm.expectRevert(FM_NoAccess.selector);
        engine.transferAccount(address(this), alice);
    }
}

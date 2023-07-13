// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "forge-std/Script.sol";

// Grappa contract & OptionToken

import "grappa-core/core/Grappa.sol";
import "grappa-core/core/GrappaProxy.sol";
import "grappa-core/core/CashOptionToken.sol";

import "grappa-core/config/enums.sol";
import "grappa-core/config/types.sol";

// helper from Grappa core repo
import "lib/core-cash/test/shared/ActionHelper.sol";

import "src/FullMarginEngine.sol";

// Mocks
import "../mocks/MockERC20.sol";
import "../mocks/MockOracle.sol";

// solhint-disable max-states-count

/**
 * helper contract for full margin integration test to inherit.
 */
contract FullMarginFixture is Test, ActionHelper, Script {
    FullMarginEngine internal engine;
    Grappa internal grappa;
    CashOptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    address internal alice;
    address internal charlie;
    address internal bob;

    // usdc collateralized call / put
    uint40 internal pidUsdcCollat;

    // eth collateralized call / put
    uint40 internal pidEthCollat;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal engineId;
    uint8 internal oracleId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2

        oracle = new MockOracle(); // nonce: 3

        // predict address of grappa account and use it here
        address grappaAddr = computeCreateAddress(address(this), 6);

        option = new CashOptionToken(grappaAddr, address(0)); // nonce: 4

        address grappaImplementation = address(new Grappa(address(option))); // nonce: 5

        bytes memory data = abi.encodeWithSelector(Grappa.initialize.selector, address(this));

        grappa = Grappa(address(new GrappaProxy(grappaImplementation, data))); // 6

        engine = new FullMarginEngine(address(grappa), address(option)); // nonce 6

        // register products
        usdcId = grappa.registerAsset(address(usdc));
        wethId = grappa.registerAsset(address(weth));

        engineId = grappa.registerEngine(address(engine));

        oracleId = grappa.registerOracle(address(oracle));

        pidUsdcCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(usdc));
        pidEthCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(weth));

        charlie = address(0xcccc);
        vm.label(charlie, "Charlie");

        bob = address(0xb00b);
        vm.label(bob, "Bob");

        alice = address(0xaaaa);
        vm.label(alice, "Alice");

        // make sure timestamp is not 0
        vm.warp(0xffff);

        usdc.mint(alice, 1000_000_000 * 1e6);
        usdc.mint(bob, 1000_000_000 * 1e6);
        usdc.mint(charlie, 1000_000_000 * 1e6);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function mintOptionFor(address _recipient, uint256 _tokenId, uint40 _productId, uint256 _amount) internal {
        address anon = address(0x42424242);

        vm.startPrank(anon);

        uint256 lotOfCollateral = 1_000 * 1e18;

        usdc.mint(anon, lotOfCollateral);
        weth.mint(anon, lotOfCollateral);
        usdc.approve(address(engine), type(uint256).max);
        weth.approve(address(engine), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](2);

        uint8 collateralId = uint8(_productId);

        actions[0] = createAddCollateralAction(collateralId, address(anon), lotOfCollateral);
        actions[1] = createMintAction(_tokenId, address(_recipient), _amount);
        engine.execute(address(anon), actions);

        vm.stopPrank();
    }
}

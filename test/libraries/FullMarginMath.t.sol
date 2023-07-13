// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {FullMarginMath} from "src/FullMarginMath.sol";
import "grappa-core/src/config/constants.sol";
import "grappa-core/src/config/errors.sol";

import "src/types.sol";

/**
 * @dev forge coverage only pick up coverage for internal libraries
 *      when it's initiated with external calls
 */
contract FullMarginMathTester {
    function getMinCollateral(FullMarginDetail calldata _detail) external pure returns (uint256) {
        uint256 result = FullMarginMath.getCollateralRequirement(_detail);
        return result;
    }
}

contract FullMarginMathBasic is Test {
    using FullMarginMath for FullMarginDetail;

    FullMarginMathTester tester;

    function setUp() public {
        tester = new FullMarginMathTester();
    }

    function testNoCollateralIfNoShort() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: 0,
            longStrike: 0,
            shortStrike: 0,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: false,
            tokenType: TokenType.CALL
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 0;
        assertEq(collat, expectedRequirement);
    }
}

/**
 * test full margin calculation for simple call
 */
contract FullMarginMathTestCall is Test {
    using FullMarginMath for FullMarginDetail;

    FullMarginMathTester tester;

    function setUp() public {
        tester = new FullMarginMathTester();
    }

    function testMarginRequirementCall() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 0,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            tokenType: TokenType.CALL,
            collateralizedWithStrike: false
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = UNIT;
        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCall() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 0,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: false,
            tokenType: TokenType.CALL
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = shortAmount;

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCallDiffDecimals() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 0,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 18,
            collateralizedWithStrike: false,
            tokenType: TokenType.CALL
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 5 * 1e18;

        assertEq(collat, expectedRequirement);
    }
}

/**
 * test full margin calculation for call spread, collaterlized with underlying
 */
contract FullMarginMathTestCallSpreadWithUnderlying is Test {
    using FullMarginMath for FullMarginDetail;

    FullMarginMathTester tester;

    function setUp() public {
        tester = new FullMarginMathTester();
    }

    function testMarginRequirementCallCreditSpread() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 4000 * UNIT,
            shortStrike: 2000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: false,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = UNIT / 2;
        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCallCreditSpread() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 4000 * UNIT,
            shortStrike: 2000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: false,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = shortAmount / 2;

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCallCreditSpreadDiffDecimals() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 6000 * UNIT,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 18,
            collateralizedWithStrike: false,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = (5 * 1e18) / 2;

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementCallDebitSpread() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 2000 * UNIT,
            shortStrike: 4000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: false,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 0;
        assertEq(collat, expectedRequirement);
    }
}

/**
 * test full margin calculation for call spread, collaterlized with strike
 */
contract FullMarginMathTestCallSpreadWithStrike is Test {
    using FullMarginMath for FullMarginDetail;

    FullMarginMathTester tester;

    function setUp() public {
        tester = new FullMarginMathTester();
    }

    function testMarginRequirementCallCreditSpread() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 4000 * UNIT,
            shortStrike: 2000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = (4000 - 2000) * UNIT;
        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCallCreditSpread() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 4000 * UNIT,
            shortStrike: 2000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = shortAmount * (4000 - 2000);

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCallCreditSpreadDiffDecimals() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 6000 * UNIT,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 18,
            collateralizedWithStrike: true,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = (3000 * 1e18) * 5;

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementCallDebitSpread() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 2000 * UNIT,
            shortStrike: 4000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.CALL_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 0;
        assertEq(collat, expectedRequirement);
    }
}

/**
 * test full margin calculation for simple put
 */
contract FullMarginMathTestPut is Test {
    using FullMarginMath for FullMarginDetail;

    FullMarginMathTester tester;

    function setUp() public {
        tester = new FullMarginMathTester();
    }

    function testMarginRequirementPut() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 0,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.PUT
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 3000 * UNIT;
        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultiplePut() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 0,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.PUT
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = shortAmount * 3000;

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultiplePutDiffDecimals() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 0,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 18,
            collateralizedWithStrike: true,
            tokenType: TokenType.PUT
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 5 * 3000 * 1e18;

        assertEq(collat, expectedRequirement);
    }
}

/**
 * test full margin calculation for put spread
 */
contract FullMarginMathTestPutSpread is Test {
    using FullMarginMath for FullMarginDetail;

    FullMarginMathTester tester;

    function setUp() public {
        tester = new FullMarginMathTester();
    }

    function testMarginRequirementPutCreditSpread() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 2000 * UNIT,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.PUT_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 1000 * UNIT;
        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCallCreditSpread() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 3000 * UNIT,
            shortStrike: 4000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.PUT_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = shortAmount * 1000;

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementMultipleCallCreditSpreadDiffDecimals() public {
        uint256 shortAmount = 5 * UNIT;
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: shortAmount,
            longStrike: 3000 * UNIT,
            shortStrike: 4000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 18,
            collateralizedWithStrike: true,
            tokenType: TokenType.PUT_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = (5 * 1e18) * 1000;

        assertEq(collat, expectedRequirement);
    }

    function testMarginRequirementCallDebitSpread() public {
        FullMarginDetail memory detail = FullMarginDetail({
            shortAmount: UNIT,
            longStrike: 4000 * UNIT,
            shortStrike: 3000 * UNIT,
            collateralAmount: 0,
            collateralDecimals: 6,
            collateralizedWithStrike: true,
            tokenType: TokenType.PUT_SPREAD
        });

        uint256 collat = tester.getMinCollateral(detail);
        uint256 expectedRequirement = 0;
        assertEq(collat, expectedRequirement);
    }
}

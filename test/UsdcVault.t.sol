// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "compound-protocol/contracts/CErc20.sol";
import {ComptrollerG7 as Comptroller} from "compound-protocol/contracts/ComptrollerG7.sol";
import "../src/UsdcVault.sol";

contract UsdcVaultTest is Test {
    address private immutable depositor = vm.addr(0x1);

    UsdcVault private usdcVault;

    ERC20 private USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    CErc20 private cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    ERC20 private COMP = ERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    Comptroller private comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    function setUp() public {
        usdcVault = new UsdcVault(
            USDC,
            cUSDC,
            COMP,
            comptroller,
            "UsdcVault",
            "VUSDC"
        );
    }

    function testDeposit() public {
        uint256 amount = 1e6;
        deal(address(USDC), depositor, amount);

        vm.startPrank(address(depositor));
        USDC.approve(address(usdcVault), type(uint256).max);

        uint256 exchangeRateMantissa = cUSDC.exchangeRateCurrent();
        uint256 sharesToBeReceived = ((amount * 1e18) / (exchangeRateMantissa));

        usdcVault.deposit(amount);
        vm.stopPrank();

        assertEq(usdcVault.balanceOf(depositor), sharesToBeReceived);
        assertEq(USDC.balanceOf(address(usdcVault)), 0);
        assertEq(cUSDC.balanceOf(address(usdcVault)), sharesToBeReceived);
    }

    function testDepositForZeroAmountReverts() public {
        uint256 amount = 1e6;
        deal(address(USDC), depositor, amount);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    UsdcVault.AmountBelowOrEqualZero.selector
                )
            )
        );
        usdcVault.deposit(0);
        vm.stopPrank();
    }

    function testDepositForTooLowAllowanceReverts() public {
        uint256 amount = 1e6;
        deal(address(USDC), depositor, amount);

        vm.startPrank(address(depositor));
        USDC.approve(address(usdcVault), amount - 1);
        vm.expectRevert(
            bytes(abi.encodeWithSelector(UsdcVault.AllowanceNotMet.selector))
        );
        usdcVault.deposit(amount);
        vm.stopPrank();
    }

    function testWithdraw() public {
        uint256 amount = 1e6;
        deal(address(USDC), depositor, amount);

        vm.startPrank(address(depositor));
        USDC.approve(address(usdcVault), type(uint256).max);
        usdcVault.deposit(amount);
        vm.roll(block.number + 1000);

        uint256 totalShares = usdcVault.balanceOf(depositor);
        usdcVault.withdraw(totalShares);
        vm.stopPrank();

        assertEq(usdcVault.balanceOf(depositor), 0);
        assertEq(cUSDC.balanceOf(address(usdcVault)), 0);
        assertGe(USDC.balanceOf(depositor), amount);
    }

    function testWithdrawWithZeroAmountReverts() public {
        vm.startPrank(address(depositor));
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    UsdcVault.AmountBelowOrEqualZero.selector
                )
            )
        );
        usdcVault.withdraw(0);
        vm.stopPrank();
    }

    function testWithdrawTooManySharesReverts() public {
        uint256 amount = 1e6;
        deal(address(USDC), depositor, amount);

        vm.startPrank(address(depositor));
        USDC.approve(address(usdcVault), type(uint256).max);
        usdcVault.deposit(amount);
        vm.roll(block.number + 1000);

        uint256 totalShares = usdcVault.balanceOf(depositor);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(UsdcVault.NotEnoughShares.selector))
        );
        usdcVault.withdraw(totalShares + 1);
        vm.stopPrank();
    }

    function testWithdrawRewards() public {
        uint256 amount = 1e6;
        deal(address(USDC), depositor, amount);

        vm.startPrank(address(depositor));
        USDC.approve(address(usdcVault), type(uint256).max);
        usdcVault.deposit(amount);
        vm.roll(block.number + 100);

        uint256 totalShares = usdcVault.balanceOf(depositor);
        usdcVault.withdraw(totalShares);
        vm.stopPrank();

        usdcVault.withdrawRewards();
        assertGt(COMP.balanceOf(address(this)), 1);
    }

    function testWithdrawRewardsNotOwnerReverts() public {
        uint256 amount = 1e6;
        deal(address(USDC), depositor, amount);

        vm.startPrank(address(depositor));
        USDC.approve(address(usdcVault), type(uint256).max);
        usdcVault.deposit(amount);
        vm.roll(block.number + 10000);

        uint256 totalShares = usdcVault.balanceOf(depositor);
        usdcVault.withdraw(totalShares);

        vm.expectRevert();
        usdcVault.withdrawRewards();
    }
}

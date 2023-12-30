// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SmartShopper is Pausable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Order {
        string orderId;
        uint256 amount;
        address buyer;
        uint256 lockStartTime;
        uint256 lockEndTime;
        bool returned;
        bool claimed;
        uint256 returnedAmount;
    }

    uint256 public LOCK_DURATION = 1 days;

    IERC20 public usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

    mapping(string => Order) private orderIdToOrder;
    mapping(address => string[]) private addressToOrders;
    mapping(string => bool) public orderIds;

    string[] public ordersIdsValue;

    uint256 public fees = 5;

    event OrderCreated(string orderId, uint256 amount, address buyer);
    event OrderRefunded(string orderId, uint256 returnedAmount);
    event OrderClaimed(string orderId, uint256 claimedAmount);
    event FeesUpdated(uint256 newFees);
    event AllOrdersClaimed(uint256 amountToClaim);

    constructor() {

    }

    function createOrder(
        string memory orderId,
        uint256 amount,
        address buyer
    ) external nonReentrant onlyOwner {
        require(!orderIds[orderId], "This order already exists");

        Order memory order = Order(
            orderId,
            amount,
            buyer,
            block.timestamp,
            block.timestamp + LOCK_DURATION,
            false,
            false,
            0
        );

        orderIds[orderId] = true;
        addressToOrders[_msgSender()].push(orderId);
        orderIdToOrder[orderId] = order;
        ordersIdsValue.push(orderId);

        emit OrderCreated(orderId, amount, buyer);
    }

    function claimOrder(
        string memory orderId
    ) external nonReentrant onlyOwner {
        Order storage order = orderIdToOrder[orderId];

        if (!order.returned) {
            require(order.lockEndTime < block.timestamp, "Cannot unlock yet");
        }
        require(!order.claimed, "Order already claimed");

        order.claimed = true;

        uint256 claimedAmount = order.amount - order.returnedAmount;
        usdt.safeTransfer(_msgSender(), claimedAmount);

        emit OrderClaimed(orderId, claimedAmount);
    }

    function claimAll() external nonReentrant onlyOwner {
        uint256 amountToClaim = 0;
        uint256 currentBalance = usdt.balanceOf(address(this));

        for (uint256 i = 0; i < ordersIdsValue.length; i++) {
            string memory currentOrderId = ordersIdsValue[i];
            Order storage order = orderIdToOrder[currentOrderId];

            if (!order.claimed && order.lockEndTime <= block.timestamp) {
                uint256 currentAmountToClaim = order.amount -
                order.returnedAmount;

                amountToClaim += currentAmountToClaim;
                order.claimed = true;
            }
        }

        if (amountToClaim > currentBalance) {
            amountToClaim = currentBalance;
        }
        usdt.safeTransfer(_msgSender(), amountToClaim);

        emit AllOrdersClaimed(amountToClaim);
    }

    function processRefund(
        string memory orderId,
        uint256 returnedAmount
    ) external nonReentrant onlyOwner {
        Order storage order = orderIdToOrder[orderId];

        require(
            returnedAmount <= order.amount,
            "Returned amount higher than order amount"
        );
        require(!order.returned, "Order already returned");

        order.returnedAmount = returnedAmount;
        order.returned = true;

        usdt.safeTransfer(order.buyer, returnedAmount);

        emit OrderRefunded(orderId, returnedAmount);
    }

    function setFees(uint256 newFees) external onlyOwner {
        require(newFees >= 0, "Fees must be higher than 0");
        fees = newFees;

        emit FeesUpdated(newFees);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getOrder(
        string memory orderId
    ) external view returns (Order memory) {
        return orderIdToOrder[orderId];
    }
}

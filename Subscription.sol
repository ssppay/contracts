// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SmartShopperSubscription is Pausable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct SubscriptionType {
        uint256 id;
        string name;
        uint256 price;
        uint256 period;
        bool enabled;
    }

    struct Subscription {
        uint256 id;
        address subscriber;
        uint256 start;
        uint256 end;
        uint256 idSubType;
    }

    Subscription[] public subscriptions;
    SubscriptionType[] public subscriptionTypes;
    IERC20 public usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

    mapping(uint256 => SubscriptionType) public subTypeIdSubType;
    mapping(uint256 => Subscription) public subIdToSub;
    mapping(address => uint256[]) public addressToSubsIds;

    event Subscribed(address subscriber);
    event Withdrawn(uint256 balance);

    constructor() {
        SubscriptionType memory monthly = SubscriptionType(
            subscriptionTypes.length,
            "Monthly",
            8990000,
            30 days,
            true
        );
        subTypeIdSubType[subscriptionTypes.length] = monthly;
        subscriptionTypes.push(monthly);

        SubscriptionType memory annual = SubscriptionType(
            subscriptionTypes.length,
            "Annual",
            49990000,
            365 days,
            true
        );
        subTypeIdSubType[subscriptionTypes.length] = annual;
        subscriptionTypes.push(annual);
    }

    function subscribe(
        uint256 subscriptionTypeId,
        address subscriber
    ) external whenNotPaused nonReentrant onlyOwner {
        SubscriptionType memory subscriptionType = subTypeIdSubType[
            subscriptionTypeId
        ];

        uint256 allSubsLength = addressToSubsIds[subscriber].length;

        Subscription memory newSubscription = Subscription(
            subscriptions.length,
            subscriber,
            block.timestamp,
            block.timestamp + subscriptionType.period,
            subscriptionTypeId
        );

        if (allSubsLength > 0) {
            uint256 lastSubId = addressToSubsIds[subscriber][
                allSubsLength - 1
            ];
            Subscription memory lastSubscription = subIdToSub[lastSubId];

            if (lastSubscription.end <= block.timestamp) {
                newSubscription.start = block.timestamp;
                newSubscription.end = block.timestamp + subscriptionType.period;
            } else {
                newSubscription.start = lastSubscription.end + 1;
                newSubscription.end =
                    lastSubscription.end +
                    1 +
                    subscriptionType.period;
            }
        }

        subscriptions.push(newSubscription);
        subIdToSub[newSubscription.id] = newSubscription;
        addressToSubsIds[subscriber].push(newSubscription.id);

        emit Subscribed(subscriber);
    }

    function withdraw() external onlyOwner {
        uint256 balance = usdt.balanceOf(address(this));
        usdt.safeTransfer(_msgSender(), balance);

        emit Withdrawn(balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function isSubscriptionValidById(
        uint256 subscriptionId
    ) external view returns (bool) {
        Subscription memory subscription = subIdToSub[subscriptionId];

        return subscription.end > block.timestamp;
    }

    function isSubscriptionValidByAddress(
        address subscriber
    ) external view returns (bool) {
        uint256 allSubsLength = addressToSubsIds[subscriber].length;
        uint256 lastSubId = addressToSubsIds[subscriber][allSubsLength - 1];
        Subscription memory lastSubscription = subIdToSub[lastSubId];

        return lastSubscription.end > block.timestamp;
    }

    function getAllSubTypes()
        external
        view
        returns (SubscriptionType[] memory)
    {
        return subscriptionTypes;
    }

    function getAllSubs() external view returns (Subscription[] memory) {
        return subscriptions;
    }

    function getAllSubsByAddress(
        address subscriber
    ) external view returns (Subscription[] memory) {
        uint256 allSubsLength = addressToSubsIds[subscriber].length;
        Subscription[] memory currentSubs = new Subscription[](allSubsLength);

        for (uint256 i = 0; i < allSubsLength; i++) {
            Subscription memory currentSub = subIdToSub[
                addressToSubsIds[subscriber][i]
            ];
            currentSubs[i] = currentSub;
        }
        return currentSubs;
    }
}

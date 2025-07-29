// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TermDeposit is Ownable {
    IERC20 public stableToken;

    uint256 public interestRatePerDay; // e.g. 137 for 0.0137% daily (1e5 precision)
    uint256 public termDays;

    struct DepositInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaimTime;
        bool withdrawn;
    }

    mapping(address => DepositInfo) public deposits;

    event Deposited(address indexed user, uint256 amount);
    event InterestClaimed(address indexed user, uint256 interest);
    event Withdrawn(address indexed user, uint256 principal, uint256 interest);

    constructor(address _stableToken, uint256 _interestRatePerDay, uint256 _termDays) {
        stableToken = IERC20(_stableToken);
        interestRatePerDay = _interestRatePerDay;
        termDays = _termDays;
    }

    function deposit(uint256 amount) external {
        require(deposits[msg.sender].amount == 0, "Already deposited");
        require(amount > 0, "Amount must be > 0");

        stableToken.transferFrom(msg.sender, address(this), amount);

        deposits[msg.sender] = DepositInfo({
            amount: amount,
            startTime: block.timestamp,
            lastClaimTime: block.timestamp,
            withdrawn: false
        });

        emit Deposited(msg.sender, amount);
    }

    function claimInterest() external {
        DepositInfo storage info = deposits[msg.sender];
        require(info.amount > 0, "No deposit found");
        require(!info.withdrawn, "Already withdrawn");

        uint256 elapsedDays = (block.timestamp - info.lastClaimTime) / 1 days;
        require(elapsedDays > 0, "Nothing to claim");

        uint256 interest = info.amount * interestRatePerDay * elapsedDays / 1e5;

        info.lastClaimTime = block.timestamp;

        stableToken.transfer(msg.sender, interest);
        emit InterestClaimed(msg.sender, interest);
    }

    function withdraw() external {
        DepositInfo storage info = deposits[msg.sender];
        require(info.amount > 0, "No deposit");
        require(!info.withdrawn, "Already withdrawn");

        uint256 endTime = info.startTime + termDays * 1 days;
        require(block.timestamp >= endTime, "Not matured");

        // Final interest
        uint256 elapsedDays = (block.timestamp - info.lastClaimTime) / 1 days;
        uint256 interest = 0;
        if (elapsedDays > 0) {
            interest = info.amount * interestRatePerDay * elapsedDays / 1e5;
        }

        info.withdrawn = true;
        stableToken.transfer(msg.sender, info.amount + interest);

        emit Withdrawn(msg.sender, info.amount, interest);
    }

    function fundContract(uint256 amount) external onlyOwner {
        stableToken.transferFrom(msg.sender, address(this), amount);
    }

    function getPendingInterest(address user) external view returns (uint256) {
        DepositInfo storage info = deposits[user];
        if (info.amount == 0 || info.withdrawn) return 0;

        uint256 elapsedDays = (block.timestamp - info.lastClaimTime) / 1 days;
        return info.amount * interestRatePerDay * elapsedDays / 1e5;
    }
}

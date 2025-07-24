## Short-term deposit product smart contract code example

This tutorial will use the **Solidity** language and **ERC-20 tokens** as the medium for deposits and interest payments (this is very common in DeFi because it can easily handle stablecoins such as USDT, USDC, etc.).

For brevity and clarity, this example will contain core functions, excluding complex error handling and permission management, but these are essential in actual production environments.

**Core functions:**

1. **Deposit (deposit):** The user deposits a specified number of ERC-20 tokens and specifies the number of deposit days.

2. **Deposit (claimInterest):** The user can withdraw the accrued interest at any time according to the set daily interest rate.

3. **Withdraw Principal (withdrawPrincipal):** After the deposit expires, the user can withdraw the principal.

4. **Manage interest rate (setDailyInterestRate):** The contract owner can set the daily interest rate.

We will assume that there is an ERC-20 token contract deployed and that the user has authorized this contract to transfer their tokens before calling the deposit function.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; // Although 0.8.0+ versions have built-in safe math, it is still introduced here to emphasize security

/**
* @title ShortTermDepositProduct
* @dev A simple short-term deposit product smart contract.
* Users can deposit ERC-20 tokens and earn interest on a daily basis, and get their principal back after maturity.
*/
contract ShortTermDepositProduct is Ownable {
    using SafeMath for uint256;
    
    // Deposit information structure
    struct Deposit {
        uint256 amount; // Deposit principal
        uint256 startTime; // Deposit timestamp
        uint256 durationDays; // Deposit period (days)
        uint256 claimedInterest; // Withdrawn interest
    }
    
    // Mapping: user address => deposit information
    mapping(address => Deposit) public deposits;
    
    // ERC-20 token address, principal and interest will be paid in this token
    IERC20 public depositToken;
    
    // Daily interest rate (expressed in ten-thousandths of the base unit, for example, 100 represents 1% = 0.01)
    // For example: if the daily interest rate is 0.01% (0.0001), then dailyInterestRate = 1
    // If the daily interest rate is 0.1% (0.001), then dailyInterestRate = 10
    // If the daily interest rate is 1% (0.01), then dailyInterestRate = 100
    uint256 public dailyInterestRateBasisPoints; // Basis Points (BPS) 10000 BPS = 100%
    
    // Events
    event Deposited(address indexed user, uint256 amount, uint256 durationDays, uint256 startTime);
    event InterestClaimed(address indexed user, uint256 amount);
    event PrincipalWithdrawn(address indexed user, uint256 amount);
    event DailyInterestRateSet(uint256 newRate);
    
    /**
    * @dev Constructor, initializes the deposit token address when deployed.
    * @param _depositTokenAddress ERC-20 token contract address.
    * @param _initialDailyInterestRateBPS Initial daily interest rate (in BPS).
    */
    constructor(address _depositTokenAddress, uint256 _initialDailyInterestRateBPS) Ownable(msg.sender) {
        require(_depositTokenAddress != address(0), "Invalid token address");
        depositToken = IERC20(_depositTokenAddress);
        dailyInterestRateBasisPoints = _initialDailyInterestRateBPS;
        emit DailyInterestRateSet(_initialDailyInterestRateBPS);
    }
    
    /**
    * @dev Set the daily interest rate. Only the contract owner can call it.
    * @param _newRateBPS New daily interest rate (in BPS).
    */
    function setDailyInterestRate(uint256 _newRateBPS) public onlyOwner {
        dailyInterestRateBasisPoints = _newRateBPS;
        emit DailyInterestRateSet(_newRateBPS);
    }
    
    /**
    * @dev Deposit function. Users deposit ERC-20 tokens to purchase financial products.
    * Each deposit will overwrite the previous deposit information, so users can only have one active deposit.
    * In a production environment, you may need to support multiple deposits.
    * @param _amount Deposit amount.
    * @param _durationDays Deposit duration (days).
    */
    function deposit(uint256 _amount, uint256 _durationDays) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(_durationDays > 0, "Duration must be greater than 0");
        require(deposits[msg.sender].amount == 0, "You already have an active deposit. Please withdraw or claim first."); // For simplicity, only one deposit is allowed
        
        // Transfer tokens from user to contract
        require(depositToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        
        deposits[msg.sender] = Deposit({
        amount: _amount,
        startTime: block.timestamp,
        durationDays: _durationDays,
        claimedInterest: 0
        });
        
        emit Deposited(msg.sender, _amount, _durationDays, block.timestamp);
    }
    
    /**
    * @dev Calculate the current interest that the user can withdraw.
    * @param _user User address.
    * @return The amount of interest that can be withdrawn.
    */
    function calculateAvailableInterest(address _user) public view returns (uint256) {
        Deposit memory userDeposit = deposits[_user];
        if (userDeposit.amount == 0) {
            return 0;
        }
    
        // Calculate the number of days that have passed
        uint256 elapsedDays = (block.timestamp.sub(userDeposit.startTime)).div(1 days);
        
        // If the deposit period has passed, only calculate the interest before maturity
        if (elapsedDays > userDeposit.durationDays) {
            elapsedDays = userDeposit.durationDays;
        }
        
        // Calculate the total interest due
        // interest = principal * dailyRate * days
        // dailyRate = dailyInterestRateBasisPoints / 10000
        uint256 totalAccruedInterest = userDeposit.amount
            .mul(dailyInterestRateBasisPoints)
            .mul(elapsedDays)
            .div(10000); // 10000 is the base of BPS
        
        return totalAccruedInterest.sub(userDeposit.claimedInterest);
    }
    /**
    * @dev Withdraw the interest that has been generated.
    */
    function claimInterest() public {
        uint256 interestToClaim = calculateAvailableInterest(msg.sender);
        require(interestToClaim > 0, "No interest to claim");
        
        // Update the record of the interest that has been withdrawn
        deposits[msg.sender].claimedInterest = deposits[msg.sender].claimedInterest.add(interestToClaim);
        
        // Transfer interest tokens to users
        require(depositToken.transfer(msg.sender, interestToClaim), "Interest transfer failed");
        
        emit InterestClaimed(msg.sender, interestToClaim);
    }
    
    /**
    * @dev Withdraw the principal. Can only be called when the deposit expires.
    */
    function withdrawPrincipal() public {
        Deposit storage userDeposit = deposits[msg.sender];
        require(userDeposit.amount > 0, "No active deposit to withdraw");
        
        // Check if it is due
        uint256 maturityTime = userDeposit.startTime.add(userDeposit.durationDays.mul(1 days));
        require(block.timestamp >= maturityTime, "Deposit has not matured yet");
        
        uint256 principalToReturn = userDeposit.amount;
        
        // Clear deposit records
        delete deposits[msg.sender];
        
        // Transfer principal tokens to users
        require(depositToken.transfer(msg.sender, principalToReturn), "Principal transfer failed");
        
        emit PrincipalWithdrawn(msg.sender, principalToReturn);
    }
    
    /**
    * @dev Emergency withdrawal function, only for the owner to use in an emergency.
    * In a production environment, this should be a more complex and limited function.
    */
    function emergencyWithdraw(address _tokenAddress, uint256 _amount) public onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(owner(), _amount);
    }
}
```

-----

## Contract call example (using Hardhat/Ethers.js)

Here we will provide an example of deployment and interaction using Hardhat and Ethers.js. You need to install Hardhat and set up the project first.

**1. Preparation**

First, make sure your project has the following dependencies installed:

```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-ethers @openzeppelin/contracts
```

**2. Deploy ERC-20 token contract (MockToken.sol)**

For testing, we need an ERC-20 token. Create a file `contracts/MockToken.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 { 
    constructor(uint256 initialSupply) ERC20("Mock USDT", "mUSDT") { 
        _mint(msg.sender, initialSupply); 
    }
}
```
**3. Deployment and interaction script (`scripts/deployAndInteract.js`)**

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer, user1, user2] = await ethers.getSigners();
    
    console.log("Deploying contract...");
    
    // Deploy Mock ERC-20 token
    const MockToken = await ethers.getContractFactory("MockToken");
    // Initial supply of 1,000,000 tokens, assuming the token has 18 decimal places
    const initialSupply = ethers.parseUnits("1000000", 18);
    const mockToken = await MockToken.deploy(initialSupply);
    await mockToken.waitForDeployment();
    const mockTokenAddress = await mockToken.getAddress();
    console.log(`MockToken Deploy to: ${mockTokenAddress}`);
    
    // Give user1 and user2 some tokens for testing
    const transferAmount = ethers.parseUnits("1000", 18);
    await mockToken.transfer(user1.address, transferAmount);
    await mockToken.transfer(user2.address, transferAmount);
    console.log(`${ethers.formatUnits(transferAmount, 18)} mUSDT transferred to user1 and user2`);
    
    // Deploy ShortTermDepositProduct contract
    // Set initial daily rate to 10 BPS (0.1%)
    const initialDailyRateBPS = 10;
    const ShortTermDepositProduct = await ethers.getContractFactory("ShortTermDepositProduct");
    const depositProduct = await ShortTermDepositProduct.deploy(mockTokenAddress, initialDailyRateBPS);
    await depositProduct.waitForDeployment();
    const depositProductAddress = await depositProduct.getAddress();
    console.log(`ShortTermDepositProduct deployed to: ${depositProductAddress}`);
    console.log(`Initial Daily Rate (BPS): ${initialDailyRateBPS}`);
    
    console.log("\n--- User 1 (user1) made a deposit ---");
    const depositAmount = ethers.parseUnits("100", 18); // Deposit 100 mUSDT
    const depositDurationDays = 7; // Deposit 7 days
    
    // user1 authorizes ShortTermDepositProduct contract to spend its mUSDT
    await mockToken.connect(user1).approve(depositProductAddress, depositAmount);
    console.log(`User1 authorizes ${depositProductAddress} to spend ${ethers.formatUnits(depositAmount, 18)} mUSDT`);
    
    // user1 calls the deposit function
    await depositProduct.connect(user1).deposit(depositAmount, depositDurationDays);
    console.log(`User1 deposited ${ethers.formatUnits(depositAmount, 18)} mUSDT, term ${depositDurationDays} days`);
    
    // Check user 1's deposit information
    let user1Deposit = await depositProduct.deposits(user1.address);
    console.log(`User1 deposit principal: ${ethers.formatUnits(user1Deposit.amount, 18)} mUSDT`);
    console.log(`User1 deposit term: ${user1Deposit.durationDays} days`);
    console.log(`User1 deposit time: ${new Date(Number(user1Deposit.startTime) * 1000)}`);
    
    console.log("\n--- Simulate the passage of time ---");
    // Simulate time to advance 3 days (3 * 24 * 60 * 60 seconds)
    await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []); // Mine a new block to make time effective
    console.log("Time has advanced 3 days.");
    
    console.log("\n--- User 1 (user1) tried to withdraw interest ---");
    let availableInterest = await depositProduct.calculateAvailableInterest(user1.address);
    console.log(`User1 can withdraw interest: ${ethers.formatUnits(availableInterest, 18)} mUSDT`);
    
    if (availableInterest > 0) {
        await depositProduct.connect(user1).claimInterest();
        console.log(`User1 successfully withdrew interest ${ethers.formatUnits(availableInterest, 18)} mUSDT`);
    } else {
        console.log("User1 currently has no interest to withdraw.");
    }
    
    // Check user 1's deposit information again to see if claimedInterest is updated
    user1Deposit = await depositProduct.deposits(user1.address);
    console.log(`User1 has withdrawn interest: ${ethers.formatUnits(user1Deposit.claimedInterest, 18)} mUSDT`);
    
    console.log("\n--- Simulation time advances to deposit expiration ---");
    // Simulation time advances to ensure that it exceeds 7 days (for example, advance another 5 days, a total of 3 + 5 = 8 days)
    await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);
    console.log("Time has advanced to after the deposit expires.");
    
    console.log("\n--- User 1 (user1) withdraws principal ---");
    // Before withdrawing principal, check again if there is any unwithdrawn interest
    availableInterest = await depositProduct.calculateAvailableInterest(user1.address);
    if (availableInterest > 0) {
        console.log(`User1 still has available interest before withdrawing principal: ${ethers.formatUnits(availableInterest, 18)} mUSDT`);
        await depositProduct.connect(user1).claimInterest();
        console.log(`User1 successfully withdrew the remaining interest ${ethers.formatUnits(availableInterest, 18)} mUSDT`);
    } else {
        console.log("User1 has no remaining interest before withdrawing principal.");
    }
    
    const user1BalanceBeforeWithdraw = await mockToken.balanceOf(user1.address);
    console.log(`User1 Balance before withdrawal: ${ethers.formatUnits(user1BalanceBeforeWithdraw, 18)} mUSDT`);
    
    await depositProduct.connect(user1).withdrawPrincipal();
    console.log(`User1 successfully withdrew the principal ${ethers.formatUnits(depositAmount, 18)} mUSDT`);
    
    const user1BalanceAfterWithdraw = await mockToken.balanceOf(user1.address);
    console.log(`User1 Balance after withdrawal: ${ethers.formatUnits(user1BalanceAfterWithdraw, 18)} mUSDT`);
    
    // Verify that the deposit record has been cleared
    user1Deposit = await depositProduct.deposits(user1.address);
    console.log(`User1 Deposit record (principal): ${ethers.formatUnits(user1Deposit.amount, 18)} mUSDT (should be 0)`);
    
    console.log("\n--- Contract owner modifies daily interest rate ---");
    const newDailyRateBPS = 20; // Change to 0.2%
    await depositProduct.connect(deployer).setDailyInterestRate(newDailyRateBPS);
    console.log(`Owner updates daily interest rate to ${newDailyRateBPS} BPS`);
    console.log(`Current daily interest rate (BPS): ${await depositProduct.dailyInterestRateBasisPoints()}`);
    
    console.log("\n--- End of example ---");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

**4. Run the script**

In your Hardhat project root directory, run:

```bash
npx hardhat run scripts/deployAndInteract.js
```

You will see the simulated deployment and interaction process in the console, including deposit, interest calculation, interest withdrawal, and principal withdrawal.

-----

### Notes and improvement directions

This sample code is designed to demonstrate the core concepts. In a production environment, you need to consider:

1. **Multiple deposits:** The current contract only supports one active deposit per user. To support multiple deposits, you need a `mapping(address => mapping(uint256 => Deposit))` or `mapping(address => Deposit[])` structure and generate a unique ID for each deposit.

2. **Security:**
* **Reentrancy protection:** In functions involving token transfers (`claimInterest`, `withdrawPrincipal`), make sure to use the "check-effect-interaction" pattern or libraries such as ReentrancyGuard.
* **Authorization management:** To refine the `Ownable` permissions, you can introduce role management (such as OpenZeppelin's AccessControl) to assign permissions for different operations to different roles.
* **Numerical overflow/underflow:** Although `SafeMath` is used (in Solidity 0.8.0+, SafeMath has been built-in to the compiler, but explicit use can emphasize security), you still need to be vigilant in complex calculations.
* **Audit:** Be sure to conduct a professional security audit before deployment.
3. **Interest calculation accuracy:** Solidity does not support floating point numbers, so integers need to be used for precise calculations. We used **Basis Points (BPS)** to represent interest rates, which is a common way of dealing with it.
4. **Withdrawal limit/lock-up period:** You can add additional logic, such as limiting the maximum daily withdrawal amount, or making withdrawals only possible after the deposit expires.
5. **Fund pool management:** The contract needs to have enough deposit tokens to pay interest and principal. In actual products, the funds collected by the contract are usually invested (for example, deposited in DeFi protocols to earn returns) to cover interest expenses. This introduces more complexity and risk.
6. **Pause function:** When a problem occurs with the contract, a `Pausable` function can suspend some or all operations for maintenance or upgrades (in non-upgradeable contracts, this usually means deploying a new contract).
7. **Upgradeability:** For long-running contracts, consider using a proxy pattern (such as UUPSProxy) to make it upgradeable so that bugs can be fixed or new features can be added.
  

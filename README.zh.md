## 短期存款产品智能合约代码示例

本教程将使用 **Solidity** 语言和 **ERC-20 代币**作为存款和利息支付的媒介（这在DeFi中非常常见，因为它可以方便地处理稳定币如USDT、USDC等）。

为了简洁和清晰，这个例子将包含核心功能，不包括复杂的错误处理和权限管理，但在实际生产环境中，这些都是必不可少的。

**核心功能：**

1.  **存款 (deposit):** 用户存入指定数量的ERC-20代币，并指定存款天数。
2.  **派息 (claimInterest):** 用户可以根据设定的日利率随时提取已产生的利息。
3.  **取回本金 (withdrawPrincipal):** 存款到期后，用户可以取回本金。
4.  **管理利率 (setDailyInterestRate):** 合约所有者可以设置日利率。

我们将假设已有一个部署好的ERC-20代币合约，并且用户在调用存款函数前已授权本合约可以转移其代币。

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; // 尽管0.8.0+版本已经内置安全数学，这里依然引入以强调安全性

/**
 * @title ShortTermDepositProduct
 * @dev 一个简单的短期存款产品智能合约。
 * 用户可以存入ERC-20代币，并按天获取利息，到期后取回本金。
 */
contract ShortTermDepositProduct is Ownable {
    using SafeMath for uint256;

    // 存款信息结构体
    struct Deposit {
        uint256 amount;            // 存款本金
        uint256 startTime;         // 存款时间戳
        uint256 durationDays;      // 存款期限（天）
        uint256 claimedInterest;   // 已提取的利息
    }

    // 映射：用户地址 => 存款信息
    mapping(address => Deposit) public deposits;

    // ERC-20代币地址，本金和利息将以此代币支付
    IERC20 public depositToken;

    // 日利率（以基础单位的万分之一表示，例如 100 代表 1% = 0.01）
    // 例如：如果日利率是 0.01% (0.0001), 那么 dailyInterestRate = 1
    // 如果日利率是 0.1% (0.001), 那么 dailyInterestRate = 10
    // 如果日利率是 1% (0.01), 那么 dailyInterestRate = 100
    uint256 public dailyInterestRateBasisPoints; // Basis Points (BPS) 10000 BPS = 100%

    // 事件
    event Deposited(address indexed user, uint256 amount, uint256 durationDays, uint256 startTime);
    event InterestClaimed(address indexed user, uint256 amount);
    event PrincipalWithdrawn(address indexed user, uint256 amount);
    event DailyInterestRateSet(uint256 newRate);

    /**
     * @dev 构造函数，部署时初始化存款代币地址。
     * @param _depositTokenAddress ERC-20 代币合约地址。
     * @param _initialDailyInterestRateBPS 初始日利率（以BPS为单位）。
     */
    constructor(address _depositTokenAddress, uint256 _initialDailyInterestRateBPS) Ownable(msg.sender) {
        require(_depositTokenAddress != address(0), "Invalid token address");
        depositToken = IERC20(_depositTokenAddress);
        dailyInterestRateBasisPoints = _initialDailyInterestRateBPS;
        emit DailyInterestRateSet(_initialDailyInterestRateBPS);
    }

    /**
     * @dev 设置日利率。仅限合约所有者调用。
     * @param _newRateBPS 新的日利率（以BPS为单位）。
     */
    function setDailyInterestRate(uint256 _newRateBPS) public onlyOwner {
        dailyInterestRateBasisPoints = _newRateBPS;
        emit DailyInterestRateSet(_newRateBPS);
    }

    /**
     * @dev 存款函数。用户存入ERC-20代币以购买理财产品。
     * 每次存款都会覆盖之前的存款信息，因此用户只能有一笔活动存款。
     * 在生产环境中，可能需要支持多笔存款。
     * @param _amount 存款金额。
     * @param _durationDays 存款期限（天）。
     */
    function deposit(uint256 _amount, uint256 _durationDays) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(_durationDays > 0, "Duration must be greater than 0");
        require(deposits[msg.sender].amount == 0, "You already have an active deposit. Please withdraw or claim first."); // 简单起见，只允许一笔存款

        // 从用户处转移代币到合约
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
     * @dev 计算用户当前可提取的利息。
     * @param _user 用户地址。
     * @return 可提取的利息金额。
     */
    function calculateAvailableInterest(address _user) public view returns (uint256) {
        Deposit memory userDeposit = deposits[_user];
        if (userDeposit.amount == 0) {
            return 0;
        }

        // 计算已过去的天数
        uint256 elapsedDays = (block.timestamp.sub(userDeposit.startTime)).div(1 days);

        // 如果存款期限已过，只计算到期前的利息
        if (elapsedDays > userDeposit.durationDays) {
            elapsedDays = userDeposit.durationDays;
        }

        // 计算总共应得利息
        // interest = principal * dailyRate * days
        // dailyRate = dailyInterestRateBasisPoints / 10000
        uint256 totalAccruedInterest = userDeposit.amount
                                        .mul(dailyInterestRateBasisPoints)
                                        .mul(elapsedDays)
                                        .div(10000); // 10000 是 BPS 的基数

        return totalAccruedInterest.sub(userDeposit.claimedInterest);
    }

    /**
     * @dev 提取已产生的利息。
     */
    function claimInterest() public {
        uint256 interestToClaim = calculateAvailableInterest(msg.sender);
        require(interestToClaim > 0, "No interest to claim");

        // 更新已提取利息记录
        deposits[msg.sender].claimedInterest = deposits[msg.sender].claimedInterest.add(interestToClaim);

        // 转移利息代币给用户
        require(depositToken.transfer(msg.sender, interestToClaim), "Interest transfer failed");

        emit InterestClaimed(msg.sender, interestToClaim);
    }

    /**
     * @dev 取回本金。只有当存款到期时才能调用。
     */
    function withdrawPrincipal() public {
        Deposit storage userDeposit = deposits[msg.sender];
        require(userDeposit.amount > 0, "No active deposit to withdraw");

        // 检查是否到期
        uint256 maturityTime = userDeposit.startTime.add(userDeposit.durationDays.mul(1 days));
        require(block.timestamp >= maturityTime, "Deposit has not matured yet");

        uint256 principalToReturn = userDeposit.amount;

        // 清除存款记录
        delete deposits[msg.sender];

        // 转移本金代币给用户
        require(depositToken.transfer(msg.sender, principalToReturn), "Principal transfer failed");

        emit PrincipalWithdrawn(msg.sender, principalToReturn);
    }

    /**
     * @dev 紧急提币功能，仅限所有者在紧急情况下使用。
     * 在生产环境中，这应该是一个更复杂且受限的功能。
     */
    function emergencyWithdraw(address _tokenAddress, uint256 _amount) public onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(owner(), _amount);
    }
}
```

-----

## 合约调用示例 (使用 Hardhat/Ethers.js)

这里我们将提供一个使用 Hardhat 和 Ethers.js 进行部署和交互的示例。你需要先安装 Hardhat 并设置好项目。

**1. 准备工作**

首先，确保你的项目已安装以下依赖：

```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-ethers @openzeppelin/contracts
```

**2. 部署ERC-20代币合约 (MockToken.sol)**

为了测试，我们需要一个ERC-20代币。创建一个文件 `contracts/MockToken.sol`：

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

**3. 部署和交互脚本 (`scripts/deployAndInteract.js`)**

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer, user1, user2] = await ethers.getSigners();

    console.log("部署合约中...");

    // 部署 Mock ERC-20 代币
    const MockToken = await ethers.getContractFactory("MockToken");
    // 初始供应 1,000,000 个代币，假设代币有18位小数
    const initialSupply = ethers.parseUnits("1000000", 18);
    const mockToken = await MockToken.deploy(initialSupply);
    await mockToken.waitForDeployment();
    const mockTokenAddress = await mockToken.getAddress();
    console.log(`MockToken 部署到: ${mockTokenAddress}`);

    // 给 user1 和 user2 一些代币用于测试
    const transferAmount = ethers.parseUnits("1000", 18);
    await mockToken.transfer(user1.address, transferAmount);
    await mockToken.transfer(user2.address, transferAmount);
    console.log(`向 user1 和 user2 转移了 ${ethers.formatUnits(transferAmount, 18)} mUSDT`);

    // 部署 ShortTermDepositProduct 合约
    // 初始日利率设置为 10 BPS (0.1%)
    const initialDailyRateBPS = 10;
    const ShortTermDepositProduct = await ethers.getContractFactory("ShortTermDepositProduct");
    const depositProduct = await ShortTermDepositProduct.deploy(mockTokenAddress, initialDailyRateBPS);
    await depositProduct.waitForDeployment();
    const depositProductAddress = await depositProduct.getAddress();
    console.log(`ShortTermDepositProduct 部署到: ${depositProductAddress}`);
    console.log(`初始日利率 (BPS): ${initialDailyRateBPS}`);

    console.log("\n--- 用户1 (user1) 进行存款 ---");
    const depositAmount = ethers.parseUnits("100", 18); // 存款 100 mUSDT
    const depositDurationDays = 7; // 存款 7 天

    // user1 授权 ShortTermDepositProduct 合约可以花费其 mUSDT
    await mockToken.connect(user1).approve(depositProductAddress, depositAmount);
    console.log(`User1 授权 ${depositProductAddress} 消费 ${ethers.formatUnits(depositAmount, 18)} mUSDT`);

    // user1 调用存款函数
    await depositProduct.connect(user1).deposit(depositAmount, depositDurationDays);
    console.log(`User1 存入了 ${ethers.formatUnits(depositAmount, 18)} mUSDT，期限 ${depositDurationDays} 天`);

    // 检查用户1的存款信息
    let user1Deposit = await depositProduct.deposits(user1.address);
    console.log(`User1 存款本金: ${ethers.formatUnits(user1Deposit.amount, 18)} mUSDT`);
    console.log(`User1 存款期限: ${user1Deposit.durationDays} 天`);
    console.log(`User1 存款时间: ${new Date(Number(user1Deposit.startTime) * 1000)}`);

    console.log("\n--- 模拟时间流逝 ---");
    // 模拟时间前进 3 天 (3 * 24 * 60 * 60 秒)
    await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []); // 挖一个新区块让时间生效
    console.log("时间已前进 3 天。");

    console.log("\n--- 用户1 (user1) 尝试提取利息 ---");
    let availableInterest = await depositProduct.calculateAvailableInterest(user1.address);
    console.log(`User1 可提取利息: ${ethers.formatUnits(availableInterest, 18)} mUSDT`);

    if (availableInterest > 0) {
        await depositProduct.connect(user1).claimInterest();
        console.log(`User1 成功提取了利息 ${ethers.formatUnits(availableInterest, 18)} mUSDT`);
    } else {
        console.log("User1 当前没有可提取的利息。");
    }

    // 再次检查用户1的存款信息，看claimedInterest是否更新
    user1Deposit = await depositProduct.deposits(user1.address);
    console.log(`User1 已提取利息: ${ethers.formatUnits(user1Deposit.claimedInterest, 18)} mUSDT`);

    console.log("\n--- 模拟时间前进至存款到期 ---");
    // 模拟时间前进，确保超过 7 天 (比如再前进 5 天，总共 3 + 5 = 8 天)
    await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);
    console.log("时间已前进至存款到期后。");

    console.log("\n--- 用户1 (user1) 提取本金 ---");
    // 在提取本金之前，再次检查是否有未提取的利息
    availableInterest = await depositProduct.calculateAvailableInterest(user1.address);
    if (availableInterest > 0) {
        console.log(`User1 在提取本金前还有可提取利息: ${ethers.formatUnits(availableInterest, 18)} mUSDT`);
        await depositProduct.connect(user1).claimInterest();
        console.log(`User1 成功提取了剩余利息 ${ethers.formatUnits(availableInterest, 18)} mUSDT`);
    } else {
        console.log("User1 在提取本金前没有剩余利息。");
    }

    const user1BalanceBeforeWithdraw = await mockToken.balanceOf(user1.address);
    console.log(`User1 提款前余额: ${ethers.formatUnits(user1BalanceBeforeWithdraw, 18)} mUSDT`);

    await depositProduct.connect(user1).withdrawPrincipal();
    console.log(`User1 成功提取了本金 ${ethers.formatUnits(depositAmount, 18)} mUSDT`);

    const user1BalanceAfterWithdraw = await mockToken.balanceOf(user1.address);
    console.log(`User1 提款后余额: ${ethers.formatUnits(user1BalanceAfterWithdraw, 18)} mUSDT`);

    // 验证存款记录是否已清除
    user1Deposit = await depositProduct.deposits(user1.address);
    console.log(`User1 存款记录（本金）：${ethers.formatUnits(user1Deposit.amount, 18)} mUSDT (应为0)`);

    console.log("\n--- 合约所有者修改日利率 ---");
    const newDailyRateBPS = 20; // 更改为 0.2%
    await depositProduct.connect(deployer).setDailyInterestRate(newDailyRateBPS);
    console.log(`所有者将日利率更新为 ${newDailyRateBPS} BPS`);
    console.log(`当前日利率 (BPS): ${await depositProduct.dailyInterestRateBasisPoints()}`);

    console.log("\n--- 示例结束 ---");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

**4. 运行脚本**

在你的 Hardhat 项目根目录下，运行：

```bash
npx hardhat run scripts/deployAndInteract.js
```

你会在控制台中看到模拟的部署和交互流程，包括存款、利息计算、利息提取以及本金提取。

-----

### 注意事项和改进方向

这个示例代码是为演示核心概念而设计的，在生产环境中，你需要考虑：

1.  **多笔存款：** 当前合约只支持每个用户一笔活动存款。要支持多笔存款，你需要一个 `mapping(address => mapping(uint256 => Deposit))` 或者 `mapping(address => Deposit[])` 结构，并为每笔存款生成一个唯一的ID。
2.  **安全性：**
      * **重入攻击防护：** 在涉及代币转移的函数（`claimInterest`, `withdrawPrincipal`）中，确保使用“检查-效果-交互”模式或 ReentrancyGuard 等库。
      * **授权管理：** 细化 `Ownable` 权限，可以引入角色管理（如 OpenZeppelin 的 AccessControl），将不同操作的权限分配给不同角色。
      * **数值溢出/下溢：** 尽管使用了 `SafeMath`（在Solidity 0.8.0+版本中，SafeMath已被编译器内置，但明确使用可以强调安全性），但在复杂的计算中仍需警惕。
      * **审计：** 务必在部署前进行专业的安全审计。
3.  **利息计算精度：** Solidity 不支持浮点数，因此需要使用整数进行精确计算。我们使用了 **Basis Points (BPS)** 来表示利率，这是一种常见的处理方式。
4.  **提款限额/锁定期：** 你可以添加额外的逻辑，例如限制每日最大提款金额，或者在存款到期后才能提款。
5.  **资金池管理：** 合约需要有足够的存款代币来支付利息和本金。在实际产品中，通常会将合约收集的资金进行投资（例如，存入DeFi协议赚取收益），以覆盖利息支出。这会引入更多的复杂性和风险。
6.  **暂停功能：** 在合约出现问题时，一个 `Pausable` 功能可以暂停部分或所有操作，以便进行维护或升级（在不可升级合约中，这通常意味着部署新合约）。
7.  **可升级性：** 对于长期运行的合约，考虑使用代理模式（如 UUPSProxy）使其可升级，以便修复bug或添加新功能。


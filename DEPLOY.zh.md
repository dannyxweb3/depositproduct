
## ✅ 一、可用的测试网络（Testnet）

根据你合约的目标链（比如 Ethereum、Tron、Solana），可选择不同测试链：

### 🔷 以太坊生态（Solidity 开发）

| 测试链                 | 说明                                        |
| ------------------- | ----------------------------------------- |
| **Sepolia** ✅ 推荐    | 以太坊主推，活跃度高，支持 Etherscan，代替 Rinkeby/Goerli |
| **Holesky**         | 更大规模的测试链，主要用于协议开发者测试，稳定性好                 |
| ~~Goerli~~ ❌        | 不推荐，新地址难拿水；已逐渐废弃                          |
| ~~Rinkeby/Kovan~~ ❌ | 已关闭                                       |

🔗 获取水龙头（Faucet）：

* Sepolia：[https://sepoliafaucet.com](https://sepoliafaucet.com)
* 或通过Alchemy、Infura等平台免费领取

---

### 🔶 BNB Chain

| 测试链                                                                                         | URL                           |
| ------------------------------------------------------------------------------------------- | ----------------------------- |
| BNB Testnet                                                                                 | `https://testnet.bscscan.com` |
| Faucet：[https://testnet.binance.org/faucet-smart](https://testnet.binance.org/faucet-smart) |                               |

---

### 🔴 Tron 网络（非 EVM）

| 网络                                                                              | 工具        |
| ------------------------------------------------------------------------------- | --------- |
| **Nile Testnet**                                                                | Tron官方测试链 |
| 开发语言：Java/TronBox/Truffle-like                                                  |           |
| Faucet：[https://nileex.io/join/getTestCoin](https://nileex.io/join/getTestCoin) |           |

---

### 🟣 Solana 网络（非 EVM）

| 测试链                                      | 工具支持         |
| ---------------------------------------- | ------------ |
| **Devnet** ✅                             | Solana 的主测试链 |
| 使用 Rust + Anchor 框架开发                    |              |
| Faucet：通过 CLI 工具 `solana airdrop` 获取 SOL |              |

---

## ✅ 二、部署到测试链前你需要准备的工作

### 🧱 1. 准备开发工具

| 工具               | 说明                       |
| ---------------- | ------------------------ |
| **Hardhat** ✅ 推荐 | Solidity 的主流框架，便于本地测试和部署 |
| Truffle          | 传统框架，支持EVM开发             |
| Foundry          | 新兴纯命令行工具，速度快             |
| Remix IDE        | Web IDE，适合小项目测试部署        |

---

### 🪙 2. 获取测试币（ETH, BNB, SOL等）

使用对应测试链的 Faucet 获取：

* 在部署时需要支付 Gas 费
* 水龙头获取后，等待10秒至几分钟到账

---

### 🛠 3. 配置你的钱包和网络

以 MetaMask 为例：

* 添加测试网络（如 Sepolia、BNB Testnet 等）
* 导入你的测试账号
* 确保有测试币余额

---

### 🧪 4. 编译、测试和部署合约

* 使用 Hardhat 编译 `.sol` 合约文件：

  ```bash
  npx hardhat compile
  ```

* 在本地运行测试：

  ```bash
  npx hardhat test
  ```

* 配置 `hardhat.config.js` 中的测试网信息（如Infura或Alchemy的RPC）

  ```js
  sepolia: {
    url: "https://sepolia.infura.io/v3/YOUR_INFURA_KEY",
    accounts: [PRIVATE_KEY]
  }
  ```

* 执行部署脚本：

  ```bash
  npx hardhat run scripts/deploy.js --network sepolia
  ```

---

### 🧾 5. 验证合约源码（可选）

* 在 [Sepolia Etherscan](https://sepolia.etherscan.io/) 上提交源代码
* 或使用 `hardhat-etherscan` 插件直接验证：

  ```bash
  npx hardhat verify --network sepolia <contract_address> "constructor_arg1" ...
  ```

---

### 📲 6. 模拟调用合约函数

你可以用以下方式与合约交互：

* **Remix连接钱包** 调用合约方法
* **Hardhat script** 运行调用脚本
* **Frontend DApp** 调用合约（测试前端逻辑）
* **Etherscan测试链界面** 调用合约的公共方法


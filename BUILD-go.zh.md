
# Golang 调用以太坊智能合约

部署到 Sepolia 测试网的理财合约，可以通过 `go-ethereum` 提供的 `geth` 绑定库完成。流程如下：

---

## ✅ 步骤概览

1. 编译合约 ABI 和 BIN
2. 用 `abigen` 工具生成 Golang 合约绑定代码
3. 编写 Golang 程序调用合约（读/写函数）
4. 使用 Infura、Alchemy 或本地节点连接 Ethereum 网络

---

## 🧩 示例：调用你之前的 `FixedDeposit.sol` 合约

我们以调用该合约的 `deposit()` 函数为例。

---

### 1. 安装依赖

确保你已安装以下组件：

```bash
go install github.com/ethereum/go-ethereum/cmd/abigen@latest
go get github.com/ethereum/go-ethereum
```

---

### 2. 编译合约为 Golang 文件

假设你有以下文件：

* `FixedDeposit.sol`：你的 Solidity 合约
* 合约已部署地址：例如 `0xabc123...`

使用 `solc` 生成 ABI 和 BIN：

```bash
solc --abi --bin contracts/FixedDeposit.sol -o build/
```

然后生成绑定代码：

```bash
abigen --bin=build/FixedDeposit.bin --abi=build/FixedDeposit.abi --pkg=deposit --out=fixed_deposit.go
```

这样你会得到一个 `fixed_deposit.go`，可以在 Golang 项目中使用。

---

### 3. Go 代码调用合约（示例）

```go
package main

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"log"
	"math/big"

	"deposit" // 你生成的绑定包名
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	// 连接 RPC
	client, err := ethclient.Dial("https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID")
	if err != nil {
		log.Fatal(err)
	}

	// 私钥
	privateKeyHex := "0xYOUR_PRIVATE_KEY"
	privateKey, err := crypto.HexToECDSA(privateKeyHex[2:])
	if err != nil {
		log.Fatal(err)
	}

	publicKey := privateKey.Public()
	publicKeyECDSA, _ := publicKey.(*ecdsa.PublicKey)
	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)

	// 设置 auth 交易信息
	chainID := big.NewInt(11155111) // Sepolia 的 chain ID
	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		log.Fatal(err)
	}

	// 实例化合约
	contractAddress := common.HexToAddress("0xYourDeployedContractAddress")
	instance, err := deposit.NewFixedDeposit(contractAddress, client)
	if err != nil {
		log.Fatal(err)
	}

	// 示例：调用 deposit 方法（假设该函数接受 USDT 地址和数额）
	tokenAddress := common.HexToAddress("0xUSDT_TOKEN_ADDRESS")
	amount := big.NewInt(1000000) // 例如 1 USDT，单位取决于合约

	tx, err := instance.Deposit(auth, tokenAddress, amount)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Deposit tx sent: %s\n", tx.Hash().Hex())
}
```

---

### 🛠️ 补充说明

* 如果 `deposit()` 是 payable 函数，需要加 `auth.Value = big.NewInt(...)`
* 如果是调用 `view` 方法（比如读取利率），用：

```go
rate, err := instance.InterestRate(nil)
```

---

## ✅ 你需要准备的环境

* Golang v1.20+
* Infura 或 Alchemy 账号（免费）
* 合约 ABI / BIN 文件
* 已部署合约地址
* Metamask 中导出的私钥（用于测试）


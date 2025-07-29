
const contract = new ethers.Contract(contractAddress, abi, signer);

// 1. 授权合约可以转账USDT
await usdt.approve(contract.address, depositAmount);

// 2. 存入理财产品
await contract.deposit(depositAmount);

// 3. 过一天后，领取利息
await contract.claimInterest();

// 4. 30天后提取本金 + 剩余利息
await contract.withdraw();

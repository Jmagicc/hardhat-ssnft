require("@nomicfoundation/hardhat-toolbox");


// 申请alchemy的api key
const ALCHEMY_API_KEY = "50987f18ba7a45ffab01ba309e43d411";

//将此私钥替换为测试账号私钥
//从Metamask导出您的私钥，打开Metamask和进入“帐户详细信息”>导出私钥
//注意:永远不要把真正的以太放入测试帐户
const GOERLI_PRIVATE_KEY = "98110d6402509e6b9a5b18869b56c38e3740b9183cf492466694caeff2a9f258";

// The next line is part of the sample project, you don't need it in your
// project. It imports a Hardhat task definition, that can be used for
// testing the frontend.
require("./tasks/faucet");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.14",
    networks: {
        // 本地测试网络
        hardhat: {
            chainId: 1337,
            gasPrice: 20000000000,
            blockGasLimit: 100000000,
            allowUnlimitedContractSize: true,


        },
        goerli: {
            url: `https://goerli.infura.io/v3/${ALCHEMY_API_KEY}`,
            accounts: [GOERLI_PRIVATE_KEY],
            chainId: 5,
            saveDeployments: true,
            tags: ["staging"],
        }
    },
    etherscan: {
        apiKey: {
            goerli: "KRMKBCB48Y93ZNH6TEXUP5IJDFEI8JZKYS"
        }
    }
};
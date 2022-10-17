const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");

//初始化部署得到合约实例
describe("初始化部署得到合约实例", function() {
    async function deployTokenFixture() {
        const Token = await ethers.getContractFactory("PaymentSplit");
        const [owner, addr1, addr2] = await ethers.getSigners();

        const hardhatToken = await Token.deploy(["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"], [1, 2, 3]);

        await hardhatToken.deployed();

        return { Token, hardhatToken, owner, addr1, addr2 };
    }

    // 整体测试分账流程（会消耗gas）
    describe("", function() {
        it("整体测试分账流程", async function() {
            const { hardhatToken, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);
            // //--------1.部署合约成功后，向合约中存入60e
            expect(await hardhatToken.getBalance(hardhatToken.address)).to.equal(0);

            const tx = {
                to: hardhatToken.address,
                value: ethers.utils.parseEther("60")
            }
            const receipt = await owner.sendTransaction(tx)
            await receipt.wait() // 等待链上确认交易
                //console.log("receipt::", receipt) // 打印交易详情


            expect(await hardhatToken.getBalance(hardhatToken.address)).to.equal(ethers.utils.parseEther("60"));
            // console.log("合约中的余额有::", "", await hardhatToken.getBalance(hardhatToken.address));
            //--------2.开始release, 测试每个收益人可获取的e

            const payment = await hardhatToken.releasable(addr1.address);
            const paymentVal = ethers.utils.formatUnits(payment, 0)
                //console.log("该地址::", addr1.address, "，可以获取::", paymentVal)

            // 消费受益人提款事件
            await expect(hardhatToken.release(addr1.address))
                .to.emit(hardhatToken, "PaymentReleased").withArgs(addr1.address, paymentVal)
        });
    })

    // 查询受益人份额，查询受益人对应的下标，查询收益人目前可以提款的金额（不会消耗gas）
    describe("", function() {
        it("查询受益人的收益", async function() {
            const { hardhatToken, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);
            // //--------1.部署合约成功后，向合约中存入60e
            expect(await hardhatToken.getBalance(hardhatToken.address)).to.equal(0);

            const tx = {
                to: hardhatToken.address,
                value: ethers.utils.parseEther("60")
            }
            const receipt = await owner.sendTransaction(tx)
            await receipt.wait() // 等待链上确认交易

            expect(await hardhatToken.getBalance(hardhatToken.address)).to.equal(ethers.utils.parseEther("60"));

            //查询受益人对应的下标
            const payees_1 = await hardhatToken.payees(0)
            expect(payees_1).to.equal(owner.address);

            //查询受益人可分得的份数
            const payees_1_shares = await hardhatToken.shares(addr1.address)
            expect(payees_1_shares).to.equal(2);

            //查看收益人可分得收益
            const payment = await hardhatToken.releasable(addr1.address);
            const paymentVal = ethers.utils.formatUnits(payment, 0);
            expect(paymentVal).to.equal(ethers.utils.parseEther("20"));

        })
    })







});
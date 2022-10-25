var Web3= require('web3');   
var web3= new Web3(new Web3.providers.HttpProvider("https://goerli.infura.io/v3/50987f18ba7a45ffab01ba309e43d411"));

var contractAbi = require('./PaymentSplit.json')                      //合约ABI
var contractAddress = "0xb96D0536B3ad9CfB2B20F063fe7e86c14cF7d1f1";   //合约地址
var onlyReadContract =  new web3.eth.Contract(contractAbi,contractAddress); //只可读实例

// var webowner = new Web3(window.web3.currentProvider)
// var senderContract= new webowner.eth.Contract(contractAbi,contractAddress); //可读可写实例 //创建该实例的前提是,得先连接小狐狸钱包



// 分账合约：
// 写入区块：

// 1.提取收益 release (address _account)
// async function release(_account){

//     let sender= await  webowner.eth.getAccounts()
   
//     await senderContract.methods.release(_account).send({from: sender[0]})
//         .then(function(receipt){
//             return receipt.status
//     });
//      await web3.eth.getBlockNumber().then(function(res){
//     console.log(res,"::当前区块高度")
//      });
//     return false
// }

// 只读区块：
// 2.查合约、查地址余额 getBalance(address _addr)
async function getBalance(_addr) {
    let data
    await onlyReadContract.methods.getBalance(_addr).call().then(function(res){
        data=res
    });
    return data
}


// 3.根据下标得到收益人的地址（从下标0开始） payees(uint256 num)
async function payees(num) {
    let data
    await onlyReadContract.methods.payees(num).call().then(function(res){
        data=res
        console.log(res,"0000")
    });

    return data
}
 

// 4.每个受益人目前可领取的收益releasable(address _account)
async function releasable(_account) {
    let data
    await onlyReadContract.methods.releasable(_account).call().then(function(res){
        data=res
    });

    return data
}


// 5.每个受益人已领取到的收益released(address c)
async function released(_account) {
    let data
    await onlyReadContract.methods.released(_account).call().then(function(res){
        data=res
    });
    return data
}


// 6.查看每个收益人可分得份额shares(address _account)
async function shares(_account) {
    let data
    await onlyReadContract.methods.shares(_account).call().then(function(res){
        data=res
    });
    return data
}

// 7.事件的监听,是否要存入数据库  TODO
// 收益人提款
// onlyReadContract.getPastEvents('PaymentReleased', {
//     filter: {},
//     fromBlock: 0,// TODO
//     toBlock: 'latest'
// }, function(error, events){ console.log(events); })
// .then(function(events){
//     console.log(events)
// });
// //本合约收款
// onlyReadContract.getPastEvents('PaymentReceived', {
//     filter: {},
//     fromBlock: 0, // TODO
//     toBlock: 'latest'
// }, function(error, events){ console.log(events); })
// .then(function(events){
//     console.log(events)
// });





//导出相对应的方法
// export default {
//     release,
//     getBalance,
//     payees,
//     releasable,
//     released,
//     shares

// };

payees(1);



// root 数生成器demo，node环境下执行  
// 后续盲盒结束后，需要mint单人物图或配件图需要根据调用者地址生成proof 并携带proof去铸造NFT

const whiteList =require("./whitelist.json");

const {MerkleTree} = require("merkletreejs");
const keccak256=require("keccak256");

const leaves =whiteList.data.map(x =>keccak256(x));
const tree = new MerkleTree(leaves,keccak256,{sortPairs:true});

var root=tree.getHexRoot();
var proof=tree.getHexProof(keccak256("0xC9D994e2E2614bE1218AfB55104723C2c2B8AA13"))


console.log("root :",root);
console.log("proof :",proof);



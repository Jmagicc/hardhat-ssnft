//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

interface Ibloom{
     function cnOwnerOf(uint256 tokenId_)  external returns(address);  //判断创世图的归属地址是谁
}

interface Ifusion{
     function ownerOf(uint256 tokenId_) external returns (address);  //判断融合图的归属地址是谁
}

contract auxiliary is Ownable,Pausable,ERC1155URIStorage,IERC1155Receiver{
    using Strings for uint256;
    string public name;    // 合约名称
    string public symbol;  // 简称代号
    string public baseURL; // 盲盒Cid

    
    bytes32 public root; // 保存 MerkleProof 生成的白名单(用于空投)
    uint256 public auxiliarySaleStartTimestamp = 1660234648;   // 超过这个时间才可以自由开盒（用来限制主办方地址开盒后不能立马交易）

    //NFT专享参数
    struct NftToken{
      string tokenURI;
      bool isVaild;
    }
    uint256 private constant MAXMINT_NFT = 1;   // erc1155处于erc20和erc721的中间地带，如果发行量为n个则是erc20,如果发行量为1个,则视为nft
    mapping(uint256 => NftToken)  public tokenURIs;  // nft的tokenId => ipfs://主图CID/tokenId.json
    string private baseExtension = ".json";     // 主图的元数据扩展类型（一般是json）
    mapping(uint256 => string) public NFTbase;  //盲盒id => 开盒之后的baseURL
    mapping(uint256 => uint256[]) public fusionInfo;

 
    struct Box {
        uint    id;      // 盲盒id  可发行多种盲盒 
        string  name;    // 盲盒名字
        string  symbol;  // 盲盒代号
        uint256 mintNum; // 被成功mint的数量
        uint256 openNum; // 被开箱的数量
        uint256 totalSupply;  // 盲盒发行总量
    }
    // 一种box代表一类配件
    mapping(uint => Box) public boxMap;
 
    constructor(string memory url_) ERC1155(url_) {
        name = "Twelve constellations slim blind box";
        symbol = "TBOX";
        baseURL = url_;
       // root = _root; // deploy 时候传入 Merkle Root ,bytes32 _root
    }


    // 创建一个新的盲盒类型
    function newBox(uint boxID_, string memory name_,string memory symbol_, uint256 totalSupply_) public onlyOwner {
        require(boxID_ > 0 && boxMap[boxID_].id == 0, "box id invalid");
        boxMap[boxID_] = Box({
            id: boxID_,
            name: name_,
            symbol:symbol_,
            mintNum: 0,
            openNum: 0,
            totalSupply: totalSupply_
        });
    }

    
    // 修改某个盲盒的属性
    function updateBox(uint boxID_, string memory name_,string memory symbol_, uint256 totalSupply_) public onlyOwner {
        require(boxID_ > 0 && boxMap[boxID_].id == boxID_, "id invalid");
        require(totalSupply_ >= boxMap[boxID_].mintNum, "totalSupply err");
 
        boxMap[boxID_] = Box({
            id: boxID_,
            name: name_,
            symbol:symbol_,
            mintNum: boxMap[boxID_].mintNum,
            openNum: boxMap[boxID_].openNum,
            totalSupply: totalSupply_
        });
    }

 
    
    // 用户mint配件渠道  白名单proof控制  可以来自用户是否拥有主图
    function mintAuxiliary(address to_, uint boxID_, uint num_, bytes32[] memory proof) public  whenNotPaused  {
          // 校验 msg.sender 是否在白名单
        require(isValid(proof, msg.sender), "Not a part of Allowlist");
        require(num_ > 0, "mint number err");
        require(boxMap[boxID_].id > 1, "box id err");
        require(boxMap[boxID_].totalSupply >= boxMap[boxID_].mintNum + num_, "mint number is insufficient");
        require(block.timestamp >= auxiliarySaleStartTimestamp, "Minting is not available");
 
        boxMap[boxID_].mintNum += num_;
        _mint(to_, boxID_, num_, "");
    }
    // 用户可以mint多种盲盒，白名单proof控制    例如衣服盲盒2套，裤子盲盒3套，鞋子盲盒2双，帽子盲盒2顶  只属于支付一笔手续费（直接起飞）
    function mintBatchAuxiliary(address to_, uint[] memory boxIDs_, uint256[] memory nums_, bytes32[] memory proof) public  whenNotPaused {
          // 校验 msg.sender 是否在白名单
        require(isValid(proof, msg.sender), "Not a part of Allowlist");
        require(boxIDs_.length == nums_.length, "array length unequal");
        require(block.timestamp >= auxiliarySaleStartTimestamp, "Minting is not available");
 
        for (uint i = 0; i < boxIDs_.length; i++) {
            require(boxMap[boxIDs_[i]].id > 1, "box id err");
            require(boxMap[boxIDs_[i]].totalSupply >= boxMap[boxIDs_[i]].mintNum + nums_[i], "mint number is insufficient");
            boxMap[boxIDs_[i]].mintNum += nums_[i];
        }
 
        _mintBatch(to_, boxIDs_, nums_, "");
    }
 
    // (购盲盒配件的开箱),燃烧盲盒 支持批量燃烧同系列的配件盲盒  例如燃烧2个衣服盲盒  3个衣服盲盒
    function burnAuxiliaryBox(address from_, uint boxID_, uint256 num_) public whenNotPaused {
        require(_msgSender() == from_ || isApprovedForAll(from_, _msgSender()), "burn caller is not owner nor approved");
            for (uint256 i = 0; i < num_; i++) {
                //NFT的唯一id生成   盲盒boxID*10000 + 开箱数boxMap[boxID_].openNum
                uint256 mintNFTindex = boxID_*10000+ boxMap[boxID_].openNum;
                boxMap[boxID_].openNum +=  MAXMINT_NFT;
                _burn(from_, boxID_, MAXMINT_NFT);
               
               
                // 燃烧盲盒之后需要mint一个erc1155的nft
                _mint(from_, mintNFTindex, MAXMINT_NFT, "");
                tokenURIs[mintNFTindex].tokenURI=mintNFTindex.toString();
                tokenURIs[mintNFTindex].isVaild=true;


                //tokenURIs[mintNFTindex].tokenURI
                _setURI(mintNFTindex, string(abi.encodePacked(NFTbase[boxID_], mintNFTindex.toString(), baseExtension)));
                
            }
    }

    //v2 拆卸创世图得到至少1个单人物图和n个配件图   有可能获取1个单宠物图    TODO 未考虑再一次融合了再拆(先去判断一下tokenIdArr的key是不是tokenid,有代表是融合再拆图）
     function mintAux(address to_, uint256[] memory boxIDs_,uint256[] memory nums_,uint256 tokenId_,address Contract) external  whenNotPaused{
    
       
        if (fusionInfo[tokenId_].length != 0) {
            //todo 因为这个方法设置了对外可访问，   tokenId_判断不存在后 提供接口(太关键了)  是否有这个资格融合
             require(Ifusion(Contract).ownerOf(tokenId_) == to_,"The token has been burning, remove the standard");
              //融合图再拆,解析得到对应配件transfer给用户
            _safeBatchTransferFrom(address(this),to_,fusionInfo[tokenId_], nums_,"");
              //清空对应关系
            delete fusionInfo[tokenId_];

          }else{
            //todo 因为这个方法设置了对外可访问，   tokenId_判断不存在后 提供接口(太关键了)   是否有这个资格拆创世
            require(Ibloom(Contract).cnOwnerOf(tokenId_) == address(0),"The token has been burning, remove the standard");
            //创世图拆
            require(boxIDs_.length == nums_.length, "array length unequal");
            //校验参数     
            for (uint i = 0; i < boxIDs_.length; i++) {
                require(boxIDs_[i] > 1 && boxMap[boxIDs_[i]].id ==boxIDs_[i] , "box id invalid");
            }
            for (uint j = 0; j < nums_.length; j++) {
                require( nums_[j]==1, "nums_  invalid");
            }
            burnBatchByone(to_, boxIDs_,tokenId_);
          }

     }

    // v2 融合--只有1个单人物图、(只有1个宠物单图,可有可无)和n个配件图去合约 mint一个融合超图（可再拆卸）
    function fusionPrecondition(address from_,uint[] memory tokenIdArr_,uint256[] memory nums_,uint256 tokenId_) external whenNotPaused{  
        //todo 因为这个方法设置了对外可访问  tokenId_判断不存在后 提供接口(太关键了)。这个还好，_safeBatchTransferFrom，他要是没权限根本也转不出去

        //1.判断至少有一个是单人物图
        require(tokenIdArr_[0]>=150000&&tokenIdArr_[0]<250000&&tokenIdArr_.length>1,"there must be a main-character and aux") ;
        //2.回收配件去 合约
        _safeBatchTransferFrom(from_,address(this),tokenIdArr_, nums_,"");
        //3.要记录融合的信息上链，Push -> mappin  tokenid ->tokenIdArr_[]
        fusionInfo[tokenId_]=tokenIdArr_;
    }


    // 获取地址的以太余额
    function getBalance(address addr) view public returns(uint){
        return addr.balance;
    }
    
   
    // 拆得到配件
    function burnBatchByone(address from_, uint[] memory boxIDs_,uint256 tokenId_) private whenNotPaused {
        for (uint j = 0; j < boxIDs_.length; j++) {
                //NFT的唯一id生成   盲盒boxIDs_[j]*10000 + 开箱数boxMap[boxIDs_[j]].openNum
                uint256 mintNFTindex = boxMap[boxIDs_[j]].id*10000 + boxMap[boxIDs_[j]].openNum;
                boxMap[boxIDs_[j]].openNum +=  MAXMINT_NFT;
            
                // 燃烧盲盒之后需要mint一个erc1155的nft
                _mint(from_, mintNFTindex, MAXMINT_NFT, "");
                tokenURIs[mintNFTindex].tokenURI=mintNFTindex.toString();
                tokenURIs[mintNFTindex].isVaild=true;


                // tokenURIs[mintNFTindex].tokenURI 后续完成及时上传对应 json源数据
                _setURI(mintNFTindex, string(abi.encodePacked(NFTbase[boxIDs_[j]], mintNFTindex.toString(), baseExtension)));
        }
        tokenURIs[tokenId_].isVaild=false;
}




 
 
    // 获取已经上链的某个盲盒蒙版cid
    function boxURL(uint boxID_) public view returns (string memory s) {
        require(boxMap[boxID_].id != 0, "box not exist");
       
        return string(abi.encodePacked(baseURL, boxID_));
    }

    // 获取已经上链的某个真实配件cid
    function nftURL(uint tokenID_,uint boxID_) public view returns (string memory s) {
         require(tokenURIs[tokenID_].isVaild, "nft is not valid");
      
        // return strConcat(NFTbase[boxID_],tokenURIs[tokenID_].tokenURI);  
        return string(abi.encodePacked(NFTbase[boxID_],tokenURIs[tokenID_].tokenURI));
    }

    // 基于地址名单发空投 项目方替用户出mint gas费,目前仅支持对一种配件类空投每人发送一个配件图 ["0xC9D994e2E2614bE1218AfB55104723C2c2B8AA13"]
    function airdrop(address[] calldata addresses_, uint boxId_) external onlyOwner {
        require(addresses_.length > 0, "mint number err");
        require(boxId_ > 1, "box id err");
        require(boxMap[boxId_].totalSupply >= boxMap[boxId_].mintNum + addresses_.length, "mint number is insufficient");


        for (uint i = 0; i < addresses_.length; i++) {
             //NFT的唯一id生成   盲盒boxId_*10000 + 开箱数boxMap[boxId_].openNum
                uint256 mintNFTindex = boxId_*10000+ boxMap[boxId_].openNum;
                boxMap[boxId_].openNum +=  MAXMINT_NFT;
            
                // 发空投
                _mint(addresses_[i], mintNFTindex, MAXMINT_NFT, "");
                tokenURIs[mintNFTindex].tokenURI=mintNFTindex.toString();
                tokenURIs[mintNFTindex].isVaild=true;
                // tokenURIs[mintNFTindex].tokenURI
                _setURI(mintNFTindex, string(abi.encodePacked(NFTbase[boxId_], mintNFTindex.toString(), baseExtension)));
                
        }
    }
   
    //盲盒 ipfs://CID/
    function setURL(string memory newURL_) public onlyOwner {
        baseURL = newURL_;
    }

    //NFT  ipfs://NFT的CID/      跟创世图的老规矩一样，可先不上传. 有事件消息回调给web2.0的后台,mint多少，咱们就上多少张图的cid（避免了盲盒未开先知道内容）但是，每一次这样都要消耗gas
    function setNFTbase(string memory newURL_,uint boxID_) public onlyOwner {
        NFTbase[boxID_] = newURL_;
    }
    
    // 可暂停合约开关
    function setPause(bool isPause) public onlyOwner {
        if (isPause) {
            _pause();
        } else {
            _unpause();
        }
    }


    // 校验方法，传入两个数据，proof = 证明数据、lear = 地址
    function isValid(bytes32[] memory proof, address useraddress) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(useraddress));
        return MerkleProof.verify(proof,root,leaf);

    }
    // 设置白名单的默克尔树根
    function setRoot(bytes32 _root) public onlyOwner {
        root = _root;
    }


    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || 
        interfaceId == type(ERC1155URIStorage).interfaceId || 
        super.supportsInterface(interfaceId);
    }

}
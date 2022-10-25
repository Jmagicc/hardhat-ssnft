// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";



interface MyAuxiliary{
    function mintAux(address to_, uint256[] memory boxIDs_,uint256[] memory nums_,uint256 tokenId_,address bloomContract) external;  //拆        得到1个单主图和n个配件
    function balanceOf(address account,uint256 boxId) view  external returns (uint256); // 判断这个盲盒是否属于地址
}



contract CryptoLeo is ERC721A, Ownable,Pausable {
    using Strings for uint256;
   
    uint256 public constant max_genesis_supply = 8868;    // 总量发行8868个
    uint256 public mintPrice =  0.00001 ether;   // 地板价 0.00001e =10000 GWEI
    uint public maxPublicMintsPerWallet = 100;              // 某个地址最多能拥有该合约的100个nft
    uint256 public publicSaleStartTimestamp = 1660234648;   // 超过这个时间才可以自由开盒（用来限制主办方地址开盒后不能立马交易）  要改例如：超过这个时间才可以自由交易 
    


    mapping(address => uint) public mintedNFTs;            // 判断某个地址拥有的nft数量
    mapping (address => bool) public organizerWallets;     // 判断是否是主办方地址

    string baseURI;                                 // 主图的cid（部署时可以先传空，不填）
    string public baseExtension = ".json";          // 主图的元数据扩展类型（一般是json）
    mapping(uint256 => string) public _tokenURIs;  // nft的tokenId => tokenId
    bool internal locked;



    event mintCallback(address addr,uint amount);   // 事件：mint创世图
    event fusionCallback(address addr);             // 事件：mint融合图

    // 合约初始化构造函数  名称  简称 一次mint最多只能是10个
    constructor(string memory initBaseURI)
         ERC721A("crypto leo", "LEO",10)
    {
        setBaseURI(initBaseURI);
        // 也可以在部署的时候将项目方地址加上，项目方地址多的话，也可以做成默克尔数白名单类似来做校验。会比较省gas费
        setWallet(_msgSender());
        // setWallet();
        // setWallet();
        // setWallet();
    }

    // 将地址加入主办方地址名单中
    function setWallet(address _wallet) public{
        organizerWallets[_wallet]=true;
    }

    // 创世图mint
    function publicMint(uint amount) public payable whenNotPaused{
        require(block.timestamp >= publicSaleStartTimestamp, "Minting is not available");
        require(mintedNFTs[_msgSender()] + amount <= maxPublicMintsPerWallet, "Too much mints for this wallet!");
        // TODO收取mint费用
        //require(mintPrice * amount == msg.value, "Wrong et+hers value");
      
        mintedNFTs[_msgSender()] += amount;
        mint(amount);
    }
    
    function mint(uint amount) internal whenNotPaused{
        require(tx.origin == _msgSender(), "The caller is another contract");
        require(amount > 0, "Zero amount to mint");
        require(totalSupply() +  amount <= max_genesis_supply, "Tokens supply reached limit");
         _safeMint(_msgSender(),amount);

        emit mintCallback(_msgSender(),amount);
    }


    function cnOwnerOf(uint256 tokenId_) view external returns(address){
       return ownerOf(tokenId_);
    }  

/** burn ERC721 token  拆，得到配件和单人物图*/ 
//todo 要加上得到的获取的配件分类id ,对应的数组len数量为1  10背景 15人物单图 20裤子 25夹克 30鞋子 8015宠物    为了方便后续的扩展，boxIDs,num_做成形参
    function disassemblyToBurn(address auxiliaryContract,uint256 tokenId_,uint256[] memory boxIDs_,uint256[] memory nums_) public   whenNotPaused returns (bool) {                 
        require(                                                                // 想要 拆卸燃烧 成功，必须满足以下条件之一：
            _msgSender() == ownerOf(tokenId_) ||                                // 1.操作者即是该 token 的拥有者
            _msgSender() == getApproved(tokenId_) ||                            // 2.操作者接受了该 token 拥有者的授权，即已经进行了 approve 操作
            isApprovedForAll(ownerOf(tokenId_), _msgSender()),                  // 3.操作者接受了该 token 拥有者的完全授权，即已经进行了 setApprovalForAll 操作
            "burn caller is not owner nor approved"
        );
        // TODO 收取拆卸的费用
        // require(mintPrice * amount == msg.value, "Wrong et+hers value");
        
     
        _burn(tokenId_);
        mintedNFTs[_msgSender()] -= 1;

        // uint256[]   memory boxIDs_= [10,15,20,25,30];
        // uint256[]   memory nums_= [1,1,1,1,1];

        //得到配件和单人物图
       MyAuxiliary(auxiliaryContract).mintAux(_msgSender(),boxIDs_,nums_,tokenId_,address(this));
		return true;
    }

 

    // 输入nft的tokenId获取  ipfs://主图源数据json-CID/tokenId.json
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
     
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI;
         // 如果是融合图
        if (bytes(_tokenURI).length > 0) {
           return string(abi.encodePacked(_tokenURI, baseExtension));
        }
        
        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        // 如果是创世图
        return string(abi.encodePacked(base, tokenId.toString(), baseExtension));
    }



    // 判断如果是名单中的地址，则限制一星期无法交易
     function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public   override   {
        // 判断该tokenId(nft)是地址的拥有者，授权不算 
         if (from == ownerOf(tokenId) && organizerWallets[from]){
           require(timeByTokenId[tokenId]>publicSaleStartTimestamp && timeByTokenId[tokenId]<=1660803717,"The organizer's address cannot be traded within one week");   
         }
        safeTransferFrom(from, to, tokenId, "");
    }


 

    // onlyOwner修饰器 只有管理员（部署者）可调用以下方法
    // 设置地板价
    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

  

    // 设置盲盒中的主图源数据   例如：1000.json  
    // 等共售卖差不多了，手动开启盲盒前五分钟上传主图元数据到ipfs获取cid(用来避免盲盒没开知道提前知道图的情况）
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    // 设置元数据的格式 一般来说是json
    function setBaseExtension(string memory _newBaseExtension) public onlyOwner{
        baseExtension = _newBaseExtension;
    }

    // 设置公售时地址可拥有的nft数量
    function setMaxPublicMintsPerWallet(uint256 _maxBalance) public onlyOwner {
        maxPublicMintsPerWallet = _maxBalance;
    }

    // 可暂停合约暂时不能使用   whenNotPaused修饰器代表 合约暂停了不能使用该方法
    function setPause(bool isPause) public onlyOwner {
        if (isPause) {
            _pause();
        } else {
            _unpause();
        }
    }

    // 提现合约里的ether去部署者地址中
    function withdraw(address to) public onlyOwner {
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
    }
}

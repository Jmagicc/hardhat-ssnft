// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";



interface MyAuxiliary{
    function mintAux(address to_, uint256[] memory boxIDs_,uint256[] memory nums_,uint256 tokenId_,address bloomContract) external;  //拆        得到1个单主图和n个配件
    function fusionPrecondition(address to_,uint[] memory tokenIdArr_,uint256[] memory nums_,uint256 tokenId_)  external;            //融合前提   至少需要1个单主图和1个配件
    function balanceOf(address account,uint256 boxId) view  external returns (uint256); // 判断这个盲盒是否属于地址
}


contract Fusion is ERC721Enumerable, Ownable,Pausable {
    using Strings for uint256;

    // Constants
    uint256 private fusion_start_index = 8870;    // 融合图片的tokenId 从编号8870起
    uint256 public mintPrice =  0.003 ether;
    mapping(address => uint) public mintedNFTs;            // 判断某个地址拥有的nft数量

    string baseURI;
    string public baseExtension = ".json";

    mapping(uint256 => string) private _tokenURIs;
    bool internal locked;
    modifier noReentrant(){
        require(!locked,"No re-entrancy");
        locked=true;
        _;
        locked=false;
    }

    constructor()
         ERC721("bloom", "BLM")
    {
    }

    function bili22() public {
        _mintFusion();
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

    //v2 融合
    function fusionToMint(address auxiliaryContract,uint[] memory tokenIdArr_,uint256[] memory nums_,string memory cidg_) public whenNotPaused noReentrant  returns (bool){
        //TODO 收取一定的融合费用(配件合约已收取）
        //  require(mintPrice * amount == msg.value, "Wrong et+hers value");
        //加一个互斥锁先进行完融合前提后，在mint融合图
        //融合前提：先回收配件，必须有一个单人物图  [150001,100000,200000,250000,300000]

        //tokenid编号为8869后续的    都视为融合图片 
        uint256 tokenId_= fusion_start_index+1;
        require(!_exists(tokenId_), "ERC721A: token already minted");
        MyAuxiliary(auxiliaryContract).fusionPrecondition(_msgSender(),tokenIdArr_,nums_,tokenId_);
        mintedNFTs[_msgSender()] += 1;
        _mintFusion();
        _tokenURIs[tokenId_]=string(abi.encodePacked(cidg_, tokenId_.toString()));

        return true;
    }


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
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return _tokenURI;
        }
    
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
     
        return
            string(abi.encodePacked(base, tokenId.toString(), baseExtension));
    }


    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
    function _mintFusion() internal noReentrant {
        _safeMint(msg.sender,  fusion_start_index);
        fusion_start_index++;
    
    }

    //only owner
    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }


    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }


    function withdraw(address to) public onlyOwner {
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
    }
}

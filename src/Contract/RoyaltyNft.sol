// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTWithRoyalties is ERC721, ERC721URIStorage, ERC2981, Ownable, ReentrancyGuard {
    uint256 private _nextTokenId;

    struct NFTInfo {
        address minter;
        uint96 royaltyFee;
        string name;
        string symbol;
        uint256 age;
        string assetType;
        bool hasUnlockable;
        string unlockableContent;
        uint256 revenue;
        uint256 netProfit;
        uint256 totalRoyaltiesEarned;
    }

    mapping(uint256 => NFTInfo) private _nftInfo;

    event NFTMinted(uint256 indexed tokenId, address indexed minter, string name, string symbol, uint256 age, string assetType, uint96 royaltyFee);
    event RevenueUpdated(uint256 indexed tokenId, uint256 newRevenue, uint256 newNetProfit);
    event RoyaltyPaid(uint256 indexed tokenId, address indexed recipient, uint256 amount);

    constructor(string memory name, string memory symbol, address initialOwner) ERC721(name, symbol) Ownable(initialOwner) {}

    function mint(
        string memory name,
        string memory symbol,
        uint256 age,
        string memory assetType,
        string memory uri,
        bool hasUnlockable,
        string memory unlockableContent,
        uint96 royaltyFee
    ) public nonReentrant returns (uint256) {
        require(royaltyFee <= 1000, "Royalty fee cannot exceed 10%");
        require(bytes(name).length > 0, "Name required");
        require(bytes(symbol).length > 0, "Symbol required");

        uint256 tokenId = _nextTokenId++;
        
        _nftInfo[tokenId] = NFTInfo({
            minter: msg.sender,
            royaltyFee: royaltyFee,
            name: name,
            symbol: symbol,
            age: age,
            assetType: assetType,
            hasUnlockable: hasUnlockable,
            unlockableContent: hasUnlockable ? unlockableContent : "",
            revenue: 0,
            netProfit: 0,
            totalRoyaltiesEarned: 0
        });

        _setTokenRoyalty(tokenId, msg.sender, royaltyFee);
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);

        emit NFTMinted(tokenId, msg.sender, name, symbol, age, assetType, royaltyFee);
        return tokenId;
    }
    function burn(uint256 tokenId) public nonReentrant {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Caller is not token owner or approved");
        
        // First burn the token using ERC721URIStorage's implementation
        super._burn(tokenId);
        
        // Then delete the additional info
        delete _nftInfo[tokenId];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || 
                getApproved(tokenId) == spender || 
                isApprovedForAll(owner, spender));
    }

    function updateRevenue(uint256 tokenId, uint256 newRevenue) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(msg.sender == _nftInfo[tokenId].minter, "Only minter can update revenue");

        NFTInfo storage nft = _nftInfo[tokenId];
        uint256 oldRevenue = nft.revenue;
        nft.revenue = newRevenue;

        if (newRevenue > oldRevenue) {
            uint256 revenueIncrease = newRevenue - oldRevenue;
            uint256 royaltyAmount = (revenueIncrease * nft.royaltyFee) / 10000;
            nft.totalRoyaltiesEarned += royaltyAmount;
            nft.netProfit = newRevenue - nft.totalRoyaltiesEarned;
            emit RoyaltyPaid(tokenId, nft.minter, royaltyAmount);
        }

        emit RevenueUpdated(tokenId, newRevenue, nft.netProfit);
    }

    function getNFTDetails(uint256 tokenId) external view returns (
        string memory name,
        string memory symbol,
        uint256 age,
        string memory assetType,
        address minter,
        uint96 royaltyFee,
        uint256 revenue,
        uint256 netProfit,
        bool hasUnlockable
    ) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        NFTInfo storage nft = _nftInfo[tokenId];
        return (nft.name, nft.symbol, nft.age, nft.assetType, nft.minter, nft.royaltyFee, nft.revenue, nft.netProfit, nft.hasUnlockable);
    }

    function getUnlockableContent(uint256 tokenId) external view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(_nftInfo[tokenId].hasUnlockable, "No unlockable content");
        return _nftInfo[tokenId].unlockableContent;
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override(ERC721) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal virtual override(ERC721) {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

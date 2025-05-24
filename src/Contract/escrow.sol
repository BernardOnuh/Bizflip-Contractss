// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title NFTEscrow
 * @dev Contract to handle escrow transactions for NFTs
 */
contract NFTEscrow is Ownable {
    struct EscrowData {
        address seller;
        address buyer;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isComplete;
    }
    
    mapping(uint256 => EscrowData) public escrows;
    uint256 private escrowCount;
    uint256 private accumulatedFee;
    uint256 public marketplaceFee;
    address public marketplaceContract;
        
    event EscrowCreated(uint256 escrowId, address seller, address buyer, uint256 price);
    event EscrowComplete(uint256 escrowId);
    event EscrowCanceled(uint256 escrowId);
    event MarketplaceContractUpdated(address previousMarketplace, address newMarketplace);
    
    modifier onlyMarketplace() {
        require(msg.sender == marketplaceContract, "Only marketplace can call");
        _;
    }
    
    /**
     * @dev Constructor to initialize the contract
     * @param initialOwner The address of the initial owner
     * @param _marketplaceFee The initial marketplace fee (in basis points)
     */
    constructor(address initialOwner, uint256 _marketplaceFee) Ownable(initialOwner) {
        escrowCount = 0;
        accumulatedFee = 0;
        marketplaceFee = _marketplaceFee;
    }
    
    /**
     * @dev Sets the marketplace contract address that is allowed to call escrow functions
     * @param _marketplaceContract Address of the marketplace contract
     */
    function setMarketplaceContract(address _marketplaceContract) external onlyOwner {
        require(_marketplaceContract != address(0), "Invalid marketplace address");
        address oldMarketplace = marketplaceContract;
        marketplaceContract = _marketplaceContract;
        emit MarketplaceContractUpdated(oldMarketplace, _marketplaceContract);
    }
    
    /**
     * @dev Updates the marketplace fee percentage
     * @param _marketplaceFee New fee percentage (in basis points)
     */
    function updateMarketplaceFee(uint256 _marketplaceFee) external onlyOwner {
        marketplaceFee = _marketplaceFee;
    }
    
    /**
     * @dev Creates a new escrow transaction
     * @param seller Address of the NFT seller
     * @param nftContract Address of the NFT contract
     * @param tokenId ID of the token being escrowed
     * @return escrowId ID of the created escrow
     */
    function createEscrow(
        address seller,
        address nftContract,
        uint256 tokenId
    ) external payable onlyMarketplace returns (uint256) {
        require(msg.value > 0, "Price must be greater than 0");
        require(seller != address(0), "Invalid seller address");
        require(nftContract != address(0), "Invalid NFT contract address");
        
        uint256 escrowId = escrowCount++;
        escrows[escrowId] = EscrowData({
            seller: seller,
            buyer: tx.origin, // Use tx.origin since msg.sender is the marketplace
            nftContract: nftContract,
            tokenId: tokenId,
            price: msg.value,
            isComplete: false
        });
        
        emit EscrowCreated(escrowId, seller, tx.origin, msg.value);
        return escrowId;
    }
    
    /**
     * @dev Completes an escrow transaction by releasing funds to seller
     * @param escrowId ID of the escrow to complete
     */
    function completeEscrow(uint256 escrowId) external onlyMarketplace {
        EscrowData storage escrow = escrows[escrowId];
        require(!escrow.isComplete, "Escrow already complete");
        
        escrow.isComplete = true;
        
        uint256 fee = (escrow.price * marketplaceFee) / 10000;
        uint256 sellerAmount = escrow.price - fee;
        
        accumulatedFee += fee;
        
        // Transfer funds to seller
        (bool success, ) = payable(escrow.seller).call{value: sellerAmount}("");
        require(success, "Transfer to seller failed");
        
        // No need to transfer NFT here as the marketplace will handle it
        
        emit EscrowComplete(escrowId);
    }
    
    /**
     * @dev Cancels an escrow transaction and returns funds to buyer
     * @param escrowId ID of the escrow to cancel
     */
    function cancelEscrow(uint256 escrowId) external onlyMarketplace {
        EscrowData storage escrow = escrows[escrowId];
        require(!escrow.isComplete, "Escrow already complete");
        
        escrow.isComplete = true;
        
        // Return funds to buyer
        (bool success, ) = payable(escrow.buyer).call{value: escrow.price}("");
        require(success, "Transfer to buyer failed");
        
        emit EscrowCanceled(escrowId);
    }
    
    /**
     * @dev Allows the owner to claim accumulated fees
     */
    function claimFee() external onlyOwner {
        uint256 feeAmount = accumulatedFee;
        accumulatedFee = 0;
        (bool success, ) = payable(owner()).call{value: feeAmount}("");
        require(success, "Transfer to owner failed");
    }
}
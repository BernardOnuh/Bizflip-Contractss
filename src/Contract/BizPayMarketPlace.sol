// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import OpenZeppelin upgradeable contracts for security and functionality
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {NFTEscrow} from "./escrow.sol";

/**
 * @title INFTWithRoyalties
 * @dev Interface for NFT contract with minting and burning capabilities
 * that supports royalty functionalities
 */
interface INFTWithRoyalties {
    /**
     * @dev Mints a new NFT with specified parameters
     * @param name Name of the NFT
     * @param symbol Symbol of the NFT
     * @param age Age metadata for the NFT
     * @param assetType Type of asset the NFT represents
     * @param uri Metadata URI for the NFT
     * @param hasUnlockable Whether NFT has unlockable content
     * @param unlockableContent Content that can be unlocked by the owner
     * @param royaltyFee Fee percentage for royalties
     * @return uint256 The ID of the newly minted token
     */
    function mint(
        string memory name,
        string memory symbol,
        uint256 age,
        string memory assetType,
        string memory uri,
        bool hasUnlockable,
        string memory unlockableContent,
        uint96 royaltyFee
    ) external returns (uint256);

    /**
     * @dev Burns (destroys) an NFT with the specified token ID
     * @param tokenId ID of the token to burn
     */
    function burn(uint256 tokenId) external;

}

/**
 * @title NFTMarketplaceV1
 * @dev A marketplace for NFTs supporting listing, offers, escrow, and investment functionalities
 * Uses upgradeable pattern to allow for future improvements
 */
contract NFTMarketplaceV1 is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    /**
     * @dev Structure to keep record of listed NFTs
     * @param seller Address of the NFT seller
     * @param price Listed price of the NFT
     * @param isActive Whether the listing is currently active
     */
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
        string tokenURI;
    }

    /**
     * @dev Structure to keep record of offers made on NFTs
     * @param buyer Address of the potential buyer
     * @param price Offered price
     * @param expirationTime Time when the offer expires
     * @param isEscrow Whether the offer uses escrow
     * @param isActive Whether the offer is currently active
     * @param escrowId ID of the escrow if using escrow
     */
    struct Offer {
        address buyer;
        uint256 price;
        uint256 expirationTime;
        bool isEscrow;
        bool isActive;
        uint256 escrowId;
    }

    /**
     * @dev Structure to keep record of investments in NFTs
     * @param investor Address of the investor
     * @param amount Amount invested
     * @param sharePercentage Percentage of ownership claimed
     * @param timestamp Time when the investment was made
     */
    struct Investment {
        address investor;
        uint256 amount;
        uint256 sharePercentage;
        uint256 timestamp;
    }

    // Mapping of NFT contract address => token ID => listing details
    mapping(address => mapping(uint256 => Listing)) public listings;

    // Mapping of NFT contract address => token ID => array of offers
    mapping(address => mapping(uint256 => Offer[])) public offers;

    // Mapping of NFT contract address => token ID => array of investments
    mapping(address => mapping(uint256 => Investment[])) public investments;

    // Mapping of user address => balance deposited in the contract
    mapping(address => uint256) public userBalance;

    // Fee percentage charged by the marketplace (in basis points, e.g., 250 = 2.5%)
    uint256 public marketplaceFee;

    // Address of the NFT contract used by this marketplace
    address public _nftContract;

    // Address of the escrow contract used for secure transactions
    address public escrowContract;

    // Total amount of minted Asset
    uint256 public TotalNftMinted;

    // Events for tracking marketplace activities
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address seller, uint256 price);
    event NFTDelisted(address indexed nftContract, uint256 indexed tokenId, address seller);
    event OfferPlaced(
        address indexed nftContract, uint256 indexed tokenId, address buyer, uint256 price, bool isEscrow
    );
    event OfferAccepted(address indexed nftContract, uint256 indexed tokenId, address buyer, uint256 price);
    event OfferRejected(address indexed nftContract, uint256 indexed tokenId, address buyer, uint256 price);
    event OfferWithdrawn(address indexed nftContract, uint256 indexed tokenId, uint256 offerIndex);
    event InvestmentMade(
        address indexed nftContract, uint256 indexed tokenId, address investor, uint256 amount, uint256 sharePercentage
    );

    /**
     * @dev Initializes the marketplace contract (replaces constructor for upgradeable contracts)
     * @param __nftContract Address of the NFT contract
     * @param _escrowContract Address of the escrow contract
     * @param _marketplaceFee Fee percentage for the marketplace (in basis points)
     */
    function initialize(address __nftContract, address _escrowContract, uint256 _marketplaceFee) public initializer {
        // Initialize inherited contracts
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init(msg.sender);

        // Validate input parameters
        require(__nftContract != address(0), "Invalid NFT contract");
        require(_escrowContract != address(0), "Invalid escrow contract");
        require(IERC721(__nftContract).supportsInterface(type(IERC721).interfaceId), "Not ERC-721");

        // Set contract parameters
        _nftContract = __nftContract;
        escrowContract = _escrowContract;
        marketplaceFee = _marketplaceFee;
    }



    /**
     * @dev Lists an NFT for sale
     * @param tokenId ID of the token to list
     * @param price Price at which to list the NFT
     */
    function listNFT(uint256 tokenId, uint256 price) external nonReentrant whenNotPaused {
        // Verify caller owns the NFT
        require(IERC721(_nftContract).ownerOf(tokenId) == msg.sender, "Not owner of NFT");
        require(price > 0, "Price must be greater than zero");

        // Create listing record
        listings[_nftContract][tokenId] = Listing({seller: msg.sender, price: price, isActive: true, tokenURI: getTokenURI(tokenId) });
        IERC721(_nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        // Increment the totalsupply
        TotalNftMinted += 1;

        // Emit listing event
        emit NFTListed(_nftContract, tokenId, msg.sender, price);
    }

    /**
     * @dev Removes an NFT listing from the marketplace
     * @param tokenId ID of the token to delist
     */
    function delistNFT(uint256 tokenId) public nonReentrant {
        // Get the listing and verify ownership and status
        Listing storage listing = listings[_nftContract][tokenId];
        require(listing.seller == msg.sender, "Not the seller");
        require(listing.isActive, "Not listed");

        // Deactivate the listing
        listing.isActive = false;
        IERC721(_nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        

        // Emit delisting event
        emit NFTDelisted(_nftContract, tokenId, msg.sender);
    }

    /**
     * @dev Mints a new NFT and immediately lists it for sale
     * @param name Name of the NFT
     * @param symbol Symbol of the NFT
     * @param age Age metadata for the NFT
     * @param assetType Type of asset the NFT represents
     * @param uri Metadata URI for the NFT
     * @param hasUnlockable Whether NFT has unlockable content
     * @param unlockableContent Content that can be unlocked by the owner
     * @param royaltyFee Fee percentage for royalties
     * @param listingPrice Price at which to list the NFT
     * @return uint256 The ID of the newly minted token
     */
    function mintAndList(
        string memory name,
        string memory symbol,
        uint256 age,
        string memory assetType,
        string memory uri,
        bool hasUnlockable,
        string memory unlockableContent,
        uint96 royaltyFee,
        uint256 listingPrice
    ) external nonReentrant whenNotPaused returns (uint256) {
        // Mint the NFT
        uint256 tokenId = INFTWithRoyalties(_nftContract).mint(
            name, symbol, age, assetType, uri, hasUnlockable, unlockableContent, royaltyFee
        );
        
        // List the newly minted NFT
        listings[_nftContract][tokenId] = Listing({seller: msg.sender, price: listingPrice, isActive: true, tokenURI: getTokenURI(tokenId)});

        TotalNftMinted += 1;


        // Emit listing event
        emit NFTListed(_nftContract, tokenId, msg.sender, listingPrice);
        return tokenId;
    }

    /**
     * @dev Makes an offer on a listed NFT
     * @param tokenId ID of the token to make an offer on
     * @param expirationTime Time when the offer expires
     * @param isEscrow Whether to use escrow for the transaction
     */
    function makeOffer(uint256 tokenId, uint256 expirationTime, bool isEscrow)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        // Verify the NFT is listed and offer parameters are valid
        Listing storage listing = listings[_nftContract][tokenId];
        require(listing.isActive, "Not listed");
        require(msg.value > 0, "Invalid price");
        require(expirationTime > block.timestamp, "Invalid expiration");

        uint256 escrowId = 0;
        if (isEscrow) {
            // Create escrow and forward the ETH to the escrow contract
            escrowId = NFTEscrow(escrowContract).createEscrow{value: msg.value}(listing.seller, _nftContract, tokenId);
        }

        // Add the offer to the offers array
        offers[_nftContract][tokenId].push(
            Offer({
                buyer: msg.sender,
                price: msg.value,
                expirationTime: expirationTime,
                isEscrow: isEscrow,
                isActive: true,
                escrowId: escrowId
            })
        );

        // Emit offer event
        emit OfferPlaced(_nftContract, tokenId, msg.sender, msg.value, isEscrow);
    }

   
    /**
     * @dev Accepts an offer for a listed NFT
     * @param tokenId ID of the token with the offer
     * @param offerIndex Index of the offer to accept
     */
    function acceptOffer(uint256 tokenId, uint256 offerIndex) external nonReentrant whenNotPaused {
        // Verify listing and seller
        Listing storage listing = listings[_nftContract][tokenId];
        require(msg.sender == listing.seller, "Not seller");
        require(listing.isActive, "Not listed");

        // Verify offer is active and not expired
        Offer storage offer = offers[_nftContract][tokenId][offerIndex];
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expirationTime, "Offer expired");

        // Update listing and offer status
        listing.isActive = false;
        offer.isActive = false;

        if (offer.isEscrow) {
            // Handle escrow transaction
            // Transfer NFT to buyer first
            IERC721(_nftContract).transferFrom(listing.seller, offer.buyer, tokenId);

            // Then complete the escrow to release funds
            NFTEscrow(escrowContract).completeEscrow(offer.escrowId);
        } else {
            // Handle direct sale
            // Calculate marketplace fee
            uint256 fee = (offer.price * marketplaceFee) / 10000;
            uint256 sellerAmount = offer.price - fee;

            // Transfer funds to seller
            (bool success1,) = payable(listing.seller).call{value: sellerAmount}("");
            require(success1, "Transfer to seller failed");

            // Transfer fee to marketplace owner
            (bool success2,) = payable(owner()).call{value: fee}("");
            require(success2, "Transfer to owner failed");

            // Transfer NFT to buyer
            IERC721(_nftContract).transferFrom(listing.seller, offer.buyer, tokenId);
        }

        // Emit offer accepted event
        emit OfferAccepted(_nftContract, tokenId, offer.buyer, offer.price);
    }

    /**
     * @dev Rejects an offer for a listed NFT
     * @param tokenId ID of the token with the offer
     * @param offerIndex Index of the offer to reject
     */
    function rejectOffer(uint256 tokenId, uint256 offerIndex) external nonReentrant whenNotPaused {
        // Verify seller
        Listing storage listing = listings[_nftContract][tokenId];
        require(msg.sender == listing.seller, "Not seller");

        // Verify offer is active and not expired
        Offer storage offer = offers[_nftContract][tokenId][offerIndex];
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expirationTime, "Offer expired");

        // Update offer status
        offer.isActive = false;

        if (offer.isEscrow) {
            // Cancel the escrow transaction
            NFTEscrow(escrowContract).cancelEscrow(offer.escrowId);
        } else {
            // Refund the buyer
            (bool success,) = payable(offer.buyer).call{value: offer.price}("");
            require(success, "Transfer to buyer failed");
        }

        // Emit offer rejected event
        emit OfferRejected(_nftContract, tokenId, offer.buyer, offer.price);
    }

    /**
     * @dev Allows a buyer to withdraw their offer
     * @param tokenId ID of the token with the offer
     * @param offerIndex Index of the offer to withdraw
     */
    function withdrawOffer(uint256 tokenId, uint256 offerIndex) external nonReentrant {
        // Verify offer maker and offer status
        Offer storage offer = offers[_nftContract][tokenId][offerIndex];
        require(offer.buyer == msg.sender, "Not offer maker");
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expirationTime, "Offer expired");

        // Update offer status
        offer.isActive = false;

        if (offer.isEscrow) {
            // Cancel the escrow
            NFTEscrow(escrowContract).cancelEscrow(offer.escrowId);
        } else {
            // Refund the offer amount
            (bool success,) = payable(msg.sender).call{value: offer.price}("");
            require(success, "Transfer failed");
        }

        // Emit offer withdrawn event
        emit OfferWithdrawn(_nftContract, tokenId, offerIndex);
    }

    /**
     * @dev Allows users to invest in an NFT
     * @param tokenId ID of the token to invest in
     * @param sharePercentage Percentage of ownership claimed
     */
    function invest(uint256 tokenId, uint256 sharePercentage) external payable nonReentrant whenNotPaused {
        // Verify NFT is listed and investment parameters
        require(listings[_nftContract][tokenId].isActive, "Not listed");
        require(sharePercentage <= 100, "Invalid share percentage");
        require(msg.value > 0, "Invalid investment amount");

        // Record the investment
        investments[_nftContract][tokenId].push(
            Investment({
                investor: msg.sender,
                amount: msg.value,
                sharePercentage: sharePercentage,
                timestamp: block.timestamp
            })
        );

        // Emit investment event
        emit InvestmentMade(_nftContract, tokenId, msg.sender, msg.value, sharePercentage);
    }

    /**
     * @dev Updates the marketplace fee percentage
     * @param _marketplaceFee New fee percentage (in basis points)
     */
    function updateMarketplaceFee(uint256 _marketplaceFee) external onlyOwner {
        marketplaceFee = _marketplaceFee;
    }

    function getTokenURI( uint256 tokenId) internal view returns (string memory) {
        IERC721Metadata nft = IERC721Metadata(_nftContract);
        return nft.tokenURI(tokenId);
    }

    /**
     * @dev Pauses the contract (emergency stop)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Implementation of IERC721Receiver interface
     * Required for the marketplace to receive NFTs
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

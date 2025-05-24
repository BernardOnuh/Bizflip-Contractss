## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
# NFT Marketplace Smart Contract System

## Overview

This project implements a comprehensive NFT marketplace on Ethereum using Solidity ^0.8.20.  
The system consists of three core smart contracts that together provide a secure, feature-rich NFT trading platform with escrow and royalty support.

---

## System Architecture

### Core Contracts

| Contract            | Description                                                  |
|---------------------|--------------------------------------------------------------|
| `NFTMarketplaceV1`  | Main marketplace contract for listing, trading, and investing in NFTs |
| `NFTEscrow`        | Secure escrow service for protected transactions             |
| `NFTWithRoyalties` | ERC721 NFT contract with built-in royalty mechanisms         |

### Key Features

- ✅ Upgradeable design using OpenZeppelin upgradeable pattern  
- ✅ Escrow protection for secure NFT transactions  
- ✅ Built-in creator royalties (ERC2981 standard)  
- ✅ Fractional investment mechanism for NFTs  
- ✅ Offer system to make and manage offers  
- ✅ Emergency pause controls (Pausable)  
- ✅ Reentrancy protection for security  

---

## Contract Details

### 1. NFTMarketplaceV1

Main marketplace contract managing all trading operations.

#### Core Data Structures

solidity
struct Listing {
    address seller;
    uint256 price;
    bool isActive;
    string tokenURI;
}

struct Offer {
    address buyer;
    uint256 price;
    uint256 expirationTime;
    bool isEscrow;
    bool isActive;
    uint256 escrowId;
}

struct Investment {
    address investor;
    uint256 amount;
    uint256 sharePercentage;
    uint256 timestamp;
}

Key Functions
Listing Management
```listNFT(uint256 tokenId, uint256 price)```

Lists an NFT for sale at specified price

Transfers NFT to marketplace contract for custody

Emits NFTListed event

```delistNFT(uint256 tokenId)```

Removes NFT from marketplace

Returns NFT to original owner

Only callable by the seller

```mintAndList(...)```

Mints new NFT and immediately lists it

One-step process for creators

Returns the new token ID

Offer System
```makeOffer(uint256 tokenId, uint256 expirationTime, bool isEscrow)````

Make an offer on a listed NFT

Can use escrow for additional security

Requires ETH payment with the transaction

```acceptOffer(uint256 tokenId, uint256 offerIndex)```

Accept a specific offer

Handles fund distribution and NFT transfer

Only callable by the NFT seller

```rejectOffer(uint256 tokenId, uint256 offerIndex)```

Reject an offer and refund buyer

Only callable by the NFT seller

```withdrawOffer(uint256 tokenId, uint256 offerIndex)```

Allows buyers to withdraw their offers

Refunds the offer amount

Investment Features
```invest(uint256 tokenId, uint256 sharePercentage)```

Invest in an NFT for fractional ownership

Records investment details

Emits InvestmentMade event

Security Features
ReentrancyGuard - Prevents reentrancy attacks

Pausable - Emergency stop functionality

Ownable - Admin controls for critical functions

Upgradeable - Future improvement capability

2. NFTEscrow
Secure escrow service for protected NFT transactions.

Core Structure
solidity
```
struct EscrowData {
    address seller;        // NFT seller
    address buyer;         // NFT buyer
    address nftContract;   // NFT contract address
    uint256 tokenId;       // Token ID
    uint256 price;         // Transaction price
    bool isComplete;       // Completion status
}
Key Functions
createEscrow(address seller, address nftContract, uint256 tokenId)
```

Creates new escrow transaction

Holds buyer's funds securely

Returns unique escrow ID

completeEscrow(uint256 escrowId)

Releases funds to seller

Deducts marketplace fees

Only callable by marketplace contract

cancelEscrow(uint256 escrowId)

Cancels escrow and refunds buyer

Used when offers are rejected or withdrawn

claimFee()

Admin function to claim accumulated fees

Only callable by contract owner

3. NFTWithRoyalties
ERC721 NFT contract with built-in royalty system and metadata management.

Core Structure
solidity
```
struct NFTInfo {
    address minter;             // Original creator
    uint96 royaltyFee;          // Royalty percentage (basis points)
    string name;                // NFT name
    string symbol;              // NFT symbol
    uint256 age;                // Age metadata
    string assetType;           // Asset type category
    bool hasUnlockable;         // Unlockable content flag
    string unlockableContent;   // Private content for owner
    uint256 revenue;            // Total revenue generated
    uint256 netProfit;          // Net profit after royalties
    uint256 totalRoyaltiesEarned; // Cumulative royalties
}
```
Key Functions
mint(...)

Mints new NFT with comprehensive metadata

Sets up royalty information

Returns new token ID

burn(uint256 tokenId)

Burns NFT and cleans up metadata

Only callable by owner or approved address

updateRevenue(uint256 tokenId, uint256 newRevenue)

Updates revenue tracking for NFT

Calculates and tracks royalty payments

Only callable by original minter

getNFTDetails(uint256 tokenId)

Returns comprehensive NFT information

Public view function

getUnlockableContent(uint256 tokenId)

Returns private content to NFT owner

Access control enforced

Integration Guide
Deployment Sequence
solidity

// 1. Deploy NFTWithRoyalties
NFTWithRoyalties nft = new NFTWithRoyalties(
    "My NFT Collection",
    "MNC",
    owner
);

// 2. Deploy NFTEscrow
NFTEscrow escrow = new NFTEscrow(
    owner,
    250  // 2.5% marketplace fee
);

// 3. Deploy NFTMarketplaceV1 (proxy)
NFTMarketplaceV1 marketplace = new NFTMarketplaceV1();
marketplace.initialize(
    address(nft),
    address(escrow),
    250  // 2.5% marketplace fee
);

// 4. Configure Escrow
escrow.setMarketplaceContract(address(marketplace));

Frontend Integration

Web3 Setup
javascript

// Contract instances
const marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, signer);
const nft = new ethers.Contract(nftAddress, nftABI, signer);
const escrow = new ethers.Contract(escrowAddress, escrowABI, signer);
Common Operations
Mint and List NFT

javascript

const tx = await marketplace.mintAndList(
    "NFT Name",
    "SYMBOL",
    25,  // age
    "Art",  // assetType
    "ipfs://...",  // metadata URI
    true,  // hasUnlockable
    "Secret content",  // unlockableContent
    500,  // 5% royalty (basis points)
    ethers.utils.parseEther("1.0")  // listing price
);
Make Offer with Escrow

javascript

const expirationTime = Math.floor(Date.now() / 1000) + 86400; // 24 hours
const tx = await marketplace.makeOffer(
    tokenId,
    expirationTime,
    true,  // use escrow
    { value: ethers.utils.parseEther("0.8") }
);
Accept Offer

javascript

const tx = await marketplace.acceptOffer(tokenId, offerIndex);
Events Reference
NFTMarketplaceV1 Events
solidity

event NFTListed(address indexed nftContract, uint256 indexed tokenId, address seller, uint256 price);
event NFTDelisted(address indexed nftContract, uint256 indexed tokenId, address seller);
event OfferPlaced(address indexed nftContract, uint256 indexed tokenId, address buyer, uint256 price, bool isEscrow);
event OfferAccepted(address indexed nftContract, uint256 indexed tokenId, address buyer, uint256 price);
event OfferRejected(address indexed nftContract, uint256 indexed tokenId, address buyer, uint256 price);
event OfferWithdrawn(address indexed nftContract, uint256 indexed tokenId, uint256 offerIndex);
event InvestmentMade(address indexed nftContract, uint256 indexed tokenId, address investor, uint256 amount, uint256 sharePercentage);
NFTEscrow Events
solidity

event EscrowCreated(uint256 escrowId, address seller, address buyer, uint256 price);
event EscrowComplete(uint256 escrowId);
event EscrowCanceled(uint256 escrowId);
event MarketplaceContractUpdated(address previousMarketplace, address newMarketplace);
NFTWithRoyalties Events
solidity

event NFTMinted(uint256 indexed tokenId, address indexed minter, string name, string symbol, uint256 age, string assetType, uint96 royaltyFee);
event RevenueUpdated(uint256 indexed tokenId, uint256 newRevenue, uint256 newNetProfit);
event RoyaltyPaid(uint256 indexed tokenId, address indexed recipient, uint256 amount);

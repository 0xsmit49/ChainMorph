// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/FunctionsClient.sol";


// ================================
// 6. CROSS-CHAIN BRIDGE CONTRACT
// ================================
contract CrossChainBridge is AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    
    TraitFusion public traitFusion;
    EvolutionNFT public evolutionNFT;
    
    struct NFTSnapshot {
        uint256 level;
        uint256 energy;
        uint256 strength;
        uint256 stamina;
        string zone;
        string elementAffinity;
        string lootTier;
        bytes32 snapshotHash;
        uint256 timestamp;
    }
    
    mapping(uint256 => NFTSnapshot) public snapshots;
    
    event SnapshotCreated(uint256 indexed tokenId, bytes32 snapshotHash);
    event CrossChainTransferInitiated(uint256 indexed tokenId, address indexed to, string targetChain);

    constructor(address _traitFusion, address _evolutionNFT) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ROLE, msg.sender);
        
        traitFusion = TraitFusion(_traitFusion);
        evolutionNFT = EvolutionNFT(_evolutionNFT);
    }

    function createSnapshot(uint256 tokenId) external returns (bytes32) {
        require(evolutionNFT.ownerOf(tokenId) == msg.sender, "Not owner");
        
        // Capture current traits
        NFTSnapshot memory snapshot = NFTSnapshot({
            level: traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "level"),
            energy: traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "energy"),
            strength: traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "strength"),
            stamina: traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "stamina"),
            zone: traitFusion.getTraitAsString(address(evolutionNFT), tokenId, "zone"),
            elementAffinity: traitFusion.getTraitAsString(address(evolutionNFT), tokenId, "element_affinity"),
            lootTier: traitFusion.getTraitAsString(address(evolutionNFT), tokenId, "loot_tier"),
            snapshotHash: bytes32(0),
            timestamp: block.timestamp
        });
        
        // Create hash of all traits
        bytes32 hash = keccak256(abi.encode(
            snapshot.level,
            snapshot.energy,
            snapshot.strength,
            snapshot.stamina,
            snapshot.zone,
            snapshot.elementAffinity,
            snapshot.lootTier,
            snapshot.timestamp
        ));
        
        snapshot.snapshotHash = hash;
        snapshots[tokenId] = snapshot;
        
        emit SnapshotCreated(tokenId, hash);
        return hash;
    }

    function initiateCrossChainTransfer(uint256 tokenId, address to, string calldata targetChain) 
        external 
        onlyRole(BRIDGE_ROLE) 
    {
        require(snapshots[tokenId].snapshotHash != bytes32(0), "Snapshot required");
        
        // In a real implementation, this would integrate with Avalanche Warp Messaging
        // to send the snapshot data to the target chain
        
        emit CrossChainTransferInitiated(tokenId, to, targetChain);
    }
}


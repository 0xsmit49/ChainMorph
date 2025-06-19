// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ================================
// 3. TRAIT FUSION IMPLEMENTATION
// ================================
contract TraitFusion is AccessControl {
    bytes32 public constant GAME_ENGINE_ROLE = keccak256("GAME_ENGINE_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // NFT contract => tokenId => traitKey => value
    mapping(address => mapping(uint256 => mapping(string => bytes))) private traits;
    
    // Events
    event TraitUpdated(address indexed nft, uint256 indexed tokenId, string traitKey, bytes value);
    event TraitSnapshot(address indexed nft, uint256 indexed tokenId, bytes32 snapshotHash);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_ENGINE_ROLE, msg.sender);
    }

    function setTrait(address nft, uint256 tokenId, string calldata traitKey, bytes calldata value) 
        external 
        onlyRole(GAME_ENGINE_ROLE) 
    {
        traits[nft][tokenId][traitKey] = value;
        emit TraitUpdated(nft, tokenId, traitKey, value);
    }

    function setTraitUint(address nft, uint256 tokenId, string calldata traitKey, uint256 value) 
        external 
        onlyRole(GAME_ENGINE_ROLE) 
    {
        traits[nft][tokenId][traitKey] = abi.encode(value);
        emit TraitUpdated(nft, tokenId, traitKey, abi.encode(value));
    }

    function setTraitString(address nft, uint256 tokenId, string calldata traitKey, string calldata value) 
        external 
        onlyRole(GAME_ENGINE_ROLE) 
    {
        traits[nft][tokenId][traitKey] = abi.encode(value);
        emit TraitUpdated(nft, tokenId, traitKey, abi.encode(value));
    }

    function getTrait(address nft, uint256 tokenId, string calldata traitKey) 
        external 
        view 
        returns (bytes memory) 
    {
        return traits[nft][tokenId][traitKey];
    }

    function getTraitAsUint(address nft, uint256 tokenId, string calldata traitKey) 
        external 
        view 
        returns (uint256) 
    {
        bytes memory data = traits[nft][tokenId][traitKey];
        if (data.length == 0) return 0;
        return abi.decode(data, (uint256));
    }

    function getTraitAsString(address nft, uint256 tokenId, string calldata traitKey) 
        external 
        view 
        returns (string memory) 
    {
        bytes memory data = traits[nft][tokenId][traitKey];
        if (data.length == 0) return "";
        return abi.decode(data, (string));
    }

    // Create snapshot for cross-chain transfer
    function createSnapshot(address nft, uint256 tokenId, string[] calldata traitKeys) 
        external 
        view 
        returns (bytes32) 
    {
        bytes memory snapshot = "";
        for (uint i = 0; i < traitKeys.length; i++) {
            snapshot = abi.encodePacked(snapshot, traits[nft][tokenId][traitKeys[i]]);
        }
        return keccak256(snapshot);
    }
}

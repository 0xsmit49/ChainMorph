pragma solidity ^0.8.19;
// ================================
// 4. EVOLUTION NFT CONTRACT
// ================================
contract EvolutionNFT is ERC721, AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    bytes32 public constant GAME_ENGINE_ROLE = keccak256("GAME_ENGINE_ROLE");
    
    Counters.Counter private _tokenIds;
    TraitFusion public traitFusion;
    
    // Base traits for new NFTs
    struct BaseTraits {
        uint256 level;
        uint256 energy;
        uint256 strength;
        uint256 stamina;
        string zone;
        string elementAffinity;
    }

    mapping(uint256 => BaseTraits) public baseTraits;
    
    event NFTMinted(address indexed to, uint256 indexed tokenId);
    event NFTEvolved(uint256 indexed tokenId, string traitKey, uint256 newValue);

    constructor(address _traitFusion) ERC721("Evolution NFT", "EVNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_ENGINE_ROLE, msg.sender);
        traitFusion = TraitFusion(_traitFusion);
    }

    function mint(address to) external onlyRole(GAME_ENGINE_ROLE) returns (uint256) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        
        _mint(to, tokenId);
        
        // Initialize base traits
        BaseTraits memory base = BaseTraits({
            level: 1,
            energy: 100,
            strength: 10,
            stamina: 50,
            zone: "starter_zone",
            elementAffinity: "neutral"
        });
        
        baseTraits[tokenId] = base;
        
        // Set initial traits in TraitFusion
        traitFusion.setTraitUint(address(this), tokenId, "level", base.level);
        traitFusion.setTraitUint(address(this), tokenId, "energy", base.energy);
        traitFusion.setTraitUint(address(this), tokenId, "strength", base.strength);
        traitFusion.setTraitUint(address(this), tokenId, "stamina", base.stamina);
        traitFusion.setTraitString(address(this), tokenId, "zone", base.zone);
        traitFusion.setTraitString(address(this), tokenId, "element_affinity", base.elementAffinity);
        
        emit NFTMinted(to, tokenId);
        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        // Get current traits from TraitFusion
        uint256 level = traitFusion.getTraitAsUint(address(this), tokenId, "level");
        uint256 energy = traitFusion.getTraitAsUint(address(this), tokenId, "energy");
        string memory zone = traitFusion.getTraitAsString(address(this), tokenId, "zone");
        
        // Return dynamic metadata based on current traits
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(abi.encodePacked(
                '{"name":"Evolution NFT #', _toString(tokenId), '",',
                '"description":"A living NFT that evolves based on gameplay and real-world actions",',
                '"attributes":[',
                '{"trait_type":"Level","value":', _toString(level), '},',
                '{"trait_type":"Energy","value":', _toString(energy), '},',
                '{"trait_type":"Zone","value":"', zone, '"}',
                ']}'
            )))
        ));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Helper functions
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        // Simple base64 encoding - in production use a library
        return "placeholder_base64";
    }
}

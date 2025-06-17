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
// 1. GAME TOKEN (ERC20)
// ================================
contract GameToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20("GameFi Token", "GAME") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        // Genesis mint
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }
}

// ================================
// 2. TRAIT FUSION PRECOMPILE INTERFACE
// ================================
interface ITraitFusion {
    function setTrait(address nft, uint256 tokenId, string calldata traitKey, bytes calldata value) external;
    function getTrait(address nft, uint256 tokenId, string calldata traitKey) external view returns (bytes memory);
    function getTraitAsUint(address nft, uint256 tokenId, string calldata traitKey) external view returns (uint256);
    function getTraitAsString(address nft, uint256 tokenId, string calldata traitKey) external view returns (string memory);
}

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

// ================================
// 5. GAME ENGINE CONTRACT
// ================================
contract GameEngine is AccessControl, ReentrancyGuard, VRFConsumerBaseV2 {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    TraitFusion public traitFusion;
    EvolutionNFT public evolutionNFT;
    GameToken public gameToken;
    
    // Chainlink VRF
    VRFCoordinatorV2Interface public vrfCoordinator;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    
    mapping(uint256 => uint256) public vrfRequests; // requestId => tokenId
    
    // Game mechanics
    mapping(uint256 => uint256) public lastActionTime;
    mapping(uint256 => uint256) public dailySteps;
    mapping(uint256 => string) public currentQuest;
    
    // Events
    event PlayerAction(uint256 indexed tokenId, string action, uint256 reward);
    event QuestCompleted(uint256 indexed tokenId, string quest, uint256 reward);
    event RealWorldUpdate(uint256 indexed tokenId, string dataType, uint256 value);
    event LootBoxOpened(uint256 indexed tokenId, uint256 lootType);

    constructor(
        address _traitFusion,
        address _evolutionNFT,
        address _gameToken,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        
        traitFusion = TraitFusion(_traitFusion);
        evolutionNFT = EvolutionNFT(_evolutionNFT);
        gameToken = GameToken(_gameToken);
        
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    // ================================
    // GAME ACTIONS
    // ================================
    
    function fightEnemy(uint256 tokenId) external nonReentrant {
        require(evolutionNFT.ownerOf(tokenId) == msg.sender, "Not owner");
        require(block.timestamp >= lastActionTime[tokenId] + 1 hours, "Cooldown active");
        
        uint256 currentLevel = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "level");
        uint256 currentEnergy = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "energy");
        
        require(currentEnergy >= 20, "Not enough energy");
        
        // Consume energy
        traitFusion.setTraitUint(address(evolutionNFT), tokenId, "energy", currentEnergy - 20);
        
        // Gain XP and potentially level up
        uint256 xpGain = 10 + (currentLevel / 2);
        uint256 newLevel = currentLevel + (xpGain / 100);
        
        if (newLevel > currentLevel) {
            traitFusion.setTraitUint(address(evolutionNFT), tokenId, "level", newLevel);
            // Increase strength on level up
            uint256 currentStrength = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "strength");
            traitFusion.setTraitUint(address(evolutionNFT), tokenId, "strength", currentStrength + 5);
        }
        
        lastActionTime[tokenId] = block.timestamp;
        
        // Reward tokens
        gameToken.mint(msg.sender, 100 * 10**18);
        
        emit PlayerAction(tokenId, "fight_enemy", xpGain);
    }

    function usePotion(uint256 tokenId) external nonReentrant {
        require(evolutionNFT.ownerOf(tokenId) == msg.sender, "Not owner");
        require(gameToken.balanceOf(msg.sender) >= 50 * 10**18, "Not enough GAME tokens");
        
        gameToken.burn(msg.sender, 50 * 10**18);
        
        uint256 currentEnergy = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "energy");
        uint256 newEnergy = currentEnergy + 50;
        if (newEnergy > 200) newEnergy = 200; // Cap at 200
        
        traitFusion.setTraitUint(address(evolutionNFT), tokenId, "energy", newEnergy);
        
        emit PlayerAction(tokenId, "use_potion", 50);
    }

    function enterZone(uint256 tokenId, string calldata newZone) external {
        require(evolutionNFT.ownerOf(tokenId) == msg.sender, "Not owner");
        
        traitFusion.setTraitString(address(evolutionNFT), tokenId, "zone", newZone);
        
        // Zone-specific bonuses
        if (keccak256(bytes(newZone)) == keccak256(bytes("fire_caves"))) {
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "element_affinity", "fire");
        } else if (keccak256(bytes(newZone)) == keccak256(bytes("ice_mountains"))) {
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "element_affinity", "ice");
        }
        
        emit PlayerAction(tokenId, "enter_zone", 0);
    }

    // ================================
    // ORACLE INTEGRATION (Real-World Data)
    // ================================
    
    function updateSteps(uint256 tokenId, uint256 steps) external onlyRole(ORACLE_ROLE) {
        dailySteps[tokenId] = steps;
        
        // Convert steps to stamina (1 step = 0.01 stamina)
        uint256 currentStamina = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "stamina");
        uint256 staminaBonus = steps / 100;
        uint256 newStamina = currentStamina + staminaBonus;
        if (newStamina > 200) newStamina = 200; // Cap at 200
        
        traitFusion.setTraitUint(address(evolutionNFT), tokenId, "stamina", newStamina);
        
        // Milestone rewards
        if (steps >= 10000) {
            gameToken.mint(evolutionNFT.ownerOf(tokenId), 200 * 10**18);
            emit QuestCompleted(tokenId, "daily_10k_steps", 200);
        }
        
        emit RealWorldUpdate(tokenId, "steps", steps);
    }

    function updateGPSZone(uint256 tokenId, string calldata gpsZone) external onlyRole(ORACLE_ROLE) {
        // GPS-based zone bonuses
        string memory zoneBonus = "none";
        
        if (keccak256(bytes(gpsZone)) == keccak256(bytes("north"))) {
            zoneBonus = "cold_resistance";
        } else if (keccak256(bytes(gpsZone)) == keccak256(bytes("south"))) {
            zoneBonus = "heat_resistance";
        } else if (keccak256(bytes(gpsZone)) == keccak256(bytes("forest"))) {
            zoneBonus = "nature_affinity";
        }
        
        traitFusion.setTraitString(address(evolutionNFT), tokenId, "zone_bonus", zoneBonus);
        
        emit RealWorldUpdate(tokenId, "gps_zone", 0);
    }

    function updateWeather(uint256 tokenId, string calldata weather) external onlyRole(ORACLE_ROLE) {
        // Weather affects element affinity
        if (keccak256(bytes(weather)) == keccak256(bytes("rain"))) {
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "weather_affinity", "water");
        } else if (keccak256(bytes(weather)) == keccak256(bytes("sunny"))) {
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "weather_affinity", "fire");
        } else if (keccak256(bytes(weather)) == keccak256(bytes("snow"))) {
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "weather_affinity", "ice");
        }
        
        emit RealWorldUpdate(tokenId, "weather", 0);
    }

    // ================================
    // CHAINLINK VRF LOOT SYSTEM
    // ================================
    
    function openLootBox(uint256 tokenId) external nonReentrant {
        require(evolutionNFT.ownerOf(tokenId) == msg.sender, "Not owner");
        require(gameToken.balanceOf(msg.sender) >= 100 * 10**18, "Not enough GAME tokens");
        
        gameToken.burn(msg.sender, 100 * 10**18);
        
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );
        
        vrfRequests[requestId] = tokenId;
        
        emit LootBoxOpened(tokenId, 0);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 tokenId = vrfRequests[requestId];
        uint256 randomValue = randomWords[0] % 100;
        
        // Loot rarity: 0-49 = common, 50-79 = rare, 80-94 = epic, 95-99 = legendary
        if (randomValue >= 95) {
            // Legendary loot
            uint256 currentStrength = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "strength");
            traitFusion.setTraitUint(address(evolutionNFT), tokenId, "strength", currentStrength + 50);
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "loot_tier", "legendary");
        } else if (randomValue >= 80) {
            // Epic loot
            uint256 currentStrength = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "strength");
            traitFusion.setTraitUint(address(evolutionNFT), tokenId, "strength", currentStrength + 25);
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "loot_tier", "epic");
        } else if (randomValue >= 50) {
            // Rare loot
            uint256 currentStrength = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "strength");
            traitFusion.setTraitUint(address(evolutionNFT), tokenId, "strength", currentStrength + 10);
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "loot_tier", "rare");
        } else {
            // Common loot
            uint256 currentStrength = traitFusion.getTraitAsUint(address(evolutionNFT), tokenId, "strength");
            traitFusion.setTraitUint(address(evolutionNFT), tokenId, "strength", currentStrength + 5);
            traitFusion.setTraitString(address(evolutionNFT), tokenId, "loot_tier", "common");
        }
        
        delete vrfRequests[requestId];
    }
}

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

// ================================
// 7. ORACLE INTEGRATION CONTRACT
// ================================
contract OracleIntegration is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    GameEngine public gameEngine;
    
    // Chainlink Functions integration
    mapping(bytes32 => uint256) public requestToTokenId;
    mapping(uint256 => uint256) public lastUpdateTime;
    
    event OracleRequest(bytes32 indexed requestId, uint256 indexed tokenId, string dataType);
    event OracleResponse(bytes32 indexed requestId, uint256 indexed tokenId, bytes response);

    constructor(address _gameEngine) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        gameEngine = GameEngine(_gameEngine);
    }

    // Simulated oracle functions (in production, integrate with Chainlink Functions)
    function requestFitnessData(uint256 tokenId) external {
        require(block.timestamp >= lastUpdateTime[tokenId] + 1 hours, "Update too frequent");
        
        // In production, this would make a Chainlink Functions request
        // to fetch data from fitness APIs like Fitbit, Apple Health, etc.
        
        bytes32 requestId = keccak256(abi.encodePacked(tokenId, block.timestamp));
        requestToTokenId[requestId] = tokenId;
        
        emit OracleRequest(requestId, tokenId, "fitness");
    }

    function requestGPSData(uint256 tokenId) external {
        require(block.timestamp >= lastUpdateTime[tokenId] + 30 minutes, "Update too frequent");
        
        bytes32 requestId = keccak256(abi.encodePacked(tokenId, block.timestamp, "gps"));
        requestToTokenId[requestId] = tokenId;
        
        emit OracleRequest(requestId, tokenId, "gps");
    }

    function requestWeatherData(uint256 tokenId) external {
        require(block.timestamp >= lastUpdateTime[tokenId] + 1 hours, "Update too frequent");
        
        bytes32 requestId = keccak256(abi.encodePacked(tokenId, block.timestamp, "weather"));
        requestToTokenId[requestId] = tokenId;
        
        emit OracleRequest(requestId, tokenId, "weather");
    }

    // Simulated oracle fulfillment (in production, this would be called by Chainlink)
    function fulfillFitnessData(bytes32 requestId, uint256 steps) external onlyRole(ORACLE_ROLE) {
        uint256 tokenId = requestToTokenId[requestId];
        gameEngine.updateSteps(tokenId, steps);
        lastUpdateTime[tokenId] = block.timestamp;
        
        emit OracleResponse(requestId, tokenId, abi.encode(steps));
    }

    function fulfillGPSData(bytes32 requestId, string calldata zone) external onlyRole(ORACLE_ROLE) {
        uint256 tokenId = requestToTokenId[requestId];
        gameEngine.updateGPSZone(tokenId, zone);
        lastUpdateTime[tokenId] = block.timestamp;
        
        emit OracleResponse(requestId, tokenId, abi.encode(zone));
    }

    function fulfillWeatherData(bytes32 requestId, string calldata weather) external onlyRole(ORACLE_ROLE) {
        uint256 tokenId = requestToTokenId[requestId];
        gameEngine.updateWeather(tokenId, weather);
        lastUpdateTime[tokenId] = block.timestamp;
        
        emit OracleResponse(requestId, tokenId, abi.encode(weather));
    }
}
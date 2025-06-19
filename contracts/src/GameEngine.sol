pragma solidity ^0.8.19;

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

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
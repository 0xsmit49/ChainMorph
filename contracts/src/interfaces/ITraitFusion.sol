// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ================================
// 2. TRAIT FUSION PRECOMPILE INTERFACE
// ================================
interface ITraitFusion {
    function setTrait(address nft, uint256 tokenId, string calldata traitKey, bytes calldata value) external;
    function getTrait(address nft, uint256 tokenId, string calldata traitKey) external view returns (bytes memory);
    function getTraitAsUint(address nft, uint256 tokenId, string calldata traitKey) external view returns (uint256);
    function getTraitAsString(address nft, uint256 tokenId, string calldata traitKey) external view returns (string memory);
}

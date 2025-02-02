// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {PoseidonUnit2L, PoseidonUnit3L} from "../libraries/Poseidon.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

contract PoseidonSMT is Initializable {
    using SparseMerkleTree for SparseMerkleTree.Bytes32SMT;

    uint256 public constant ROOT_VALIDITY = 1 hours;

    address public depositor;

    mapping(bytes32 => uint256) internal _roots;

    SparseMerkleTree.Bytes32SMT internal _bytes32Tree;

    event RootUpdated(bytes32 root);

    modifier onlyDepositor() {
        _onlyDepositor();
        _;
    }

    modifier withRootUpdate() {
        _saveRoot();
        _;
        _notifyRoot();
    }

    function __PoseidonSMT_init(address depositor_, uint256 treeHeight_) external initializer {
        _bytes32Tree.initialize(uint32(treeHeight_));
        _bytes32Tree.setHashers(_hash2, _hash3);

        depositor = depositor_;
    }

    /**
     * @notice Adds the new element to the tree.
     */
    function add(
        bytes32 keyOfElement_,
        bytes32 element_
    ) external virtual onlyDepositor withRootUpdate {
        _bytes32Tree.add(keyOfElement_, element_);
    }

    /**
     * @notice Removes the element from the tree.
     */
    function remove(bytes32 keyOfElement_) external virtual onlyDepositor withRootUpdate {
        _bytes32Tree.remove(keyOfElement_);
    }

    /**
     * @notice Updates the element in the tree.
     */
    function update(
        bytes32 keyOfElement_,
        bytes32 newElement_
    ) external virtual onlyDepositor withRootUpdate {
        _bytes32Tree.update(keyOfElement_, newElement_);
    }

    /**
     * @notice Gets Merkle (inclusion/exclusion) proof of the element.
     */
    function getProof(bytes32 key_) external view virtual returns (SparseMerkleTree.Proof memory) {
        return _bytes32Tree.getProof(key_);
    }

    /**
     * @notice Gets the SMT root
     */
    function getRoot() external view virtual returns (bytes32) {
        return _bytes32Tree.getRoot();
    }

    /**
     * @notice Gets the node info by its key.
     */
    function getNodeByKey(
        bytes32 key_
    ) external view virtual returns (SparseMerkleTree.Node memory) {
        return _bytes32Tree.getNodeByKey(key_);
    }

    /**
     * @notice Check if the SMT root is valid. Zero root in always invalid and latest root is always a valid one.
     */
    function isRootValid(bytes32 root_) external view virtual returns (bool) {
        if (root_ == bytes32(0)) {
            return false;
        }

        return isRootLatest(root_) || _roots[root_] + ROOT_VALIDITY > block.timestamp;
    }

    /**
     * @notice Check if the SMT root is a latest one
     */
    function isRootLatest(bytes32 root_) public view virtual returns (bool) {
        return _bytes32Tree.getRoot() == root_;
    }

    function _saveRoot() internal {
        _roots[_bytes32Tree.getRoot()] = block.timestamp;
    }

    function _notifyRoot() internal {
        emit RootUpdated(_bytes32Tree.getRoot());
    }

    function _onlyDepositor() internal view {
        require(depositor == msg.sender, "PoseidonSMT: not a state keeper");
    }

    function _hash2(bytes32 element1_, bytes32 element2_) internal pure returns (bytes32) {
        return PoseidonUnit2L.poseidon([element1_, element2_]);
    }

    function _hash3(
        bytes32 element1_,
        bytes32 element2_,
        bytes32 element3_
    ) internal pure returns (bytes32) {
        return PoseidonUnit3L.poseidon([element1_, element2_, element3_]);
    }
}

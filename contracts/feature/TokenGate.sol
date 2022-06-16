// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../eip/interface/IERC20.sol";
import "../eip/interface/IERC721.sol";
import "../eip/interface/IERC1155.sol";

import "./TokenBundle.sol";

abstract contract TokenGate is TokenBundle {

    uint256 private constant DEFAULT_ID = type(uint256).max;

    function setTokenGate(uint256 _id, Token[] calldata _restrictions) public {
        require(_canSetTokenGate(), "Unauthorized caller");
        require(_id < DEFAULT_ID, "Setting default token gate");
        _setBundle(_restrictions, _id);
    }

    function setDefaultTokenGate(Token[] calldata _restrictions) public {
        require(_canSetTokenGate(), "Unauthorized caller");
        _setBundle(_restrictions, DEFAULT_ID);
    }

    function _canSetTokenGate() internal virtual returns (bool);

    /// @dev See {ERC721-_beforeTokenTransfer}.
    function _beforeTokenTransfer(
        address,
        address to,
        uint256 tokenId
    ) internal virtual {

        if(getTokenCountOfBundle(DEFAULT_ID) == 0 && getTokenCountOfBundle(tokenId) == 0) {
            return;
        }

        _gate(tokenId, to);
    }

    /// @dev See {ERC1155-_beforeTokenTransfer}.
    function _beforeTokenTransfer(
        address,
        address,
        address to,
        uint256[] memory ids,
        uint256[] memory,
        bytes memory
    ) internal virtual {

        bool defaultIsEmpty = getTokenCountOfBundle(DEFAULT_ID) == 0;
        bool toCheckDefault;

        for(uint256 i = 0; i < ids.length; i += 1) {
            if(getTokenCountOfBundle(ids[i]) > 0) {
                _gate(ids[i], to);
            } else if (!toCheckDefault && !defaultIsEmpty) {
                toCheckDefault = true;
            }
        }

        if(toCheckDefault) {
            _gate(DEFAULT_ID, to);
        }
    }

    function _gate(uint256 _tokenId, address _target) internal view {
        uint256 id = getTokenCountOfBundle(_tokenId) == 0 ? DEFAULT_ID : _tokenId;
        uint256 count = getTokenCountOfBundle(id);

        for(uint256 i = 0; i < count; i += 1) {
            Token memory token = getTokenOfBundle(id, i);
            bool success = _checkBalance(token, _target);

            require(success, "TokenGate: insufficient token ownership.");
        }
    }

    function _checkBalance(Token memory _token, address _target) internal view returns (bool success) {
        if(_token.tokenType == TokenType.ERC20) {
            success = IERC20(_token.assetContract).balanceOf(_target) > _token.totalAmount;
        } else if (_token.tokenType == TokenType.ERC721) {
            success = IERC721(_token.assetContract).balanceOf(_target) > 0;
        } else if (_token.tokenType == TokenType.ERC1155) {
            success = IERC1155(_token.assetContract).balanceOf(_target, _token.tokenId) > _token.totalAmount;
        }
    }
}
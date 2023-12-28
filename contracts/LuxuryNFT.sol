//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract LuxuryNFT is ERC721URIStorage, EIP712, AccessControl {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
  string private constant SIGNATURE_VERSION = "1";
  uint256 private nextTokenId;
  mapping (uint256 => NFTHolder) private _nftHold;

  mapping (address => uint256) pendingWithdrawals;

  constructor()
    ERC721("LazyNFT1", "LAZ1") 
    EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
      nextTokenId = 0;
      _setupRole(MINTER_ROLE, msg.sender);
    }

  /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
  struct NFTVoucher {
    uint256 tokenId;
    uint256 minPrice;
    string uri;
    bytes signature;
  }

  struct NFTHolder {
    address signer;
    address buyer;
    string uri;
  }

  /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
  /// @param redeemer The address of the account which will receive the NFT upon success.
  /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
  function redeem(address redeemer, NFTVoucher[] calldata voucher, uint256 count) public payable returns (uint256) {
    // make sure signature is valid and get the address of the signer
    require(nextTokenId < 100, "Nft token counts limited");

    for(uint256 index = 0 ; index < count ; index = index + 1){ 

      address signer = _verify(voucher[index]);

      // make sure that the signer is authorized to mint NFTs
        _nftHold[voucher[index].tokenId] = NFTHolder(signer, redeemer, voucher[index].uri);

        // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, voucher[index].tokenId);
        _setTokenURI(voucher[index].tokenId, voucher[index].uri);
        
        // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher[index].tokenId);

        // record payment to signer's withdrawal balance
        pendingWithdrawals[signer] += voucher[index].minPrice;

        if(nextTokenId < voucher[index].tokenId) {
          nextTokenId = voucher[index].tokenId;
        }
      // make sure that the redeemer is paying enough to cover the buyer's cost
    }
  }

  function getLastTokenId() external returns(uint256) {
    return nextTokenId;
  }

  /// @notice Transfers all pending withdrawal balance to the caller. Reverts if the caller is not an authorized minter.
  function withdraw() public {
    require(hasRole(MINTER_ROLE, msg.sender), "Only authorized minters can withdraw");
    
    // IMPORTANT: casting msg.sender to a payable address is only safe if ALL members of the minter role are payable addresses.
    address payable receiver = payable(msg.sender);

    uint amount = pendingWithdrawals[receiver];
    // zero account before transfer to prevent re-entrancy attack
    pendingWithdrawals[receiver] = 0;
    receiver.transfer(amount);
  }

  /// @notice Retuns the amount of Ether available to the caller to withdraw.
  function availableToWithdraw() public view returns (uint256) {
    return pendingWithdrawals[msg.sender];
  }

  /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
  /// @param voucher An NFTVoucher to hash.
  function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
    return _hashTypedDataV4(keccak256(abi.encode(
      keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri)"),
      voucher.tokenId,
      voucher.minPrice,
      keccak256(bytes(voucher.uri))
    )));
  }

  /// @notice Returns the chain id of the current blockchain.
  /// @dev This is used to workaround an issue with ganache returning different values from the on-chain chainid() function and
  ///  the eth_chainId RPC method. See https://github.com/protocol/nft-website/issues/121 for context.
  function getChainID() external view returns (uint256) {
    uint256 id;
    assembly {
        id := chainid()
    }
    return id;
  }

  /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
  /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
  /// @param voucher An NFTVoucher describing an unminted NFT.
  function _verify(NFTVoucher calldata voucher) internal view returns (address) {
    bytes32 digest = _hash(voucher);
    return ECDSA.recover(digest, voucher.signature);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721URIStorage) returns (bool) {
    return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }
}

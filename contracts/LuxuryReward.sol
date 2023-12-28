//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LuxuryReward is Ownable {
     address _mintContract;
     uint256 lastDistributionTime;
     uint256 duration;
     uint256 _ethAmount;
     uint256 _totalAmount;
     mapping (address => uint256) public holder_NFTs;
     mapping (address => uint256) private receivedTime;
     mapping (address => uint256) public holder_Rewards;
     address public claimer;
     mapping (uint256 => address) public accounts;

     constructor(address mintContractAddress) Ownable(msg.sender) 
     {
          _ethAmount = 0;
          _totalAmount = 100;
          _mintContract = mintContractAddress;
          lastDistributionTime = block.timestamp;
          duration = 24 * 60 * 60;
     }

     event EthReceived(address indexed sender, uint256 amount);

     receive() external payable {
          require(msg.value > 0, "Eth amount must be over than zero");
          _ethAmount += msg.value;
          emit EthReceived(msg.sender, msg.value);
     }

     function setDurationInDay(uint256 day) public onlyOwner {
          require(day > 0, "Duration must be over zero");
          duration = day * 24 * 60 * 60;
     }

     function startReward() public onlyOwner {
          lastDistributionTime = block.timestamp;
     }
     
     function getEthBack(address account) public onlyOwner {
          require(_ethAmount > 0, "There isn't any eth");
          uint256 gasPrice = tx.gasprice;
          uint256 gasLimit = 21000; // Gas limit for a basic ETH transfer
          uint256 transactionFee = gasPrice * gasLimit;
          uint256 ethAmount = _ethAmount - transactionFee;
          payable(address(account)).transfer(ethAmount);
     }

     function claimRewards(address account, uint256 totalNFTs) public returns(uint256){
          uint256 gasPrice = tx.gasprice;
          uint256 gasLimit = 21000; // Gas limit for a basic ETH transfer
          uint256 transactionFee = gasPrice * gasLimit;
          uint256 ethAmount = _ethAmount - transactionFee;
          claimer = account;
          //require(isClaimTime(), "It's not claim time");
          require(account != address(0), "Address is invaild");
          require((ethAmount > 0 || (holder_Rewards[claimer] == 0)), "There isn't any ETH amounts to give rewards.");
          
          uint256 count = 0;

          for(uint256 i = 1 ; i <= totalNFTs ; i = i + 1){
               if(IERC721(_mintContract).ownerOf(i) != address(0))
               {
                    address cur = IERC721(_mintContract).ownerOf(i);
                    if(holder_NFTs[cur] == 0) {
                         accounts[i] = cur;
                         count ++;
                    }
                    holder_NFTs[cur] ++;
               }
          }
          
          for(uint256 i = 1 ; i <= count ; i ++) {
               uint256 rewardAmount = ethAmount / _totalAmount * holder_NFTs[accounts[i]];
               holder_Rewards[accounts[i]] += rewardAmount;
          }

          require(holder_Rewards[claimer]>0, "No rewards for current claimer.");
          uint256 amt = holder_Rewards[claimer];
          if(holder_Rewards[claimer] > 0) {
               payable(claimer).transfer(amt);
               holder_Rewards[claimer] = 0;
          }
           _ethAmount = claimer.balance;
          
          return amt;
     }     

     function getOwnerOfTokenId(uint256 id) public view returns(address){
          return IERC721(_mintContract).ownerOf(id);
     }

     function isClaimTime() private returns(bool) {
          uint256 lDay = lastDistributionTime / 24 / 60 / 60;
          uint256 cDay = block.timestamp / 24 / 60 / 60;
          uint256 dDay = duration / 24 / 60 / 60;
          return ((cDay > lDay) && ((cDay - lDay) / dDay > 0) && ((cDay - lDay) % dDay < 2));
     }

     function getEthAmount() public view returns(uint256){
          return _ethAmount * 95 / 100;
     }

     function renounceOwnership() public virtual override onlyOwner {
          _transferOwnership(address(0));
     } 

     function transferOwnership(address newOwner) public virtual override onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }
}
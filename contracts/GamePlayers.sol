pragma solidity ^0.4.24;

contract GamePlayers {
    
    mapping (address => uint) public balances;
    
    event LogDeposit(address indexed, uint funds);
    event LogWithDraw (address indexed, uint funs);
    
   
   /* depositFund - This function allows users to deposit funds to the contract and
                    participate in the game.
   */
   function depositFund() public payable{
       balances[msg.sender] += msg.value;
       emit LogDeposit(msg.sender, balances[msg.sender]);
   }
   
   /* withDrawFund - This function allows users withdraw funds from the contract.
    @params : fundToWithDraw  - Fund to withdraw
   */
   function withDrawFund(uint fundToWithDraw) public {
        require (balances[msg.sender] >= fundToWithDraw, "Insufficient Funds");
        balances[msg.sender] -= fundToWithDraw;
        emit LogWithDraw(msg.sender,fundToWithDraw);
        msg.sender.transfer(fundToWithDraw);
  }
}

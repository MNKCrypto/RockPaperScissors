pragma solidity ^0.4.24;

import "./GamePlayers.sol";

/* This contract enables any user to start a new game and invite
   one other user to it. Once both the users go through the process of placing
   a bet in a secured way and followed by revealing their bet, this contract will
   find the winner and move the funds to the winner's balance */ 

contract RockPaperScissors is GamePlayers  {
 
 enum Outcome {NONE, ROCK, PAPER, SCISSORS}
 enum GameStatus{OPEN, CREATED, PLAYER1_ENROLLED, PLAYER2_ENROLLED,BET_PLACED,BET_REVEALED}
 
 struct Player {
     address playerId;
     bytes32 betHash;
     Outcome move;
 }
 
 struct Game {
     Player player1;
     Player player2;
     uint  betAmount;
     uint fundsCollected;
     GameStatus status;
     uint duration;
 }
 
 uint maxWaitTime = 100;
 uint newGameId = 0;
 mapping(uint=>Game) public games;
 
 event LogGameCreated(uint indexed gameId,uint betAmount);
 event LogPlayerEnrolled( uint indexed gameId, address indexed player, uint betAmount);
 event LogPlayerBetPlaced( uint indexed gameId, address indexed player);
 event LogPlayerBetRevealed(uint indexed gameId, address indexed player);
 event LogWinningGame(uint indexed gameId, address indexed winner, uint funds);
 event LogDrawGame(uint indexed gameId,uint funds);
 
 /* Constructor */
 constructor(uint _maxWaitTime) public {
     if(_maxWaitTime > 0){
         maxWaitTime = _maxWaitTime;
     }
 }
 
 /* CreateGame - This function allows any user to create a new Game 
    @params : _betAmount - Bet amount identified by the user for the Game.
    @returns : Game ID
 */
 function createGame(uint _betAmount) public returns(uint) {
     require(_betAmount > 0 , "Bet Amount should be greater than 0");
     uint gameId = newGameId;
     games[gameId].betAmount = _betAmount;
     games[gameId].duration = block.number + maxWaitTime;
     games[gameId].status = GameStatus.CREATED;
     enroll(_betAmount,gameId);
     newGameId++;
     emit LogGameCreated(gameId, _betAmount);
     return gameId;
 }
 
 /* enroll - This function allows any user to enroll to an existing game.
    @params : _playerBet - Bet amount for the Game.
              _gameId    - Unique ID wich identifies the Game which user wants to
                           be part of.
 */                           
 function enroll(uint _playerBet,uint _gameId) public {
     require(games[_gameId].status > GameStatus.OPEN, "Invlaid Game ID");
     require(games[_gameId].status < GameStatus.PLAYER2_ENROLLED, "Maximium Player count reached");
     require(games[_gameId].player1.playerId != msg.sender, "Player already enrolled");
     require(games[_gameId].player2.playerId != msg.sender, "Player already enrolled");
     require(games[_gameId].betAmount == _playerBet, "Incorrect Bet Amount");
     require(balances[msg.sender] >= _playerBet, "Insufficient Funds. Deposit Funds and retry");
     if(games[_gameId].status == GameStatus.CREATED){
         games[_gameId].player1.playerId = msg.sender;
         games[_gameId].status = GameStatus.PLAYER1_ENROLLED;
     }
     else{
         games[_gameId].player2.playerId = msg.sender;
         games[_gameId].status = GameStatus.PLAYER2_ENROLLED;
     }
     balances[msg.sender] -= _playerBet;
     games[_gameId].fundsCollected += _playerBet;
     require(games[_gameId].fundsCollected >= _playerBet, "Too large funds to manage");
     emit LogPlayerEnrolled(_gameId, msg.sender, _playerBet);
 }
 
 /* play - This function allows users who are part of a game to place their bet in a secured way.
    @params : _betHash   - Hash of contract address, player address, passcode , game id 
                           and player's move (Rock/Paper/Scissors)
              _gameId    - Unique ID wich identifies the Game which user wants to
                           be part of.
 */  
 function play(bytes32 _betHash, uint _gameId) public {
     
     require(games[_gameId].status == GameStatus.PLAYER2_ENROLLED, "You cannot place bet now");
     require(msg.sender == games[_gameId].player1.playerId || msg.sender == games[_gameId].player2.playerId, "Invalid Player");
     
     if(games[_gameId].player1.playerId == msg.sender){
        require(games[_gameId].player1.betHash == 0, "Bet already placed");  
        games[_gameId].player1.betHash = _betHash;
     }
     else{
        require(games[_gameId].player2.betHash == 0, "Bet already placed");  
        games[_gameId].player2.betHash = _betHash;
     }
     emit LogPlayerBetPlaced(_gameId, msg.sender);
     
     if (games[_gameId].player1.betHash != 0 && games[_gameId].player2.betHash != 0){
        games[_gameId].status = GameStatus.BET_PLACED;
     }
 }
 
 /* revealBet - This function is used by user to reveal bet once all the users who are
                part of the game have placed bet in a secured way.
    @params :_gameId    - Unique ID wich identifies the Game which user wants to
                           be part of.
             _move      - Player's move (Rock(1)/Paper(2)/Scissors(3)
             passCode   - Player's passCode for this game.
 */     
 
 function revealBet(uint _gameId, uint8 _move, bytes32 passCode) public {
     require(games[_gameId].player1.playerId == msg.sender || games[_gameId].player2.playerId == msg.sender, "Not authorized to access this game");
     require(games[_gameId].status != GameStatus.BET_REVEALED, "Game already revealed");
     require(games[_gameId].status == GameStatus.BET_PLACED, "Cannot reveal. Still some bets are not placed");
     
     if (msg.sender == games[_gameId].player1.playerId){
         require(getHash(_gameId,passCode,_move) == games[_gameId].player1.betHash, "Invalid Bet placed");
         games[_gameId].player1.move = Outcome(_move);
     }
     else{
         require(getHash(_gameId,passCode,_move) == games[_gameId].player2.betHash, "Invalid Bet placed");
         games[_gameId].player2.move = Outcome(_move);
     }
     emit LogPlayerBetRevealed(_gameId, msg.sender);
      if (games[_gameId].player1.move != Outcome.NONE && games[_gameId].player2.move != Outcome.NONE){
          announceResult(_gameId); 
          games[_gameId].fundsCollected = 0;
          games[_gameId].status = GameStatus.BET_REVEALED;
     }
     
}

/* announceResult - This function checks the player bets and identifies the winner.
                    We find the difference between the player's bets. If the result
                    is 0, then result of the Game is Draw. If the result is non-zero,
                    then we calculate modulo-3 of the difference to identify the 
                    winner.
    @params : _gameId    - Unique ID wich identifies the Game which user wants to
                           be part of.
 */
 function announceResult(uint _gameId) internal returns(bool) {
     Outcome  player1Move = Outcome(games[_gameId].player1.move);
     Outcome  player2Move = Outcome(games[_gameId].player2.move);
     uint diff = uint(player1Move) - uint(player2Move);
     if(diff == 0){
         balances[games[_gameId].player1.playerId] += games[_gameId].fundsCollected/2;
         balances[games[_gameId].player2.playerId] += games[_gameId].fundsCollected/2;
         emit LogDrawGame (_gameId, games[_gameId].fundsCollected);
         return true;
     }
     uint winningPlayer = (diff%3);
     if(winningPlayer == 1){
        balances[games[_gameId].player1.playerId] += games[_gameId].fundsCollected;
        emit LogWinningGame(_gameId,games[_gameId].player1.playerId,games[_gameId].fundsCollected);
     } else{
        balances[games[_gameId].player2.playerId] += games[_gameId].fundsCollected;
        emit LogWinningGame(_gameId,games[_gameId].player1.playerId,games[_gameId].fundsCollected);
     }
         
    return true;
     
 }
 
 /* getHash -   This function is used both internally and externally to calculate the betHash wwhich
                is used to transfer the player's bet in a secured way.
    @params : _gameId    - Unique ID wich identifies the Game which user wants to
                           be part of.
             _move      - Player's move (Rock(1)/Paper(2)/Scissors(3)
             passCode   - Player's passCode for this game.
 */
 function getHash( uint _gameId, bytes32 passCode, uint8 move) public view returns(bytes32){
     return (keccak256(abi.encodePacked(address(this),msg.sender,passCode, _gameId, move)));
 }
 
 /* claimFunds - This function is used by the user to reclaim funds from the Game which is stuck because of 
                 other player.
    @params : _gameId    - Unique ID wich identifies the Game which user wants to
                           be part of.
 */
 function claimFunds (uint _gameId) public returns(bool) {
     require(uint(games[_gameId].status) > 1, "Invalid Game Status to claim refund ");
     require(uint(games[_gameId].status) < 5, "Game is closed already ");
     require(games[_gameId].player1.playerId == msg.sender || games[_gameId].player2.playerId == msg.sender, "Not authorized to access this game");
     require(games[_gameId].duration <  block.number, "Game still in play");
     if (games[_gameId].player1.playerId == msg.sender){
        require(games[_gameId].player1.move != Outcome.NONE, "Player cannot claim  Fund now" );
     }
     else{
        require(games[_gameId].player2.move != Outcome.NONE, "Player cannot claim  Fund now" );
     }
     balances[msg.sender] += games[_gameId].betAmount;
     return true;
 }
}
	

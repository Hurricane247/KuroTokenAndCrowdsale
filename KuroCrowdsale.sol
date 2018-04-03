pragma solidity 0.4.21;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

interface TokenInterface {
     function totalSupply() external constant returns (uint);
     function balanceOf(address tokenOwner) external constant returns (uint balance);
     function allowance(address tokenOwner, address spender) external constant returns (uint remaining);
     function transfer(address to, uint tokens) external returns (bool success);
     function approve(address spender, uint tokens) external returns (bool success);
     function transferFrom(address from, address to, uint tokens) external returns (bool success);
     function burn(uint256 _value) external; 
     event Transfer(address indexed from, address indexed to, uint tokens);
     event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
     event Burn(address indexed burner, uint256 value);
}

 contract KuroCrowdsale is Ownable{
  using SafeMath for uint256;
 
  // The token being sold
  TokenInterface public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;


  // how many token units a buyer gets per wei
  uint256 public ratePerWeiInPhase1 = 15500;
  uint256 public ratePerWeiInPhase2 = 5166;
  uint256 public ratePerWeiInPhase3 = 2348;

  // amount of raised money in wei
  uint256 public weiRaised;

  uint256 public TOKENS_SOLD;
  
  uint256 maxTokensToSale;
  
  uint256 bonusInPhase1;
  uint256 bonusInPhase2;
  uint256 bonusInPhase3;
  
  bool isCrowdsalePaused = false;
  
  uint256 totalDurationInDays = 131 days;
  
  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  function KuroCrowdsale(uint256 _startTime, address _wallet, address _tokenAddress) public 
  {
    //require(_startTime >=now);
    require(_wallet != 0x0);

    //startTime = _startTime;  
    startTime = now;
    endTime = startTime + totalDurationInDays;
    require(endTime >= startTime);
   
    owner = _wallet;
    
    maxTokensToSale = 250000000000 * 10 ** 18;
    bonusInPhase1 = 50;
    bonusInPhase2 = 35;
    bonusInPhase3 = 20;
    token = TokenInterface(_tokenAddress);
  }
  
  
   // fallback function can be used to buy tokens
   function () public  payable {
     buyTokens(msg.sender);
    }
    
    function calculateTokens(uint value) internal view returns (uint256 tokens) 
    {
        uint256 timeElapsed = now - startTime;
        uint256 timeElapsedInDays = timeElapsed.div(1 days);
        uint256 bonus = 0;
        //Phase 1 (61 days)
        if (timeElapsedInDays <61)
        {
            tokens = value.mul(ratePerWeiInPhase1);
            bonus = tokens.mul(bonusInPhase1); 
            bonus = bonus.div(100);
            tokens = tokens.add(bonus);
            require (TOKENS_SOLD.add(tokens) <= maxTokensToSale);
        }
        // 8 days break
        else if (timeElapsedInDays>=61 && timeElapsedInDays< 69)
        {
            revert();
        }
        //Phase 2 (42 days)
        else if (timeElapsedInDays >=69 && timeElapsedInDays <111)
        {
            tokens = value.mul(ratePerWeiInPhase2);
            bonus = tokens.mul(bonusInPhase2); 
            bonus = bonus.div(100);
            tokens = tokens.add(bonus);
            require (TOKENS_SOLD.add(tokens) <= maxTokensToSale);
        }
        // 2 days break
        else if (timeElapsedInDays>=111 && timeElapsedInDays< 113)
        {
            revert();
        }
         //Phase 3 (19 days)
        else if (timeElapsedInDays >=113 && timeElapsedInDays <132)
        {
            tokens = value.mul(ratePerWeiInPhase3);
            bonus = tokens.mul(bonusInPhase3); 
            bonus = bonus.div(100);
            tokens = tokens.add(bonus);
            require (TOKENS_SOLD.add(tokens) <= maxTokensToSale);
        }
        else 
        {
            bonus = 0;
        }
    }

  // low level token purchase function
  
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != 0x0);
    require(isCrowdsalePaused == false);
    require(validPurchase());

    
    require(TOKENS_SOLD<maxTokensToSale);
   
    uint256 weiAmount = msg.value;

    uint256 tokens = calculateTokens(weiAmount);
    
    // update state
    weiRaised = weiRaised.add(weiAmount);
    
    token.transfer(beneficiary,tokens);
    emit TokenPurchase(owner, beneficiary, weiAmount, tokens);
    TOKENS_SOLD = TOKENS_SOLD.add(tokens);
    forwardFunds();
  }

  // send ether to the fund collection wallet
  function forwardFunds() internal {
    owner.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    return now > endTime;
  }
  
   /**
    * function to change the end timestamp of the ico
    * can only be called by owner wallet
    **/
    function changeEndDate(uint256 endTimeUnixTimestamp) public onlyOwner{
        endTime = endTimeUnixTimestamp;
    }
    
    /**
    * function to change the start timestamp of the ico
    * can only be called by owner wallet
    **/
    
    function changeStartDate(uint256 startTimeUnixTimestamp) public onlyOwner{
        startTime = startTimeUnixTimestamp;
    }
    
     /**
     * function to pause the crowdsale 
     * can only be called from owner wallet
     **/
     
    function pauseCrowdsale() public onlyOwner {
        isCrowdsalePaused = true;
    }

    /**
     * function to resume the crowdsale if it is paused
     * can only be called from owner wallet
     **/ 
    function resumeCrowdsale() public onlyOwner {
        isCrowdsalePaused = false;
    }
     
     function takeTokensBack() public onlyOwner
     {
         uint remainingTokensInTheContract = token.balanceOf(address(this));
         token.transfer(owner,remainingTokensInTheContract);
     }
}

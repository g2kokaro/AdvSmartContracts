pragma solidity ^0.5.0;

contract Storage {
    struct CrowdFund {
        address payable channelAddress;
        uint goalInWei;
        uint deadline;
        string description;
        uint contributors;
        uint weiRaised;
        mapping (address => uint) contributions;
    }
    
    mapping(uint => CrowdFund) crowdFunds;
    uint public currentFundId;
}

contract CrowdFund is Storage {
    
    event NewContribution(address indexed _who, uint _amount, uint _timestamp);
    event BeneficiaryPaid(address _beneficiary, uint _amount, uint _timestamp);
    event newCrowdFundCreated(uint _id, address payable _channelAddress, uint _goalInWei, uint _deadline);
    
    function newCrowdFund(address payable _channelAddress, uint _goalInWei, uint _duration, string memory _description) public {
        crowdFunds[currentFundId].channelAddress = _channelAddress;
        crowdFunds[currentFundId].goalInWei = _goalInWei;
        crowdFunds[currentFundId].description = _description;
        crowdFunds[currentFundId].deadline = now + _duration;
        emit newCrowdFundCreated(currentFundId, _channelAddress, _goalInWei, now + _duration);
        currentFundId++;
    }
    
    function pledge(uint _id) public payable {
        require(now < crowdFunds[_id].deadline);
        if (crowdFunds[_id].contributions[tx.origin] == 0){
            crowdFunds[_id].contributors++;
        } 
        crowdFunds[_id].contributions[tx.origin] += msg.value;
        emit NewContribution(msg.sender, msg.value, now);
    }
    
    function refund(uint _id) public {
        require(address(this).balance < crowdFunds[_id].goalInWei && now > crowdFunds[_id].deadline, 
            "Refunds are only allowed if the goal has not been met by the deadline.");
        uint amountToSend = crowdFunds[_id].contributions[tx.origin];
        crowdFunds[_id].contributions[tx.origin] = 0;
        tx.origin.transfer(amountToSend);
    }
    
    function payChannelOwner(uint _id) public {
        require(address(this).balance >= crowdFunds[_id].goalInWei && now > crowdFunds[_id].deadline,
            "The funds can only be collected if the goal has been reached by the deadline.");
        uint amountToSend = address(this).balance;
        crowdFunds[_id].channelAddress.transfer(address(this).balance);
        emit BeneficiaryPaid(crowdFunds[_id].channelAddress, amountToSend, now);
    }
    
    function getBalance(uint _id) public view returns (uint) {
        return crowdFunds[_id].weiRaised;
    }
}

contract Registry is Storage {
    
    address delegate;
    address owner;
    
    constructor() public {
        owner = msg.sender;
    }
    
    function () payable external {
        require(delegate != address(0x0), "Delegate contract address must be set.");
        address target = delegate;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize)
            let result := delegatecall(gas, target, ptr, calldatasize, 0, 0)
            let size := returndatasize
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            case 1 { return(ptr, size) }
        }
    }
    
    function setDelegateAddress (address _c) public {
        require(msg.sender == owner);
        delegate = _c;
    }
    
}


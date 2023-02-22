// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// creating interface to accept a custom ERC20 token

interface IERC20 {
    function transfer(address, uint) external returns (bool);

    function transferFrom(address, address, uint) external returns (bool);
}

// contract starts here
contract crowdfunding {
    // struct to keep track details of all the campaigns
    struct Campaign {
        address creator;
        uint goal;
        uint pledged;
        uint startAt;
        uint endAt;
        bool claimed;
    }

    // some global variables for various utilities

    IERC20 public immutable token; // custom token to be collected
    uint public count; // keeps count of the campaigns
    uint public maxDuration; // maximum duration for whic a campaign could run
    mapping(uint => Campaign) public campaigns; // mapping campaigns to uniquely identify them with a uint id
    mapping(uint => mapping(address => uint)) public pledgedAmount; // mapping to identify which campaign got pledge from whihc account and how much

    // event to be triggered on launch of a campaign

    event Launch(
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );
    event Cancel(uint id); // event to be emitted on cancelling a campaign
    event Pledge(uint indexed id, address indexed caller, uint amount); // event to emitted on pledging to a campaign
    event Unpledge(uint indexed id, address indexed caller, uint amount); // event to be emitted on unpledging from a campaign
    event Claim(uint id); // event to be emitted on claiming the amount of the campaign
    event Refund(uint id, address indexed caller, uint amount); // event to be emitted in case of refund due to whatsoever reason

    // initializing immutable variable via the constructor
    constructor(address _token, uint _maxDuration) {
        token = IERC20(_token); // custom token address
        maxDuration = _maxDuration; // duration of the campaign, identical to every campaign
    }

    /**
     * @dev function to launch the event
     */
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {
        require(
            _startAt >= block.timestamp,
            "Start time is less than current Block Timestamp"
        );
        require(_endAt > _startAt, "End time is less than Start time");
        require(
            _endAt <= block.timestamp + maxDuration,
            "End time exceeds the maximum Duration"
        );

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    /**
     *
     * @dev function to cancel any campaign
     */

    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(
            campaign.creator == msg.sender,
            "You did not create this Campaign"
        );
        require(
            block.timestamp < campaign.startAt,
            "Campaign has already started"
        );

        delete campaigns[_id];
        emit Cancel(_id);
    }

    /**
     *
     * @dev function to pledge to a campaign
     */
    function pledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(
            block.timestamp >= campaign.startAt,
            "Campaign has not Started yet"
        );
        require(
            block.timestamp <= campaign.endAt,
            "Campaign has already ended"
        );
        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    /**
     *
     * @dev function to unpledge from a campaign
     */

    function unPledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(
            block.timestamp >= campaign.startAt,
            "Campaign has not Started yet"
        );
        require(
            block.timestamp <= campaign.endAt,
            "Campaign has already ended"
        );
        require(
            pledgedAmount[_id][msg.sender] >= _amount,
            "You do not have enough tokens Pledged to withraw"
        );

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    /**
     *
     * @dev function to claim the raised fund
     */

    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(
            campaign.creator == msg.sender,
            "You did not create this Campaign"
        );
        require(block.timestamp > campaign.endAt, "Campaign has not ended");
        require(campaign.pledged >= campaign.goal, "Campaign did not succed");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;
        token.transfer(campaign.creator, campaign.pledged);

        emit Claim(_id);
    }

    /**
     *
     * function to refund the amount
     */

    function refund(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");
        require(
            campaign.pledged < campaign.goal,
            "You cannot Withdraw, Campaign has succeeded"
        );

        uint bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}

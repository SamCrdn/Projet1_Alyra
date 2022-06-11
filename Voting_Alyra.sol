// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.14;
 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Voting is Ownable {

    // VARIABLES
    struct voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
        string name;
    }
    struct proposal {
        string description;
        uint voteCount;
    }
    string public voteName;
    uint public totalVote;
    uint public totalVoter;

    mapping(address => voter) public voterAddress;
    mapping(uint => proposal) public proposalId;

    proposal[] proposals;
    voter[] voters;

    enum WorkflowStatus {RegisteringVoters, ProposalsRegistrationStarted, ProposalsRegistrationEnded, VotingSessionStarted, VotingSessionEnded, VotesTallied}
    WorkflowStatus public state;

    // MODIFIERS
    modifier inState(WorkflowStatus _state) {
        require(state == _state);
        _;
    }
    modifier onlyRegistated(){
        require (voterAddress[msg.sender].isRegistered,"Only registered person can submit proposal");
        _;
    }

    // EVENTS
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
    
    // FUNCTIONS
    constructor(string memory _voteName) {
        voteName = _voteName ;
        state = WorkflowStatus.RegisteringVoters;
    }

    function addVoters(address _voterAddress, string calldata _name) external onlyOwner inState(WorkflowStatus.RegisteringVoters) {
        voter memory v;
        v.isRegistered = true;
        v.name = _name;
        voters.push(v);
        voterAddress[_voterAddress] = v;
        totalVoter++;
        emit VoterRegistered(_voterAddress);
    }

    function startRegistrationProposals() external onlyOwner inState(WorkflowStatus.RegisteringVoters) {
        state = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters,  WorkflowStatus.ProposalsRegistrationStarted);
    }

    function setProposal(string calldata _description) external onlyRegistated inState(WorkflowStatus.ProposalsRegistrationStarted) {
        proposal memory p;
        p.description = _description;
        proposals.push(p);
        uint id = proposals.length;
        proposalId[id] = p;
        emit ProposalRegistered(id);
    }

    function viewAllProposals() public view returns(proposal[] memory) {
        return proposals;
    }

    function stopRegistrationProposals() external onlyOwner inState(WorkflowStatus.ProposalsRegistrationStarted) {
        state = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted,  WorkflowStatus.ProposalsRegistrationEnded);
    }
    
    function startVote() external onlyOwner inState(WorkflowStatus.ProposalsRegistrationEnded){
        state = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,  WorkflowStatus.VotingSessionStarted);
    }
    
    function vote(uint _vote) public onlyRegistated inState(WorkflowStatus.VotingSessionStarted) {
       require(_vote > 0 && _vote <= proposals.length, "proposal Id do not exist");
       if(!voterAddress[msg.sender].hasVoted) {                    
            voterAddress[msg.sender].votedProposalId = _vote;
            voterAddress[msg.sender].hasVoted = true;
            proposalId[_vote].voteCount += 1;
            proposals[_vote-1].voteCount += 1;
            totalVote++;

            emit Voted (msg.sender, _vote);     
       }else {
           revert("You already voted");
        }
    }

    function endVote() external onlyOwner inState(WorkflowStatus.VotingSessionStarted) {
        if(totalVote == totalVoter) {
            state = WorkflowStatus.VotingSessionEnded;
            emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,  WorkflowStatus.VotingSessionEnded);
        }else {
            revert("All voters did not vote");
         }
    }

    function getWinner() public onlyOwner inState(WorkflowStatus.VotingSessionEnded) returns (uint winningProposalId_, string memory winningProposalDescription_){
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposalId_ = p + 1;
                winningProposalDescription_ = proposals[p].description;
                state = WorkflowStatus.VotesTallied;
                emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,  WorkflowStatus.VotesTallied);
            }
        }
    }
}  

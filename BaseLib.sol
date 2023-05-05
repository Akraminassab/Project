pragma solidity ^0.4.24;

import "./ERC20.sol";
import "./SafeMath/SafeMathLib256.sol";


library Lib {
  using SafeMathLib256 for uint256;

  // ENUMS
  enum ChallengeType {
    NONE,
    STATE_UPDATE,
    TRANSFER_DELIVERY,
    SWAP_ENACTMENT
  }

  struct Checkpoint {
    uint256 eonNumber;
    bytes32 merkleRoot;
    uint256 liveChallenges;
  }


  struct Wallet {
    AmountAggregate[3] depositsKept;
    Withdrawal[] withdrawals;
    bool recovered;
  }

  struct Withdrawal {
    uint256 eon;
    uint256 amount;
  }


  struct Chain {
    // State Update Challenges
    ChallengeType challengeType; 
    uint256 block; 
    uint256 initialStateEon; 
    uint256 initialStateBalance;
    uint256 deltaHighestSpendings; 
    uint256 deltaHighestGains; 
    uint256 finalStateBalance;
    uint256 deliveredTxNonce;
    uint64 trailIdentifier; 
  }

  enum Operation {
    DEPOSIT,
    WITHDRAWAL,
    CANCELLATION
  }

  struct Ledger {

    uint8 EONS_KEPT;
    uint8 DEPOSITS_KEPT;
    uint256 MIN_CHALLENGE_GAS_COST;
    uint256 BLOCKS_PER_EON;
    uint256 BLOCKS_PER_EPOCH;
    uint256 EXTENDED_BLOCKS_PER_EPOCH;

    uint256 genesis;
    address operator;
    Checkpoint[5] checkpoints;
    bytes32[5] parentChainAccumulator; 
    uint256 lastSubmissionEon;
    mapping (address => mapping (address => mapping (address => Challenge))) challengeBook;
    mapping (address => mapping (address => Wallet)) walletBook;
    mapping (address => AmountAggregate[5]) deposits;
    mapping (address => AmountAggregate[5]) pendingWithdrawals;
    mapping (address => AmountAggregate[5]) confirmedWithdrawals;
    mapping (address => uint64) tokenToTrail;
    address[] trailToToken;
  }

  function init(
    Ledger storage self,
    uint256 blocksPerEon,
    address operator
  )
    public
  {
    self.BLOCKS_PER_EON = blocksPerEon;
    self.BLOCKS_PER_EPOCH = self.BLOCKS_PER_EON.div(4);
    self.EXTENDED_BLOCKS_PER_EPOCH = self.BLOCKS_PER_EON.div(3);
    self.EONS_KEPT = 5;
    self.DEPOSITS_KEPT = 3;
    self.MIN_CHALLENGE_GAS_COST = 0.005 szabo
    self.operator = operator;
    self.genesis = block.number;
  }

  function Withdrawals(
    Ledger storage self,
    ERC20 token,
    uint256 eon,
    uint256 value
  )
    public
  {
    AmountAggregate storage aggregate = self.pendingWithdrawals[token][eon.mod(self.EONS_KEPT)];

    if (aggregate.eon < eon) { // implies eon > 0
      aggregate.amount = getPendingWithdrawalsAtEon(self, token, eon.sub(1)).add(value);
      aggregate.eon = eon;
    } else {
      aggregate.amount = aggregate.amount.add(value);
    }
  }
  
  function deductFromRunningPendingWithdrawals(
    Ledger storage self,
    ERC20 token,
    uint256 eon,
    uint256 latestEon,
    uint256 value
  )
    public
  {
    for (uint256 i = 0; i < self.EONS_KEPT; i++) {
      uint256 targetEon = eon.add(i);
      AmountAggregate storage aggregate = self.pendingWithdrawals[token][targetEon.mod(self.EONS_KEPT)];
      if (targetEon > latestEon) {
        break;
      } else if (aggregate.eon < targetEon) { // implies targetEon > 0
        aggregate.eon = targetEon;
        aggregate.amount = getPendingWithdrawalsAtEon(self, token, targetEon.sub(1));
      }
    }
    for (i = 0; i < self.EONS_KEPT; i++) {
      targetEon = eon.add(i);
      aggregate = self.pendingWithdrawals[token][targetEon.mod(self.EONS_KEPT)];
      if (targetEon > latestEon) {
        break;
      } else if (aggregate.eon < targetEon) {
        revert('X'); 
      } else {
        aggregate.amount = aggregate.amount.sub(value);
      }
    }
  }

  function getOrCreateCheckpoint(
    Ledger storage self,
    uint256 targetEon,
    uint256 latestEon
  )
    public
    returns (Checkpoint storage checkpoint)
  {
    require(latestEon < targetEon.add(self.EONS_KEPT) && targetEon <= latestEon);

    uint256 index = targetEon.mod(self.EONS_KEPT);
    checkpoint = self.checkpoints[index];

    if (checkpoint.eonNumber != targetEon) {
      checkpoint.eonNumber = targetEon;
      checkpoint.merkleRoot = bytes32(0);
      checkpoint.liveChallenges = 0;
    }

    return checkpoint;
  }

  function PendingWithdrawal(
    Ledger storage self,
    ERC20 token,
    address holder,
    uint256 eon
  )
    public
    view
    returns (uint256 amount)
  {
    amount = 0;

    Wallet storage accountingEntry = self.walletBook[token][holder];
    Withdrawal[] storage withdrawals = accountingEntry.withdrawals;
    for (uint32 i = 0; i < withdrawals.length; i++) {
      Withdrawal storage withdrawal = withdrawals[i];
      if (withdrawal.eon == eon) {
        amount = amount.add(withdrawal.amount);
      } else if (withdrawal.eon > eon) {
        break;
      }
    }
  }


  function getCurrentEonDepositsWithdrawals(
    Ledger storage self,
    ERC20 token,
    address holder
  )
    public
    view
    returns (uint256 currentEonDeposits, uint256 currentEonWithdrawals)
  {

    currentEonDeposits = 0;
    currentEonWithdrawals = 0;

    Wallet storage accountingEntry = self.walletBook[token][holder];
    Challenge storage challengeEntry = self.challengeBook[token][holder][holder];

    AmountAggregate storage depositEntry =
      accountingEntry.depositsKept[challengeEntry.initialStateEon.mod(self.DEPOSITS_KEPT)];

    if (depositEntry.eon == challengeEntry.initialStateEon) {
      currentEonDeposits = currentEonDeposits.add(depositEntry.amount);
    }

    currentEonWithdrawals = getWalletPendingWithdrawalAmountAtEon(self, token, holder, challengeEntry.initialStateEon);

    return (currentEonDeposits, currentEonWithdrawals);
  }

  
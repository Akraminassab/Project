/* solhint-disable func-order */

pragma solidity ^0.4.24;

import "./ERC20.sol";
import "./BimodalLib.sol";
import "./ChallengeLib.sol";
import "./SafeMath/SafeMathLib256.sol";


library RecoveryLib {
  using SafeMathLib256 for uint256;
  using BimodalLib for BimodalLib.Ledger;

  function reclaimUncommittedDeposits(
    BimodalLib.Ledger storage ledger,
    BimodalLib.Wallet storage wallet
  )
    private
    returns (uint256 amount)
  {
    for (uint8 i = 0; i < ledger.DEPOSITS_KEPT; i++) {
      BimodalLib.AmountAggregate storage depositAggregate = wallet.depositsKept[i];
      // depositAggregate.eon < ledger.lastSubmissionEon.sub(1)
      if (depositAggregate.eon.add(1) < ledger.lastSubmissionEon) {
        continue;
      }
      amount = amount.add(depositAggregate.amount);
      BimodalLib.clearAggregate(depositAggregate);
    }
  }

  function reclaimFinalizedWithdrawal(
    BimodalLib.Ledger storage ledger,
    BimodalLib.Wallet storage wallet
  )
    private
    returns (uint256 amount)
  {
    BimodalLib.Withdrawal[] storage withdrawals = wallet.withdrawals;
    for (uint32 i = 0; i < withdrawals.length; i++) {
      BimodalLib.Withdrawal storage withdrawal = withdrawals[i];

      if (withdrawal.eon.add(2) > ledger.lastSubmissionEon) {
        break;
      }

      amount = amount.add(withdrawal.amount);
      delete withdrawals[i];
    }
  }


  function recoverOnlyParentChainFunds(
    BimodalLib.Ledger storage ledger,
    ERC20 token,
    address holder
  )
    public
    returns (uint256 reclaimed)
  {
    BimodalLib.Wallet storage wallet = ledger.walletBook[token][holder];

    reclaimed = reclaimUncommittedDeposits(ledger, wallet)
              .add(reclaimFinalizedWithdrawal(ledger, wallet));

    if (ledger.lastSubmissionEon > 0) {
      BimodalLib.AmountAggregate storage eonWithdrawals =
        ledger.confirmedWithdrawals[token][ledger.lastSubmissionEon.sub(1).mod(ledger.EONS_KEPT)];
      BimodalLib.addToAggregate(eonWithdrawals, ledger.lastSubmissionEon.sub(1), reclaimed);
    }

    if (token != address(this)) {
      require(
        ledger.tokenToTrail[token] != 0,
        't');
      require(
        token.transfer(holder, reclaimed),
        'f');
    } else {
      holder.transfer(reclaimed);
    }
  }
  function recoverAllFunds(
    BimodalLib.Ledger storage ledger,
    ERC20 token,
    address holder,
    bytes32[2] checksums,
    uint64 trail,
    bytes32[] allotmentChain,
    bytes32[] membershipChain,
    uint256[] values,
    uint256[2] LR, // solhint-disable func-param-name-mixedcase
    uint256[3] dummyPassiveMark
  )
    public
    returns (uint256 recovered)
  {
    BimodalLib.Wallet storage wallet = ledger.walletBook[token][holder];
    require(
      !wallet.recovered,
      'a');
    wallet.recovered = true;

    recovered = LR[1].sub(LR[0]); // excluslive allotment
    recovered = recovered.add(reclaimUncommittedDeposits(ledger, wallet)); // unallotted parent chain deposits
    recovered = recovered.add(reclaimFinalizedWithdrawal(ledger, wallet)); // confirmed parent chain withdrawal

    if (ledger.lastSubmissionEon > 0) {
      dummyPassiveMark[0] = ledger.lastSubmissionEon.sub(1); // confirmedEon
    } else {
      dummyPassiveMark[0] = 0;
    }

    BimodalLib.AmountAggregate storage eonWithdrawals =
      ledger.confirmedWithdrawals[token][dummyPassiveMark[0].mod(ledger.EONS_KEPT)];
    BimodalLib.addToAggregate(eonWithdrawals, dummyPassiveMark[0], recovered);

    if (token != address(this)) {
      require(
        ledger.tokenToTrail[token] != 0,
        't');
      require(
        token.transfer(holder, recovered),
        'f');
    } else {
      holder.transfer(recovered);
    }
  }
}

const LotteryContract = artifacts.require("LotteryContract");
const erc20Token = artifacts.require("ERC20Token");

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
contract("LotteryContract", (accounts) => {
  let lotteryContract;
  let token;
  let decimals = 10 ** 18;
  let allowance = BigInt(20 * decimals);
  let defaultLotteryAmount = BigInt(10 * decimals);
  let balanceOfContract;
  let participants = {};
  let participantCount;
  let remainContractBalance;
  beforeEach(async () => {
    owner = accounts[0];
    token = await erc20Token.deployed();
    lotteryContract = await LotteryContract.deployed();
    // await token.transfer(lotteryContract.address, BigInt(21000000 * decimals));
  });
  describe("buy lottery and get funded by token", () => {
    it(" should accept ERC 20 token", async () => {
      await token.approve(lotteryContract.address, allowance);
      let allowanceOfContract = await token.allowance(
        accounts[0],
        lotteryContract.address,
      );
      assert.equal(allowanceOfContract.toString(), allowance);
    });

    it("should transfer from allowance and buy lottery,as per default lottery amount per Erc20 token", async () => {
      let result = await lotteryContract.buyLottery(token.address);
      participantCount = result.logs[0].args.currentParticipant.toString();
      participants[result.logs[0].args.participant] =
        result.logs[0].args.lotteryAmount;
      balanceOfContract = await token.balanceOf(lotteryContract.address);
      assert.equal(balanceOfContract.toString(), defaultLotteryAmount);
    });

    it("another person should be able to invest in lottery", async () => {
      await web3.eth.sendTransaction({
        to: token.address,
        from: accounts[2],
        value: web3.utils.toWei("1", "ether"),
      }); //fallback will buy token
      let balance = await token.balanceOf(accounts[2]);
      await token.approve(lotteryContract.address, allowance, {
        from: accounts[2],
      });

      let allowanceOfContract = await token.allowance(
        accounts[2],
        lotteryContract.address,
      );

      assert.equal(allowanceOfContract.toString(), allowance);
      let result = await lotteryContract.buyLottery(token.address, {
        from: accounts[2],
      });
      participantCount = result.logs[0].args.currentParticipant.toString();
      participants[result.logs[0].args.participant] =
        result.logs[0].args.lotteryAmount;
      balanceOfContract = await token.balanceOf(lotteryContract.address);

      assert.equal(
        balanceOfContract.toString(),
        defaultLotteryAmount * BigInt(2), // lottery amount should be double, as second person buy Lottery
      );
    });
    it(" should not able to buy if allowance is 0", async () => {
      try {
        await lotteryContract.buyLottery(token.address, { from: accounts[3] });
        balanceOfContract = await token.balanceOf(lotteryContract.address);
        assert.equal(balanceOfContract.toString(), defaultLotteryAmount);
      } catch (err) {
        balanceOfContract = await token.balanceOf(lotteryContract.address);
        assert.equal(
          balanceOfContract.toString(),
          defaultLotteryAmount * BigInt(2),
        );
        assert.equal(err.reason, "ERC20: transfer amount exceeds balance");
      }
    });
    // it(" should not be bougth by same user again and again and revert transaction", async () => {
    //   try {
    //     await lotteryContract.buyLottery(token.address); //TODO: state to initial when fail
    //   } catch (err) {
    //     balanceOfContract = await token.balanceOf(lotteryContract.address);
    //     assert.equal(
    //       balanceOfContract.toString(),
    //       defaultLotteryAmount * BigInt(2),
    //     );
    //     assert.equal(
    //       err.reason,
    //       "user has already participanted in current lot",
    //     );
    //   }
    // });
    it("should have same participants", async () => {
      assert.equal(participantCount, Object.keys(participants).length);
    });
  });

  describe("retrive lottery details", async () => {
    it("should get current lottery number", async () => {
      let getCurrentLottery = await lotteryContract.getCurrentLotteryNumber(
        token.address,
      );
      assert.equal(getCurrentLottery, 1);
    });
    it("should get current lottery details", async () => {
      let getCurrentLottery = await lotteryContract.getCurrentLotteryNumber(
        token.address,
      );
      assert.equal(getCurrentLottery, 1);
      let lotteryDetails = await lotteryContract.getDetails(
        token.address,
        getCurrentLottery,
      );
      balanceOfContract = await token.balanceOf(lotteryContract.address);

      assert.equal(lotteryDetails.totalFund.toString(), balanceOfContract);
      console.log(lotteryDetails.lotteryStartedTime <= Date.now());
      assert.equal(lotteryDetails.totalParticipants, 2); // 2 person has bought  lottery
    });
  });
  describe("anounce winner and pay to winner", async () => {
    let result;
    let beforeBalance = {};
    beforeEach(async () => {
      for (let value of Object.keys(participants)) {
        let balance = await token.balanceOf(value);
        beforeBalance[value] = balance;
      }
      await sleep(6500); // remove sleep  everything will be fail
    });
    it("should transfer fund to winner and must distribute lottery amount same collected per lot ", async () => {
      result = await lotteryContract.checkRules(token.address);
      // console.log(result.logs[0].args.winner, "check");
      remainContractBalance = await token.balanceOf(lotteryContract.address);
      let totalLotteryAmount = remainContractBalance / decimals;
      // console.log(result.logs[0].args, "args");
      for (let value of result.logs[0].args.winner) {
        let balance = await token.balanceOf(value.participant);
        console.log(balance / decimals, "balance");
        totalLotteryAmount += value.winningAmout / decimals;
        assert.equal(
          Math.round((balance - value.winningAmout) / decimals), //check current balance - wining balance is same as before anouncing balanace of participant
          Math.round((beforeBalance[value.participant] - 0) / decimals),
        );
      }
      assert.equal(
        totalLotteryAmount,
        (parseInt(defaultLotteryAmount) / decimals) * 2,
      );
    });

    it("should change lottery lot after lottery timed out", async () => {
      let getCurrentLottery = await lotteryContract.getCurrentLotteryNumber(
        token.address,
      );
      assert.equal(getCurrentLottery.toString(), 2);
    });
  });
  describe("it should start new lottery lot", () => {
    it("should buy  2nd lot", async () => {
      for (var i = 4; i < 9; i++) {
        // buy from account 4 to 8
        await web3.eth.sendTransaction({
          to: token.address,
          from: accounts[i],
          value: web3.utils.toWei("1", "ether"),
        });
        await token.approve(lotteryContract.address, allowance, {
          from: accounts[i],
        });

        let allowanceOfContract = await token.allowance(
          accounts[i],
          lotteryContract.address,
        );

        assert.equal(allowanceOfContract.toString(), allowance);
        let result = await lotteryContract.buyLottery(token.address, {
          from: accounts[i],
        });
        // console.log(result.logs[0].args["currentParticipant"], "result.logs");
        // participantCount = result.logs[0].args.currentParticipant.toString();
        participants[result.logs[0].args.participant] =
          result.logs[0].args.lotteryAmount;
        balanceOfContract = await token.balanceOf(lotteryContract.address);

        assert.equal(
          Math.round(balanceOfContract - remainContractBalance),
          defaultLotteryAmount * BigInt(i - 3), // lottery amount should be increased
        );
      }
      let getCurrentLottery = await lotteryContract.getCurrentLotteryNumber(
        token.address,
      );
      assert.equal(getCurrentLottery.toString(), 2);

      let lotteryDetails = await lotteryContract.getDetails(
        token.address,
        getCurrentLottery,
      );
      balanceOfContract = await token.balanceOf(lotteryContract.address);

      assert.equal(
        lotteryDetails.totalFund.toString(),
        balanceOfContract - remainContractBalance,
      );
      assert.equal(lotteryDetails.totalParticipants, 5);
    });
    it("should automatic declare result lottery if time expire", async () => {
      let result;
      let beforeBalance = {};
      let lotteryDetails = await lotteryContract.getDetails(token.address, 2);
      console.log(lotteryDetails, "lotteryDetails");
      for (let value of Object.keys(participants)) {
        let balance = await token.balanceOf(value);
        beforeBalance[value] = balance;
      }

      // from account 9
      await web3.eth.sendTransaction({
        to: token.address,
        from: accounts[9],
        value: web3.utils.toWei("1", "ether"),
      });
      await token.approve(lotteryContract.address, allowance, {
        from: accounts[9],
      });

      let allowanceOfContract = await token.allowance(
        accounts[9],
        lotteryContract.address,
      );

      assert.equal(allowanceOfContract.toString(), allowance);
      await sleep(4500); // buy after time out
      result = await lotteryContract.buyLottery(token.address, {
        from: accounts[9],
      });

      console.log(result.logs[0].args[0], "result");
      for (let value of result.logs[0].args[0]) {
        let balance = await token.balanceOf(value.participant);
        // totalLotteryAmount += value.winningAmout / decimals;
        console.log(value.winningAmout / decimals, "winning");
        assert.equal(
          Math.round((balance - value.winningAmout) / decimals), //check current balance - wining balance is same as before anouncing balanace of participant
          Math.round((beforeBalance[value.participant] - 0) / decimals),
        );
      }
      let balance = await token.balanceOf(lotteryContract.address);
      console.log(balance / decimals, "remaining");
      let getCurrentLottery = await lotteryContract.getCurrentLotteryNumber(
        token.address,
      );
      assert.equal(getCurrentLottery.toString(), 3);
    });
  });
});

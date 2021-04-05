const ERC20Token = artifacts.require("ERC20Token");
const LotteryContract = artifacts.require("LotteryContract");

module.exports = async function (deployer) {
  // deployer.link(ConvertLib, MetaCoin);
  let erc20Token = await deployer.deploy(
    ERC20Token,
    "TestToken",
    "TEST",
    231000000,
    3000000000,
    10000,
  );
  let lottery = await deployer.deploy(
    LotteryContract,
    10,
    4,
    10,
    ERC20Token.address,
  ); // lottery time in seccond
  // console.log(ERC20Token.address);
};

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";

contract ERC20Token is ERC20Capped, Ownable {
    uint256 private _tokenRate;

    constructor(
        string memory _name,
        string memory _symbole,
        uint256 _initialSupply,
        uint256 _maxTotalSupply,
        uint256 _rate
    ) ERC20Capped(_maxTotalSupply * (10**18)) ERC20(_name, _symbole) {
        require(
            _initialSupply <= _maxTotalSupply,
            "initial supply must be less then max total supply"
        );
        setCurrentRate(_rate);
        uint256 tokenSupply = _initialSupply * (10**18);
        ERC20._mint(msg.sender, tokenSupply);
    }

    event paybaletoken(uint256 totalPayableToken, address to);
    event PriceSet(uint256 price);

    // receive payment in ether and will convert it to given token
    //this is capped type of token, so if cap will exceeded user won't be able to mint and will get refund.
    receive() external payable {
        buyTokenUptoCapped();
    }

    // buy abount in wei.
    function buyTokenUptoCapped() public payable {
        uint256 totalPayableToken = (msg.value * _tokenRate) / 1 ether;
        require(totalPayableToken > 0, "make sure user buy atleast 1 token"); // as floting number not supported. make sure if user will try to buy less then 1 token, transaction will fail and user will gwt refund
        _mint(msg.sender, totalPayableToken);
        emit paybaletoken(totalPayableToken, msg.sender);
    }

    // set price as per demand.
    function setCurrentRate(uint256 _newRate) public onlyOwner {
        _tokenRate = _newRate * (10**18);
        emit PriceSet(_tokenRate);
    }

    // This contract is payable and only contract owner can withdraw fund
    function withdrawEther() public onlyOwner {
        address payable payTo = payable(msg.sender);
        payTo.transfer(address(this).balance);
    }
}

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Owned.sol";



// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract TokenEvents {
    event Burnt(address indexed src, uint256 wad);
    event Minted(address indexed src, uint256 wad);
}


contract PollToken is ERC20Interface, Owned, TokenEvents {
    string public symbol;
    string public name; // Optional token name
    uint8 public decimals = 18; // standard token precision. override to customize

    uint256 public totalSupply;
    uint256 public maxBalance;
    bytes32 public poll;
    bool public open;

    mapping(bytes32 => bool) polls;
    mapping(bytes32 => mapping(address => uint256)) balances;
    mapping(bytes32 => mapping(address => mapping(address => uint256))) allowances;
    mapping(bytes32 => address[]) questions;

    modifier canTransfer(address src, address dst) {
        _;
    }

    function PollToken(string name_, string symbol_) public {
        // you can't create logic here, because this contract would be the owner.
        name = name_;
        symbol = symbol_;
        open = true;
    }

    function () payable public {
        maxBalance = SafeMath.add(maxBalance, msg.value);
    }

    function stop() public onlyOwner {
        open = false;
        maxBalance = this.balance;
    }

    function retrieveBalance() public onlyOwner {
        owner.transfer(this.balance);
    }

    function balanceOf( address who ) public view returns (uint256) {
        return balances[poll][who];
    }

    function getQuestions() public view returns (address[]) {
        return questions[poll];
    }

    function addPoll() public onlyOwner {
        poll = keccak256(block.blockhash(block.number));
    }

    function setPoll(bytes32 poll_) public onlyOwner {
        //we only accept existing poll IDs
        require(polls[poll_]);
        poll = poll_;
    }

    function addQuestion(address question) public {
        questions[poll].push(question);
    }

    function allowance(address owner, address spender ) public view returns (uint256) {
        return allowances[poll][owner][spender];
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        require(open);
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        require(open);
        //TODO: check if memory is the correct place
        address[] memory pollQuestions = questions[poll];
        bool isQuestionDst;
        for (uint16 i = 0; i < pollQuestions.length; ++i) {
            if (pollQuestions[i] == dst) {
                isQuestionDst = true;
            }
        }
        //user etiher transfers their own tokens or they were given an allowance
        if(msg.sender != src) {
            require(allowances[poll][src][msg.sender] >= wad);
            require(isQuestionDst);
        }

        balances[poll][src] = SafeMath.sub(balances[poll][src], wad);
        balances[poll][dst] += SafeMath.add(balances[poll][dst], wad);
        Transfer(src, dst, wad);

        if(isQuestionDst) {
            uint256 portion = (totalSupply * 1000) / wad;
            src.transfer((maxBalance * 1000) / portion);
        }

        return true;
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        require(open);
        allowances[poll][msg.sender][guy] = wad;
        Approval(msg.sender, guy, wad);
        return true;
    }

    function pull(address src, uint256 wad) public returns (bool) {
        require(open);
        return transferFrom(src, msg.sender, wad);
    }

    function mint(address dst, uint256 wad) public onlyOwner {
        balances[poll][dst] = SafeMath.add(balances[poll][dst], wad);
        totalSupply = SafeMath.add(totalSupply, wad);
        Minted(dst, wad);
        Transfer(address(0x0), dst, wad);
    }

    function burn(uint256 wad) public {
        balances[poll][msg.sender] = SafeMath.sub(balances[poll][msg.sender], wad);
        totalSupply = SafeMath.sub(totalSupply, wad);
        Burnt(msg.sender, wad);
        Transfer(msg.sender, address(0x0), wad);
    }

    function setName(string name_) public onlyOwner {
        name = name_;
    }
}

from fractions import gcd
from random import randrange, random
from collections import namedtuple
from math import log
from binascii import hexlify, unhexlify
from brownie import MyToken,accounts
from web3 import Web3

def deploy_token():
    initial_supply = Web3.toWei(21_000_000,"ether_ERC")
    my_token = MyToken.deploy(accounts[0],initial_supply,{"from":accounts[0]})
    return my_token
    
def send_token(receiver,amount):
    my_token = MyToken[-1]
    my_token.transfer(receiver,amount)
    get_token_balance(receiver)
    
    
def get_token_balance(account_address):
    my_token = MyToken[-1]
    balance = my_token.balanceOf(account_address)
    print(f"The account {account_address} has balance {balance}")

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CoinERC20 {

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    string public constant name = "Test Coin";
    string public constant symbol = "test";
    uint8 public constant decimals = 18;

    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;

    uint256 totalSupply_;

    constructor(uint256 total) {
      totalSupply_ = total;
      balances[msg.sender] = totalSupply_;
    }

    function totalSupply() public view returns (uint256) {
      return totalSupply_;
    }

    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances[tokenOwner];
    }

    function transfer(address receiver, uint numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] -= numTokens;
        balances[receiver] += numTokens;
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function approve(address delegate, uint numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function allowance(address owner, address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);

        balances[owner] -= numTokens;
        allowed[owner][msg.sender] -= numTokens;
        balances[buyer] += numTokens;
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Implement {
    uint256 private struct;
    uint256 private reward;

    constructor(){
        correctAnswer = 11;
        reward = convertToWei(1000000);
    }

    function answerQuestion(uint256 _answer, address payable user,IERC20 token)  public{
        require(_answer == correctAnswer,"that is the wrong answer");
        token.transferFrom(msg.sender,user,reward);
    }
    function convertToWei(uint256 _eth) public pure returns(uint256){
        return _eth*(10**18);
    }
}

def is_prime(n, k=30):
    if n <= 3:
        return n == 2 or n == 3
    neg_one = n - 1

    s, d = 0, neg_one
    while not d & 1:
        s, d = s+1, d>>1
    assert 2 ** s * d == neg_one and d & 1

    for i in xrange(k):
        a = randrange(2, neg_one)
        x = pow(a, d, n)
        if x in (1, neg_one):
            continue
        for r in xrange(1, s):
            x = x ** 2 % n
            if x == 1:
                return False
            if x == neg_one:
                break
        else:
            return False
    return True

def randprime(N=10**8):
    p = 1
    while not is_prime(p):
        p = randrange(N)
    return p

def multinv(modulus, value):
    x, lastx = 0, 1
    a, b = modulus, value
    while b:
        a, q, b = b, a // b, a % b
        x, lastx = lastx - q * x, x
    result = (1 - lastx * modulus) // value
    if result < 0:
        result += modulus
    assert 0 <= result < modulus and value * result % modulus == 1
    return result

KeyPair = namedtuple('KeyPair', 'public private')
Key = namedtuple('Key', 'exponent modulus')

def keygen(N, public=None):
    prime1 = randprime(N)
    prime2 = randprime(N)
    composite = prime1 * prime2
    totient = (prime1 - 1) * (prime2 - 1)
    if public is None:
        while True:
            private = randrange(totient)
            if gcd(private, totient) == 1:
                break
        public = multinv(totient, private)
    else:
        private = multinv(totient, public)
    assert public * private % totient == gcd(public, totient) == gcd(private, totient) == 1
    assert pow(pow(n, public, composite), private, composite) == n
    return KeyPair(Key(public, composite), Key(private, composite))

def signature(privkey, r, serial, n ):
    serial =f.timestamp()
    sig =  ( serial ** privkey ) * r % n
    return sig

def blindingfactor(N):
    b=random()*(N-1)
    r=int(b)
    while (gcd(r,N)!=1):
        r=r+1
    return r

def blind(tk,privkey):
    r=blindingfactor(pubkey[1])
    m=int(tk)
    blindcn=(sig(privkey, r, serial, n)
    print "Blinded"
    return blindcn

def unblind(tk,r,pubkey, n):
	bsm=int(tk)
	ubsm=(bsm*multinv(pubkey[1],r))% pubkey[1]
	print "Unblinded"
	f.write(str(ubsm))

if __name__ == '__main__':
    
    tk = deploy_token()
    account_0 = accounts[0]
    account_1 = accounts[1]
    get_token_balance(account_0)
    send_token(account_1,Web3.toWei(7_000_000,"ether"))
    get_token_balance(account_0)


    get_token_balance(account_0)

    pubkey, privkey = keygen(2 ** 128)
    
    r=blind(msg,pubkey)

    signature(m, privkey)

    unblind(signedmsg,r,pubkey)
    
    verefy(ubsignedmsg,r,pubkey)


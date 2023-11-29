// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

error PoolDoesNotExist();
error VotingTimeExcceded();
error TokenRuggedAlready();
error PairDoesNotExist();
error YouDidNotBet();

contract WeWillRug {
    enum Options {
        WillRug,
        WillNotRug
    }


    struct Pool {
        uint256 id;
        uint256 totalParticipants;
        uint256 totalWERUGForWillRug;
        uint256 totalWERUGForWillNotRug;
        uint256 totalWERUG;
        uint256 timeCreated;
        address pairAddress;
        address tokenA;
        address tokenB;
        bool ruged;
        // bool canClaim;
    }

    struct Bet {
        uint256 amount;
        bool willRug;
    }

    mapping(uint256 => Pool) public pools;
    mapping(address => mapping(uint256 => Bet)) usersToBet;

    uint256 maxVotingPeriod = 1 hours;
    uint256 betEnding = 24 hours;
    uint256 poolCounter;

    IERC20 public WERUG;
    IUniswapV2Router02 public uniswapRouter;

    constructor(address _WERUG, address _uniswapRouter) {
        WERUG = IERC20(_WERUG);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    modifier itExist(uint256 _poolId) {
        Pool storage pool = pools[_poolId];
        if (pool.pairAddress == address(0)) {
            revert PoolDoesNotExist();
        }
        _;
    }

    function createBetPool(address _tokenA, address _tokenB) public {
        Pool storage pool = pools[poolCounter];

        address pair = IUniswapV2Factory(uniswapRouter.factory()).getPair(_tokenA, _tokenB);
        if (pair == address(0)) {
            revert PairDoesNotExist();
        }
        pool.id = poolCounter;
        pool.pairAddress = pair;
        pool.tokenA = _tokenA;
        pool.timeCreated = block.timestamp;
        
        poolCounter++;
    }

    function claim(uint256 _poolId, address beneficiary) public itExist(_poolId) {
        Pool storage pool = pools[_poolId];
        Bet storage userBet = usersToBet[msg.sender][_poolId];
        if(userBet.amount <= 0){
            revert YouDidNotBet();
        }

        // if(pool.ruged)
        // if(pool.timeCreated)
    }

    function bet(uint256 _poolId, bool willRug, uint256 amount) public itExist(_poolId) {
        Pool storage pool = pools[_poolId];
        if (pool.timeCreated + maxVotingPeriod <= block.timestamp) {
            revert VotingTimeExcceded();
        }

        if (pool.ruged == true) {
            revert TokenRuggedAlready();
        }

        WERUG.transferFrom(msg.sender, address(this), amount);

        Bet storage userBet = usersToBet[msg.sender][_poolId];
        userBet.amount = amount;
        userBet.willRug = willRug;

        if (willRug) {
            pool.totalWERUGForWillRug = pool.totalWERUGForWillRug + amount;
        } else {
            pool.totalWERUGForWillNotRug = pool.totalWERUGForWillNotRug + amount;
        }
    }
}

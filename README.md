<img src="https://i.imgur.com/wlfseTw.png" style="width:273px;">

# Sigma Zero Contract

This is the smart contract which handles Sigma Zero events.

## Table of Contents

- [Scripts](#scripts)
- [Contract Structure](#contract-structure)
  - [Events](#events)
  - [Methods](#methods)

## Scripts

- `compile`: Compiles your Solidity contracts using Hardhat, and shows stack traces if there are any compilation errors.
- `test`: Runs your contract tests using Hardhat's testing framework.
- `test:gas`: Runs your contract tests and reports the gas usage of each function call. This is useful for optimizing your contracts to use less gas.
- `copy`: Copies the compiled contract artifact (which includes the ABI and bytecode) to a given location. It's used to copy the ABI to the backend.
- `copy:types`: Copies the TypeChain types (TypeScript typings for your contracts) to a given location.
- `deploy:goerli`: Deploys your contracts to the Goerli testnet using a deployment script.
- `deploy:mainnet`: Deploys your contracts to the Ethereum mainnet using a deployment script.
- `deploy:local`: Deploys your contracts to a local Ethereum network (Hardhat Network you can run with the next script) using a deployment script.
- `local-node`: Starts a local Ethereum node using Hardhat Network. This is useful for local development and testing.

## Contract Structure

The contract is based on the `AccessControl` contract from OpenZeppelin, to make it easy to have different roles. So far the only one used is the admin role, similar to an `Owned` contract.

### Events

The contract emits three types of events:

- `BetPlaced`: Emitted when a new bet is placed. It includes the type of bet (`betType`), the wager amount (`wager`), the contract length (`contractLength`), and the bet index (`betIndex`).

- `BettorAdded`: Emitted when a new bettor is added to a bet. It includes the bettor's address (`address`), the bet index (`betIndex`), the wager amount (`wager`), and the betting group they belong to (`bettingGroup`).

- `BetSettled`: Emitted when a bet is settled. It includes the initiator (`initiator`), the groups of bettors (`firstBettorsGroup`, `secondBettorsGroup`), the type of bet (`betType`), the winners (`winners`), and the payouts (`payouts`).

- `BetVoided`: Emitted when a bet is voided. It includes the index of the bet (`betIndex`), the address of the initiator of the bet (`initiator`), and the type of the bet (`betType`).

- `BetClosed`: Emitted when a bet is closed. It includes the index of the bet (betIndex), the address of the initiator of the bet (`initiator`), the array of bettors in the first group (`firstBettorsGroup`), the array of bettors in the second group (`secondBettorsGroup`), and the type of the bet (`betType`).

- `BetApproved`: Emitted when a bet is approved. It includes the index of the bet (`betIndex`), the address of the initiator of the bet (`initiator`), and the type of the bet (`betType`).

More events could be added as the project evolves.

### Methods

Here's a detailed description of each method in the SigmaZero contract:

- `constructor()`: Called when the contract is first deployed. It grants the DEFAULT_ADMIN_ROLE to the account that deploys the contract.

- `placeBet(address tokenAddress, uint32 contractLength, BetType betType, uint wager)`: Allows a user to place a bet. It increments the betCount, creates a new Bet struct, adds the bet initiator to the first bettors group, and emits a BetPlaced event.

- `setBetValue(uint betIndex, uint value)`: Allows an admin to set the value of a bet. It checks if the bet exists, if it's not expired, and if it's initiated. It then sets the value and changes the status to Approved.

- `voidBet(uint betIndex)`: Allows an admin to void a bet. It checks if the bet exists, if it's not settled, and if it's initiated. It then changes the status to Voided and refunds the wagers to the bettors.

- `closeBet(uint betIndex)`: Allows an admin to close a bet. It checks if the bet exists, if it's not expired, and if it's approved. It then changes the status to Close.

- `addBettor(uint betIndex, uint bettingGroup, uint wager)`: Allows a user to join a bet. It checks if the bet exists, if it's not expired, if it's not settled, if it's not closed, and if it's approved. It then adds the bettor to the specified betting group and emits a BettorAdded event.

- `calculateResultsAndDistributeWinnings(uint betIndex, uint value)`: Allows an admin to settle a bet. It checks if the bet exists, if it's not expired, and if it's not settled. It then calculates the winners and their payouts, transfers the winnings, changes the status to Settled, and emits a BetSettled event.

The contract also has several modifier methods that are used to check conditions before executing a method:

- `betExists(uint betIndex)`: Checks if the bet exists.
- `betNotSettled(uint betIndex)`: Checks if the bet is not settled.
- `betApproved(uint betIndex)`: Checks if the bet is approved.
- `betInitiated(uint betIndex)`: Checks if the bet is initiated.
- `betNotExpired(uint betIndex)`: Checks if the bet is not expired.
- `betNotClosed(uint betIndex)`: Checks if the bet is not closed.
- `onlyAdmin()`: Checks if the caller is an admin.

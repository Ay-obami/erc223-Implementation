# Design Note — Option D: ERC-223 Token Standard

## 1. ERC and implemented scope

This submission implements the scoped subset of **ERC-223: Token with transaction handling model**.

Primary specification: https://eips.ethereum.org/EIPS/eip-223  
Ethereum Magicians discussion: https://ethereum-magicians.org/t/erc-223-token-standard/12894

The implementation covers:

- ERC-223 token metadata and balance queries: `totalSupply`, `name`, `symbol`, `decimals`, and `balanceOf`.
- Both ERC-223 transfer overloads:
  - `transfer(address _to, uint256 _value)`
  - `transfer(address _to, uint256 _value, bytes calldata _data)`
- The ERC-223 `Transfer(address,address,uint256,bytes)` event.
- Contract-recipient detection using code size (`address.code.length`).
- Mandatory `tokenReceived(address,uint256,bytes)` callback for contract recipients.
- Normal transfers to externally owned accounts (addresses with no code).
- A compliant receiver, a contract with no ERC-223 hook, and a receiver that explicitly rejects transfers by reverting.

The assignment is intentionally limited to the transfer/receiver safety model. It does not add ERC-20 allowances (`approve` / `transferFrom`), freezing, admin force-transfers, pausing, or other behavior that ERC-223 does not require for this scope.

## 2. Mapping code to the published specification

### `totalSupply`, `name`, `symbol`, `decimals`, `balanceOf`

Spec section: **Specification → Token contract → Token Methods**  
https://eips.ethereum.org/EIPS/eip-223#token-methods

`ERC223Token.sol` implements the query functions with the signatures and meanings described by the EIP. `name`, `symbol`, and `decimals` are optional in ERC-223, but are included because they make the example token easier to inspect and defend live.

### `transfer(address,uint256)`

Spec section: **Specification → transfer(address, uint)**  
https://eips.ethereum.org/EIPS/eip-223#transferaddress-uint

The function moves the balance normally when `_to` has no deployed code. If `_to` has code, the token invokes `tokenReceived`. The callback happens after token balances are updated. If the recipient does not implement a callable receiver hook, the external call reverts and EVM transaction atomicity rolls the balance changes back.

### `transfer(address,uint256,bytes)`

Spec section: **Specification → transfer(address, uint, bytes)**  
https://eips.ethereum.org/EIPS/eip-223#transferaddress-uint-bytes

This overload behaves the same way while forwarding `_data` to the recipient. The data is also included in the ERC-223 transfer event.

### `Transfer(address,address,uint256,bytes)`

Spec section: **Specification → Events → Transfer**  
https://eips.ethereum.org/EIPS/eip-223#transfer

The event uses the four fields required by ERC-223, including the attached `bytes` payload.

### `tokenReceived(address,uint256,bytes)`

Spec section: **ERC-223 Token Receiver → Receiver Methods**  
https://eips.ethereum.org/EIPS/eip-223#receiver-methods

`ExampleERC223Receiver` implements the exact hook and returns the published selector/magic value `0x8943ec02`. It also verifies `msg.sender` is the expected token contract. This matters because the EIP notes that the hook can be manually called and that `msg.sender` inside the hook is the token contract, while `_from` is the original token sender.

## 3. Hardest design decisions

### Decision 1 — Use the current `tokenReceived` hook, not older `tokenFallback` examples

ERC-223 has a long history and older articles and code examples frequently use `tokenFallback`. The current Final EIP specifies `tokenReceived(address,uint256,bytes)` and gives the selector `0x8943ec02`. I used the current published interface rather than copying an older draft. This is important for spec fidelity because the assignment is graded against the published specification, not historical variants.


### Decision 2 — Let a receiver reject by reverting instead of inventing extra token behavior

The receiver function is specified to return `0x8943ec02` after handling a transfer. However, the token-side transfer requirements say to invoke `tokenReceived`, and the EIP's reference token implementation does not inspect the returned `bytes4`. I therefore do not add a new token-side rule that rejects an arbitrary non-magic return value. A receiver rejects a transfer by reverting, which automatically reverts the token transfer too. The compliant example still returns the required `0x8943ec02` value.

This choice keeps the token close to the normative transfer behavior and the EIP reference implementation while still satisfying the assignment requirement that an intended receiver can reject an incoming transfer.

## 4. ERC-20 failure mode prevented

The concrete ERC-20 problem is **accidental direct transfer to a contract that is not designed to recognize that transfer**.

Example: suppose a user wants to deposit 100 ERC-20 tokens into a vault. The vault expects the user to call a `deposit` function, typically after an `approve`, so it can execute `transferFrom` and update an internal record such as `deposits[user]`. If the user instead calls the ERC-20 token's `transfer(vault, 100)`, the ERC-20 token can successfully reduce the user's token balance and increase the vault address's balance without calling the vault. The vault therefore never executes its accounting logic and may have no recovery function for those tokens. From the user's perspective, the 100 tokens are stuck even though the ERC-20 transfer itself succeeded.

ERC-223 prevents this class of mistake at the transfer layer. When the destination has contract code, the token must call `tokenReceived`. A contract that is not prepared to receive ERC-223 tokens has no compatible hook, so the transaction reverts and the user keeps the tokens. A prepared receiver can also inspect the sender, amount, attached data, and token contract, then either accept the transfer or reject it by reverting.

This is the central safety property demonstrated by `testRevertWhenContractDoesNotImplementHook` and `testRevertWhenReceiverRejectsTransfer`.

## 5. AI use disclosure

AI (ChatGPT) was used to help draft the Solidity contracts, generate candidate Foundry tests, compare the implementation against the current ERC-223 EIP, and identify edge cases for the live defense.

The AI output was not treated as authoritative. During review against the current specification, older ERC-223 material using `tokenFallback` was rejected in favor of the current `tokenReceived` interface. Generic assignment examples involving frozen addresses and admin force-transfers were also rejected because those behaviors are not part of this ERC-223 scope. The final design follows the current published transfer and receiver sections, and the tests focus on ERC-223-specific behavior: EOA transfers, required contract callbacks, callback rejection, state rollback, callback ordering, data forwarding, and insufficient balances.


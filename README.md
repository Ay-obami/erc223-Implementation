# Option D — ERC-223 Token Standard

Foundry implementation of the scoped ERC-223 assignment.

## Files

- `src/ERC223Token.sol` — token implementation
- `src/IERC223Receiver.sol` — receiver interface
- `src/ExampleERC223Receiver.sol` — correct receiver
- `src/NonERC223Receiver.sol` — deliberately incompatible receiver
- `src/RejectingERC223Receiver.sol` — compatible hook that deliberately rejects
- `test/ERC223Token.t.sol` — Foundry tests
- `DESIGN_NOTE.md` — 1–2 page design note and AI disclosure

## Run

```bash
forge install foundry-rs/forge-std --no-commit
forge test -vvv
```

## What the tests demonstrate

1. EOA transfers work normally.
2. Contract transfers call `tokenReceived` and forward data.
3. The callback runs after token balance state is updated.
4. A contract without the hook causes a revert and no token loss.
5. A receiver can reject by reverting, rolling back the transfer.
6. Insufficient-balance transfers revert.
7. The published receiver selector is `0x8943ec02`.
8. Fuzzed EOA transfers preserve balances.

Specification: https://eips.ethereum.org/EIPS/eip-223

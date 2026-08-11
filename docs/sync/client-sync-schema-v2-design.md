# Client Sync Schema V2 Design

**Status:** Approved for implementation

**Owner:** Client-app team

**Contract:** [Client–Backend Sync Contract](client-backend-sync-contract.md)

## Goal

Make the Flutter SQLite database the explicit offline-first data model that the backend can mirror for reliable two-way synchronization.

## Decisions

- The app supports VND only. Every monetary value is an integer number of dong; neither SQLite nor the API uses floating-point money.
- Every synchronized record has a client-generated UUID, `idaccount`, `createdAt`, `updatedAt`, and `isDeleted`.
- Conflicts use Last-Write-Wins: the record with the latest `updatedAt` wins.
- A transfer is two linked transactions: `transferOut` on the source wallet and `transferIn` on the destination wallet. Both have the same `transferGroupId`.
- System categories have stable UUIDs, `idaccount = 0`, and `isSystem = true`. They are read-only. User categories are editable and synchronized.
- Receipt images are outside this version. A later attachment/upload design will handle them.
- Synchronization metadata is separate from business data: `sync_outbox` records pending changes and `sync_state` stores the pull cursor.

## Data Model

Business tables are `wallets`, `transactions`, `categories`, `budgets`, `bills`, and `goals`.

`wallets.openingBalance` is the user-entered initial amount. Current wallet balance is derived from active transactions and is never independently synchronized, preventing divergence between a wallet balance field and its ledger.

`transactions.amount` is always positive. Its effect is determined by `entryType`: `income`, `expense`, `adjustment`, `transferOut`, or `transferIn`.

The local-only tables are:

- `sync_outbox`: one pending row per entity (`entityType`, `entityId`), with an idempotency `operationId`, operation type, retry count, and last error.
- `sync_state`: one row per account containing the persistent device identifier and the latest opaque server pull cursor.

Each user mutation updates the business row and outbox row in the same SQLite transaction.

## Synchronization

The client pushes pending outbox rows before pulling remote changes. Backend acknowledgements remove the matching outbox row. A conflict response includes the winning server record; the client replaces the local row and removes the outbox row. The backend must keep an operation-idempotency record per account so retries are safe.

Pull uses an opaque cursor rather than a timestamp. It returns changed and soft-deleted records, a `nextCursor`, and `hasMore`.

## Migration V1 to V2

The Drift schema version changes from 1 to 2.

1. Rebuild money-bearing tables to replace `REAL` columns with integer columns.
2. Rename wallet `balance` semantics to `openingBalance` and migrate existing values with rounding to the nearest dong.
3. Add `createdAt`, using existing `updatedAt` for existing rows.
4. Convert existing transaction types: `thu` to `income`, `chi` to `expense`, and `adjustment` unchanged. A legacy single-row `transfer` becomes `adjustment` because no destination wallet exists to reconstruct a safe pair.
5. Add `transferGroupId`, `isSystem`, `sync_outbox`, and `sync_state`.
6. Queue every existing non-system record for an initial upsert/delete push because no server sync data exists yet.

## Verification

Migration tests must assert that records, rounded money, timestamps, soft deletes, and foreign keys survive V1-to-V2 migration. Repository tests must assert atomic business-write/outbox behavior, transfer-pair invariants, and idempotent outbox retries.

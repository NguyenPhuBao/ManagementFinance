# Client–Backend Sync Contract

**Version:** 2.0 (proposed)  
**Status:** Approved design; implementation pending
**Owner:** Client-app team; backend must implement this contract before real sync is enabled.

## 1. Global conventions

- IDs are UUID v4 strings generated on the client.
- Time values are UTC ISO-8601 strings, for example `2026-08-11T10:00:00.000Z`.
- Money fields are integer VND amounts. PostgreSQL must use `BIGINT` (or an equivalent integer type), never `FLOAT`/`REAL`.
- API JSON uses camelCase; backend database columns may use snake_case.
- `isDeleted = true` is a tombstone. It must be returned by pull and never hard-deleted during normal sync.
- `updatedAt` implements Last-Write-Wins. If server and client values are equal, the operation is idempotently acknowledged.
- The authenticated JWT account is authoritative. Backend rejects a record whose `idaccount` differs from the JWT account, except system categories (`idaccount = 0`) supplied by the server.

## 2. Synchronized entities

Every entity includes `id`, `idaccount`, `createdAt`, `updatedAt`, and `isDeleted` unless noted otherwise.

| Entity | Required business fields | Notes |
|---|---|---|
| `wallet` | `name`, `type`, `openingBalance`, `currency`, `icon`, `colour`, `isDefault` | `openingBalance` is an integer. Current balance is derived from transactions and is not synchronized as a separate field. |
| `transaction` | `walletId`, `categoryId?`, `amount`, `entryType`, `transferGroupId?`, `note`, `occurredAt` | Amount is positive. `entryType` is one of `income`, `expense`, `adjustment`, `transferOut`, `transferIn`. |
| `category` | `name`, `classify`, `icon`, `colour`, `isSystem` | System category: stable UUID, `idaccount = 0`, `isSystem = true`, read-only. |
| `budget` | `categoryId?`, `amount`, `period`, `startDate`, `endDate?`, `note` | `period`: `weekly`, `monthly`, or `yearly`. |
| `bill` | `name`, `amount`, `dueDate`, `isPaid`, `recurrence`, `icon`, `colour`, `note` | `recurrence`: `once`, `weekly`, `monthly`, or `yearly`. |
| `goal` | `name`, `targetAmount`, `currentAmount`, `targetDate`, `icon`, `colour`, `note`, `isCompleted` | Amount fields are integers. |

SQLite must enforce `transactions.walletId -> wallets.id`. `categoryId` is nullable for adjustments and transfers. The client pushes parent entities before dependent ones: categories and wallets, then transactions, then budgets/bills/goals.

### Transfers

A transfer is always a pair of transaction records with the same `transferGroupId`, `amount`, and `occurredAt`:

- Source row: `entryType = "transferOut"`.
- Destination row: `entryType = "transferIn"`.
- The two rows must use different `walletId` values.

## 3. Local-only synchronization tables

`sync_outbox` contains one pending row per `(entityType, entityId)`:

| Column | Meaning |
|---|---|
| `operationId` | UUID idempotency key sent to backend |
| `entityType` | `wallet`, `transaction`, `category`, `budget`, `bill`, or `goal` |
| `entityId` | UUID of the business record |
| `operation` | `upsert` or `delete` |
| `attemptCount` | Number of failed delivery attempts |
| `lastError` | Last error text, nullable |
| `createdAt` | Time of first unsynchronized change |

`sync_state` is keyed by `idaccount` and stores `deviceId`, `pullCursor`, `lastPushedAt`, and `lastPulledAt`.

Neither table is itself synchronized.

## 4. Push API

`POST /api/sync/push` requires a bearer token.

```json
{
  "clientId": "device-uuid",
  "operations": [
    {
      "operationId": "operation-uuid",
      "entityType": "transaction",
      "operation": "upsert",
      "record": {
        "id": "transaction-uuid",
        "idaccount": 1,
        "walletId": "wallet-uuid",
        "categoryId": "cat_food",
        "amount": 150000,
        "entryType": "expense",
        "transferGroupId": null,
        "note": "Ăn trưa",
        "occurredAt": "2026-08-11T10:00:00.000Z",
        "createdAt": "2026-08-11T10:00:00.000Z",
        "updatedAt": "2026-08-11T10:00:00.000Z",
        "isDeleted": false
      }
    }
  ]
}
```

For a `delete` operation, `record.isDeleted` is `true` and the normal entity identifier, ownership, and timestamps are still required.

```json
{
  "acknowledgedOperationIds": ["operation-uuid"],
  "conflicts": [
    {
      "operationId": "other-operation-uuid",
      "entityType": "wallet",
      "serverRecord": {}
    }
  ]
}
```

Backend must persist processed `(idaccount, operationId)` values. Receiving a previously processed operation must return it in `acknowledgedOperationIds` without applying it again.

## 5. Pull API

`GET /api/sync/pull?cursor=<opaque-cursor>` requires a bearer token.

- Omit `cursor` on first pull to request the complete account dataset.
- The cursor is opaque and is issued only by the backend.
- Include tombstones in `changes` so other devices can soft-delete locally.

```json
{
  "changes": [
    { "entityType": "wallet", "record": {} },
    { "entityType": "transaction", "record": {} }
  ],
  "nextCursor": "server-issued-cursor",
  "hasMore": false
}
```

## 6. Conflict and client behavior

1. Client writes the business record and outbox row atomically while offline.
2. Client pushes outbox rows when a connection is available.
3. Backend compares `updatedAt`; the newer record wins.
4. On acknowledgement, client deletes the relevant outbox row.
5. On conflict, client writes `serverRecord` locally and deletes the relevant outbox row.
6. Client pulls until `hasMore` is false, applies every returned record, then persists `nextCursor` atomically.

## 7. Backend implementation requirements

- PostgreSQL mirrors the six business entities and uses UUID primary keys.
- Persist a monotonically ordered change feed/cursor per account; timestamp-only pull is not sufficient.
- Store processed operation IDs per account for idempotency.
- Apply push validation and writes in transactions.
- Do not trust client ownership, balance caches, or local file paths.
- Do not implement receipt-image sync under this contract; file upload will have a separate attachment contract.

## 8. Verification checklist

- Retry the same `operationId` and verify no duplicate record appears.
- Push a soft delete and verify pull returns the tombstone on another device.
- Create a transfer pair and verify both wallets derive the correct balances.
- Resolve an LWW conflict and verify the client adopts the server record.
- Pull paginated changes until the cursor reaches a stable state.
- Reject a payload with an `idaccount` not matching the JWT account.

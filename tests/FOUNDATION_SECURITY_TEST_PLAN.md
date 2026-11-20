# Supabase Foundation Test Plan

No Supabase project credentials or database runtime were provided. Therefore these tests have not been executed against PostgreSQL. The SQL below is intended for a private test project only and must not use production data.

## Authorization tests

- Ordinary user cannot insert/update/delete `public.user_roles`.
- Ordinary user cannot grant `moderator`, `admin`, or `owner` with direct SQL or RPC.
- Only an owner can execute `grant_app_role` and `revoke_app_role`.
- An owner cannot revoke its own final owner role.
- User A cannot read or send messages in a conversation where User A is not an active participant.
- User A cannot insert a comment using another `author_id`.
- User A cannot delete or update another user's comment.
- Moderator can review reports; ordinary user sees only its own report.
- Ordinary user cannot read wallet, ledger, financial transaction, withdrawal or audit tables.
- Public can read only active gift catalogue entries and published public videos.
- Ordinary user cannot create/update active gift catalogue items or commission/FX settings.

## Ledger tests

- Transaction with no ledger entries cannot pass application posting.
- Debits do not equal credits: reject.
- BDT entry posted to USD wallet: reject.
- USD entry posted to USD wallet under BDT transaction: reject.
- Replay of same `idempotency_key`: reject or return existing immutable result according to API function contract.
- Withdrawal gross amount 1000 BDT and commission rate 10%: commission must equal 100.00 BDT.
- Withdrawal commission not equal to gross×rate: reject.
- `provider_confirmed` status without provider reference/confirmation timestamp: reject.
- Public Wallet, Admin Personal Wallet and Commission Balance remain separate.
- No automatic BDT/USD conversion exists.

## Migration tests

- Migration is rerunnable only where expected; use Supabase migration tooling from a fresh database, not a manually edited schema.
- Review the `alter table` profile foreign-key statements for rerun behavior.
- Verify all policies compile and no policy grants direct write access to financial tables.
- Verify role helper functions are `security definer` with empty `search_path` and execute privileges are constrained.
- Verify audit triggers do not expose secret values or write audit events for denied operations.

## Test evidence rule

A successful test report must include database/project identifier (redacted), migration log, test SQL/output, timestamp and the exact passing/failing case. No test is marked passed until it is executed.

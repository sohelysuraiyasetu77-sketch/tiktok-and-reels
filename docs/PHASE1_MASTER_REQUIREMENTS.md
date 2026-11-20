# TikTok & Reels — Phase 1 Master Requirements and Preservation Checklist

This document consolidates requirements explicitly approved in the project conversation. It preserves all known Phase 1 requirements and does not invent the unavailable original numbering/text of the 33-part plan or the detailed 80+ list. Exact original serials remain unverified because those authoritative lists were not found in the repository inspected for this work. Do not remove, downgrade, hide, or defer any approved Phase 1 feature.

- Repository: `sohelysuraiyasetu77-sketch/tiktok-and-reels`
- Implementation branch: `copilot/phase1-mvp`
- Official name: **TikTok & Reels**
- Initial budget: zero; no paid services or billing without explicit owner approval.
- Preserve source, assets, history, and feature behavior. Add capabilities without replacing existing functionality.

## Phase 1 feature preservation matrix

Status is based on the last branch inspection (HTML prototype, minimal README). It is not a completion claim.

| ID | Requirement | Inspected status | Backend/data and acceptance gate |
|---|---|---|---|
| P1-01 | Official name, original branding/logo, protected brand controls | Partial/mismatch: HTML says Solaimanreels; approved logo asset not verified | protected assets/config; verify every client and unauthorized brand-change denial |
| P1-02 | Premium responsive UI, dark/light themes, accessibility | Unverified | client preferences; responsive, accessibility, theme tests |
| P1-03 | Home/bottom navigation | Partial prototype | real routes; direct navigation and refresh tests |
| P1-04 | Full-screen vertical video feed | Partial feed-like HTML, no real videos | feed API and media; real multi-user post retrieval tests |
| P1-05 | For You and Following feeds | Missing | ranking/feed API, follow graph; pagination and authorization tests |
| P1-06 | Swipe, autoplay, pause/resume, smooth playback | Unverified | player and media delivery; device/network lifecycle tests |
| P1-07 | Video upload, validation, processing, thumbnails, resolutions | Missing | authenticated upload, storage adapter/jobs; validation/transcode tests |
| P1-08 | Captions, descriptions, hashtags, sound information/catalog | Missing | metadata/search APIs and rights records; persistence/search tests |
| P1-09 | Storage, CDN, slow-network support, migration | Missing | provider-independent adapter; upload/access/migration/failure tests |
| P1-10 | Registration, login, verification, recovery, account deletion | Missing | Supabase Auth and secure lifecycle; auth/privacy tests |
| P1-11 | Profiles, photos/covers, creator videos, verification | Missing | profile/media schema and APIs; ownership/privacy tests |
| P1-12 | Follow/unfollow and Friends | Missing | social graph and rules; request/block/visibility tests |
| P1-13 | Like/unlike | Browser-only visual counter | persistent authenticated API; cross-client idempotency tests |
| P1-14 | Comments, nested replies, emoji, voice/video replies | Comment placeholder only | comment/media API, RLS/moderation; multi-user access tests |
| P1-15 | Favorite/save, repost, share, emoji reactions | Missing/placeholder share toast | persisted interaction APIs and links; persistence tests |
| P1-16 | Report, Not Interested, block, moderation | Missing | report queue/enforcement; moderator and abuse tests |
| P1-17 | Username/video/hashtag/sound search and Discover/trending | Missing | search API/index; filters/rate-limit tests |
| P1-18 | Inbox and direct messaging | Missing | conversations/messages, RLS/Realtime; participant isolation tests |
| P1-19 | Notifications | Missing | persistent notification API; recipient/read-state tests |
| P1-20 | Groups and Channels | Missing | membership/content APIs; role/membership tests |
| P1-21 | Settings and privacy | Missing | server-enforced preferences; effective-policy tests |
| P1-22 | LIVE host/viewer, interactions and management | Missing | replaceable signaling/media adapters; real session tests |
| P1-23 | LIVE beauty filters and moderation | Missing | client capability and moderation controls; device/safety tests |
| P1-24 | Original Gift Catalogue: Bengali names, original artwork, values, gift history and LIVE display | Missing; do not implement a Star gift system | catalog and transactional ledger; no copied platform artwork; gift-history and LIVE tests |
| P1-25 | User Wallet in BDT and USD with Bengali presentation | Missing | currency-segregated ledger/API; reconciliation and locale tests |
| P1-26 | Admin Personal Wallet in BDT and USD | Missing | separate owner ledger; isolation/reconciliation tests |
| P1-27 | Public Wallet and Commission Balance, separately by currency | Missing | separate ledgers; no cross-class/currency double count |
| P1-28 | Gift commission default 5% | Rule approved; no implementation | configurable rate; calculation basis unresolved, no inference |
| P1-29 | Withdrawal commission 10% of gross withdrawal | Rule approved; no implementation | immutable transaction calculation and audit tests |
| P1-30 | Creator monetization/applications/approval | Missing; criteria unresolved | configurable policy; approval/audit tests |
| P1-31 | Withdrawal request/review/payment confirmation | Missing | state machine and provider confirmation; never fake completion |
| P1-32 | Admin panel, RBAC, Admin 2FA, AI Control Chat | Missing | admin APIs, least privilege and audit; AI provider not approved |
| P1-33 | Security/fraud, database/backup, web deployment, native Android APK/AAB, tests and handover | Missing/unverified | secure backend, CI, restore tests, owner signing and verified deployment |

## Additional approved requirements

Preserve: social graph; Friends; Groups; Channels; inbox/moderated messaging; notifications; complete Admin Control Panel; role-based administration; separate Admin Personal Wallet, Public Wallet, Commission Balance; business accounting; append-only transaction history; audit trails; internationalization; responsive web/native Android; provider-independent media/LIVE/payment adapters; scalable migrations; account deletion/privacy; UGC reporting/blocking; secure owner-controlled signing; branded APK distribution; HTTPS; backups/recovery.

## Original Gift Catalogue and dual-currency rules

- Do **not** implement Facebook-like Star Gifts or Star balances/conversion.
- Use TikTok & Reels' original gift catalogue: flowers, fruits and other original emoji/icon gifts. Each gift has Bengali name, project-owned original design/artwork, price and persistent gift history. Do not copy another platform's artwork, brand or distinctive gift design.
- Sending, receiving, LIVE display and creator gift earnings must be persisted backend/database operations, not UI-only actions.
- Gift records must identify gift, price snapshot, currency, sender, recipient, time, LIVE/video context and ledger references for audit.
- User Wallet and Admin Accounting support BDT and USD. Bengali-language wallet, gift, income, withdrawal and transaction history are required. Show the two currencies distinctly.
- Keep separate currency-denominated transaction IDs/ledger entries and prevent duplicate earnings across currencies. Never assert a converted amount unless an owner-approved rate, source and effective time exist.
- Commission defaults remain unchanged: Gift Commission 5% (calculation basis unresolved); Withdrawal Commission 10% of gross withdrawal. Admin can configure the rates independently for future transactions.
- Admin Personal Wallet, Public Wallet and Commission Balance stay separate in every currency.
- Never mark an external payment/withdrawal completed without provider-confirmed evidence. No payment provider is authorized by this requirement.

## Financial invariants

Transactions are uniquely identified, idempotent and auditable. Amounts are positive, currency-explicit, and recorded in the appropriate separated ledger. Do not invent gift prices/catalogue values, conversion rates, commission basis, payout provider, eligibility, tax, or KYC rules. Unknown business rules remain fail-closed/configurable until owner decision.

## Modular architecture direction

- Owner-approved initial backend: Supabase Free Tier (PostgreSQL, Auth, Realtime), subject to verifying current quota/availability; no billing activation.
- RLS is required for user-scoped data; service-role secrets stay server-side only.
- Supabase Free Storage behind provider-independent media interfaces using stable asset IDs and provider-specific adapters; no unlimited storage/CDN claims.
- Replaceable adapters for media, video processing, LIVE, payments, notifications and search.
- Ledger-based financial state, segregated by wallet class and currency; transactional, idempotent and auditable.
- Native Android: Kotlin/Jetpack Compose, stable owner-approved package ID, release signing only from owner-controlled secrets.

## Unresolved decisions / external setup

1. Exact original 33-part and 80+ numbered source lists were not found; exact original serials cannot be asserted from this consolidation.
2. Exact original gift catalogue names/prices and whether the earlier count of 28 still applies after replacing Star gifts.
3. Gift Commission 5% calculation basis.
4. BDT/USD exchange rate, source and effective-time policy; no conversion until approved.
5. Monetization eligibility, withdrawal/payout policy/provider, currencies accepted for each action, and legal/KYC/tax rules.
6. Content visibility defaults and public/follower/friend/private access interaction.
7. Friends/groups/channel membership and invitation rules where not specified.
8. LIVE protocol and beauty-filter capability achievable without paid service.
9. Owner-controlled Supabase project/deployment configuration.
10. Approved logo asset and Android package ID if absent in source.

Do not block independent safe implementation on unresolved decisions; dependent financial behavior must fail closed until approved.

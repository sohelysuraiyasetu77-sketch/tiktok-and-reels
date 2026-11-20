# TikTok & Reels — Foundation roadmap

This roadmap supplements the Phase 1 Master Requirements and does not replace, reduce, disable, or move any approved Phase 1 feature to Phase 2. Moderation, LIVE, original Gifts, Social, Wallet, Monetization, Accounting, and Admin remain Phase 1.

## Foundation sequence

1. Preserve/inventory branch baseline, original HTML/assets/history and feature traceability.
2. Use owner-controlled Supabase Free Tier (PostgreSQL, Auth, Realtime) only after project setup and free-quota verification; billing stays disabled.
3. Apply reviewed, versioned migrations for identity/roles, media/videos, social graph/Friends/Groups/Channels, comments/reports/moderation, messaging/notifications, LIVE, original Gifts, separate multi-currency ledgers, Admin and audit.
4. Add least-privilege RLS/server authorization and negative cross-user access tests before enabling client writes.
5. Keep media, LIVE, payment, notification, processing, and search providers behind replaceable interfaces. No client-supplied role, currency conversion, amount, commission, or payment status is trusted.
6. Implement and test every Phase 1 feature iteratively, including moderation, LIVE, and original Gifts.
7. Keep unresolved rules fail-closed: gift values/prices and count; 5% gift-commission basis; BDT/USD rate/source/effective time; eligibility/payout/payment provider; visibility and membership rules.
8. Build native Kotlin/Jetpack Compose Android with owner-approved stable package ID. Signing secrets remain owner-controlled and out of source.
9. Add CI, free HTTPS deployment where actually available, and verified APK/AAB/download publication. No completion claims without evidence.
10. Test API/RLS, abuse controls, financial reconciliation, restore, accessibility, mobile/desktop and Android; create a PR to `main` only after review, never auto-merge.

## Owner-approved Original Gift and Wallet rules

- No Facebook-style Star gift system.
- Create original project-owned emoji/icon gifts (flowers, fruits and other suitable gifts), Bengali names, original artwork, approved prices, and persistent history.
- Gift send/receive, LIVE presentation, and creator earnings are real persisted backend/database operations.
- User and Admin Accounting support separately labeled BDT and USD and Bengali display.
- Do not infer exchange rates; any conversion requires an owner-approved rate, source, and effective time.
- Preserve 5% Gift Commission (basis unresolved) and 10% of gross Withdrawal Commission.
- Admin Personal Wallet, Public Wallet, and Commission Balance stay separate for each currency.

## Cost/publication constraints

No paid service, subscription, domain, server, API, database, storage, CDN, or billing without explicit approval. Verify free-tier limits at use time. Never claim a test, deployed URL, signed APK, or operational feature without actual evidence.

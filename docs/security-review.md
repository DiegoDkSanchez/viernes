# Prototype Firestore rules review

## Schema and queries

Only `shops/main/menu` and `shops/main/orders` are accessible. Menu queries sort by name. Orders filter by status and sort by createdAt descending; the composite index is committed. Domain/data models are described in README and the rules header. Google authentication alone grants shared access as explicitly requested, including customer names/addresses. No private Google email/token/profile documents are stored. No membership or administrator approval is required; member paths have no client access.

## Attack review

The executable emulator suite covers unauthenticated list/read and write denial; Google-provider restriction; membership-path denial; second-user shared reads and status updates; immutable creator and creation time; unknown fields; missing required fields; invalid types; oversized strings/lists; duplicate and non-string options; invalid status; forged timestamps; negative/out-of-range quantities/prices; arithmetic mismatch; and unrelated collection/shop paths. Menu creates and updates use the same validator. Orders use the same full validator on create/update with explicit content/status update whitelisting. Any Google-authenticated user may delete orders. Signed-out users and non-Google providers cannot read or mutate data. The maximum legal nested payload is tested positively so denial tests cannot mask an unusable validator.

No public user profiles, counter increments, user-supplied resource paths, or nested subcollections are exposed. Those attack categories are not applicable. `shops/main` deliberately needs no parent document; Google sign-in is the access check. All unlisted paths default to deny. Content edits retain status and delivery time; status transitions validate timestamps. Client order creation retries use a stable document ID and transaction.

## Limits requiring operational review

These are prototype rules, not a guarantee of exhaustive security. All Google-authenticated users can create customer orders and manage menu prices by design. Order line prices/options are snapshots validated for shape, bounds, and sum, not against current catalog records. Use a trusted backend to impose authoritative pricing if this becomes a payment system. Rules cannot remove data already cached on a user's device. There is intentionally no membership-based revocation. The rules are compiled and tested in the emulator before deployment. Real device Google sign-in and iOS registration/configuration still require verification.

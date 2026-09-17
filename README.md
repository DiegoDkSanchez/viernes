# Burger Pedidos / Viernes

Flutter order manager styled after the supplied Burger Pedidos reference. Spanish is the default language; Settings switches to English. All approved Google users share the same menu and orders.

## Structure

- `lib/features/*/domain`: framework-independent entities, repository interfaces, and use cases.
- `lib/features/auth/data`: Firebase / Google authentication adapter.
- `lib/features/orders/data`, `lib/features/catalog/data`: Firestore adapters.
- `lib/features/*/presentation`: screens, form state, loading/errors, and button actions.
- `lib/core`: dependency injection, theme, and shared widgets.
- `lib/l10n`: Spanish/English UI strings, localized USD formatting and dates.
- `lib/main.dart`: Firebase bootstrap and composition root.

UI dependencies point toward domain interfaces. Firestore serialization and timestamps stay in the data layer. Repositories are injected through `AppServices`; widget/domain tests use in-memory fakes.

| Action | Use case |
| --- | --- |
| Continue with Google | SignInWithGoogle |
| Pending / delivered tab | WatchOrders |
| Save order | CreateOrder |
| Mark delivered | MarkOrderDelivered |
| Still pending | ReopenOrder |
| Load menu | WatchMenu |
| Add / edit / deactivate product | SaveMenuItem |
| Sign out | SignOut |

Quantity/option controls edit a local draft; opening screens and switching language are presentation actions. Saving is the domain boundary. Orders include immutable product/price/option snapshots, customer name/address, integer-cent totals, Google creator UID/name, and server timestamps. Delivery is reversible. Stable draft IDs and transactions avoid duplicate orders on retries. Transactions require connectivity; failed saves retain the draft.

## Firebase setup

The existing project is `mycv-e9df6`, Standard edition database `(default)`, with Android package `xyz.devkraken.viernes`. Android uses the existing `android/app/google-services.json` and the Google Services Gradle plugin.

1. In Firebase Authentication, enable Google as a sign-in provider and set its support email.
2. Register the SHA-1 and SHA-256 fingerprints of the Android signing certificate in Firebase Project Settings. Download the refreshed `google-services.json` if OAuth configuration changes. The current file contains a web OAuth client; device sign-in still needs validation with the app's signing certificate.
3. Sign in, then obtain that user's UID from Firebase Authentication. In Firestore Console create `shops/main/members/<UID>` with any administrator-managed metadata (for example `active: true`). **Document existence is the grant**; delete the document to revoke access. Setting `active: false` does not revoke it. Repeat for every teammate. No client can grant membership. The `shops/main` parent document is not required.
4. Deploy the reviewed rules and index:
   ```sh
   firebase deploy --only firestore:rules,firestore:indexes --project mycv-e9df6
   ```
   The root rules currently deny all other collections, matching the previous expired/default-deny rules. Review before deployment if this existing Firebase project also serves another app. Index construction can take several minutes.
5. Run `flutter pub get` and `flutter run`. After login, open Settings and add products, prices, and optional ingredients. No sample customer data is inserted into production.

The rules/index have **not** been deployed by this change. Memberships and Authentication settings are not provisioned by the client.

### iOS

There is no iOS app registered in the Firebase project yet. Register the Runner bundle ID and configure it with FlutterFire / Firebase, add `GoogleService-Info.plist` to the Runner target, and add its `REVERSED_CLIENT_ID` as an iOS URL scheme. Verify Google sign-in on a Mac/device. The shared Dart implementation supports iOS, but native configuration and an iOS build are still required. See [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup) and [Google authentication](https://firebase.google.com/docs/auth/flutter/federated-auth).

## Data and limits

- `shops/main/menu/{id}`: name, priceCents, options, active. Any approved teammate can manage the catalog. Deactivation hides a product from new orders without altering existing orders.
- `shops/main/orders/{id}`: name, address, lines, totalCents, creatorId, creatorName, status, createdAt, deliveredAt.
- Maximum 4 distinct products per order, 99 units per product, and 8 optional ingredients per product. These explicit limits keep nested validation within Firestore's rule expression budget. Selected options apply to all units of that product; options have no surcharge.
- Catalog content is entered by the team; language switching translates UI, not user-entered product names.
- Prices use USD cents, appropriate for the supplied reference. Locale selection lasts for the app session.
- Menu snapshots are trusted staff input, not a payment/pricing authority; rules validate shape and arithmetic but do not compare historical snapshots to the current catalog.
- Order lists stream all records in the selected status. Add cursor pagination or date filtering before accumulating a large delivery history.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
npm ci --prefix tools/rules-tests
firebase emulators:exec --config firebase.emulator.json --only firestore --project demo-viernes 'npm test --prefix tools/rules-tests'
```

The Firestore suite compiles the rules in an isolated demo emulator, tests two-user collaboration, rejects outsiders and self-granted access, checks delivery/reopening, malformed/nested data, immutable fields, forged creator identities, totals, and maximum-size valid orders. See `docs/security-review.md` for the review scope.
# viernes

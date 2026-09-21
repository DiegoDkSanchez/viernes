# Burger Pedidos / Viernes

Flutter order manager styled after the supplied Burger Pedidos reference. Spanish is the default language; Settings switches to English. All Google-authenticated users share the same menu and orders.

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
| Edit order | UpdateOrder |
| Delete order | DeleteOrder |
| Mark delivered | MarkOrderDelivered |
| Still pending | ReopenOrder |
| Load menu | WatchMenu |
| Add / edit / deactivate product | SaveMenuItem |
| Sign out | SignOut |

Quantity/option controls edit a local draft; opening screens and switching language are presentation actions. Saving is the domain boundary. Orders include saved product/price/option snapshots, customer name/address, integer-cent totals, Google creator UID/name, and server timestamps. Original creator and creation time are immutable. Users can edit customer details and items on either tab or delete an order after confirmation. Editing existing items preserves their saved prices, even when the menu changes. Content updates preserve the live delivery status. Delivery is reversible. Stable draft IDs and transactions avoid duplicate orders on retries. Transactions require connectivity; failed saves retain the draft.

## Firebase setup

The existing project is `mycv-e9df6`, Standard edition database `(default)`, with Android package `xyz.devkraken.viernes`. Android uses `android/app/google-services.json` and the Google Services Gradle plugin.

After cloning on a new computer, place `google-services.json` (Android) and/or
`GoogleService-Info.plist` (iOS) inside `firebase_config/`, then run:

```sh
python3 firebase_config/setup.py
```

The script copies each supplied file into its native project directory. These
files are ignored by Git and must be supplied separately on each computer.
See [Firebase configuration instructions](firebase_config/README.md).

1. In Firebase Authentication, enable Google as a sign-in provider and set its support email.
2. Register the SHA-1 and SHA-256 fingerprints of the Android signing certificate in Firebase Project Settings. Download the refreshed `google-services.json` if OAuth configuration changes. This machine’s debug SHA-1 and SHA-256 fingerprints are registered, and the JSON contains both Android and web OAuth clients. A different development machine or release/Play signing certificate needs its own registered fingerprints. Device sign-in still needs validation.
3. Sign in with Google. No administrator approval, role, or membership document is required. Every Google-authenticated user can read, create, edit, deliver, reopen, and delete shared orders, and manage the menu.
4. Deploy the reviewed rules and index:
   ```sh
   firebase deploy --only firestore:rules,firestore:indexes --project mycv-e9df6
   ```
   The root rules currently deny all other collections, matching the previous expired/default-deny rules. Review before deployment if this existing Firebase project also serves another app. Index construction can take several minutes.
5. Run `flutter pub get` and `flutter run`. After login, open Settings and add products, prices, and optional ingredients. No sample customer data is inserted into production.

The access rules are deployed to the configured Firebase project after emulator validation. The client does not provision Authentication settings.

### iOS

There is no iOS app registered in the Firebase project yet. Register the Runner bundle ID and configure it with FlutterFire / Firebase, add `GoogleService-Info.plist` to the Runner target, and add its `REVERSED_CLIENT_ID` as an iOS URL scheme. Verify Google sign-in on a Mac/device. The shared Dart implementation supports iOS, but native configuration and an iOS build are still required. See [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup) and [Google authentication](https://firebase.google.com/docs/auth/flutter/federated-auth).

Orders support an optional delivery clock time, defaulting to “As soon as possible.”
The time is stored as local minutes since midnight (no date or timezone conversion).
Deploy the updated `firestore.rules` before using this field against Firebase.

## Data and limits

- `shops/main/menu/{id}`: name, priceCents, options, active. Any Google-authenticated user can manage the catalog. Deactivation hides a product from new orders without altering existing orders.
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

The Firestore suite compiles the rules in an isolated demo emulator, tests two-user collaboration without memberships, rejects signed-out access and non-Google providers, checks delivery/reopening, malformed/nested data, immutable fields, forged creator identities, totals, and maximum-size valid orders. See `docs/security-review.md` for the review scope.
# viernes

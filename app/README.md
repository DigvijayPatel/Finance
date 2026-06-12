# Finance — Flutter Android app

Personal finance tracker backed by Supabase.

## Modules

| Module | What it does |
| --- | --- |
| **Expenses** | Add / edit / delete expenses with category, payment method (UPI, card, cash, …), date and note. Grouped by day with month totals; realtime sync. |
| **Budget** | Overall and per-category monthly budgets with progress bars (amber at 80%, red when exceeded). |
| **Credit card cycle** | Per-card billing cycle tracking: current cycle window, spend this cycle, last statement amount, due date countdown and limit utilisation. |
| **Overspending alerts** | A Postgres trigger raises an alert the moment month-to-date spend crosses 80% ('warning') or 100% ('exceeded') of any budget. Alerts arrive in the app live via Supabase Realtime, with an unread badge. |
| **Insights** | 6-month spend trend, category breakdown donut, per-day average, month-over-month change and top expenses. |

## Backend setup (Supabase)

1. Create a project at [supabase.com](https://supabase.com).
2. Open the SQL editor and run [`../supabase/migrations/0001_init.sql`](../supabase/migrations/0001_init.sql).
   This creates the tables (`categories`, `expenses`, `budgets`, `credit_cards`, `alerts`),
   row-level security policies, the overspend-alert trigger, default categories for
   new users, and enables Realtime.
3. Under **Authentication → Providers**, make sure Email is enabled.

## Running the app

```bash
cd app
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Build a release APK the same way:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

The anon key is safe to embed in the client: all data access is enforced by
row-level security on the server.

## Tests

```bash
cd app && flutter test
```

## Notes

- Application id is `com.dpatel.finance` (`android/app/build.gradle`); change it before publishing.
- Release builds are debug-signed for now — add a `key.properties` signing config before shipping to Play.
- Launcher icons are generated placeholders; replace `android/app/src/main/res/mipmap-*/ic_launcher.png` with real artwork (e.g. via `flutter_launcher_icons`).

## Architecture

- **State**: Riverpod. Reads come from Supabase Realtime streams (`lib/data/streams.dart`), writes go through `lib/data/mutations.dart`; month filtering happens client-side since volumes are small.
- **Structure**: `lib/features/<module>/` per module, shared models in `lib/models/`, formatting and env in `lib/core/`.
- **Alerts** are produced server-side (see the `check_overspend` trigger in the migration) so they fire exactly once per budget per month regardless of which client inserts the expense.

# Money King

A polished offline-first Flutter expense tracker for everyday personal finance workflows. Money King helps users record income and expenses, organize spending by category, review budgets, and protect access with a local app lock.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Offline--First-0F172A?style=for-the-badge" alt="Offline First" />
  <img src="https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
</p>

## Highlights

- **Transaction tracking** for income and expenses with clean add/edit flows.
- **Budget management** to organize limits and monitor spending habits.
- **Category-based organization** for clearer financial breakdowns.
- **Charts and insights** powered by `fl_chart` for quick visual summaries.
- **Offline-first storage** using local persistence for fast everyday access.
- **App lock support** with local authentication for privacy-focused use.
- **Cloud ledger service** structure for Supabase-backed sync workflows.
- **Dark, mobile-first UI** designed for a premium personal finance experience.

## Tech Stack

| Area | Tools |
| --- | --- |
| App framework | Flutter, Dart |
| State management | Provider |
| Local storage | Shared Preferences |
| Charts | fl_chart |
| Authentication/privacy | local_auth, crypto |
| Cloud-ready backend | Supabase Flutter |
| Formatting/utilities | intl, uuid |

## Project Structure

```text
lib/
├── backend/          # Supabase backend integration
├── models/           # Account, budget, category, settings, transaction models
├── providers/        # App-level state management
├── screens/          # Root shell, lock screen, add/edit transaction UI
├── services/         # Local storage and cloud ledger services
├── theme/            # App theme and styling
└── main.dart         # Application entry point
```

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Analyze project health
flutter analyze
```

If Supabase sync is enabled in your environment, add the required keys to `.env` before running cloud-backed flows.

## Roadmap Ideas

- Recurring transaction templates
- Export reports to CSV/PDF
- Monthly financial summaries
- Multi-device sync improvements
- Budget alerts and smart insights

## Repository Topics

`flutter` · `dart` · `expense-tracker` · `budget-tracker` · `personal-finance` · `mobile-app` · `cloud-sync` · `biometric-auth`

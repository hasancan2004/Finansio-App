# Finansio

Finansio is a personal finance tracking application built with Flutter.

The app allows users to manage income, expenses, budgets, recurring transactions and financial summaries locally on the device. It was developed with a focus on offline usage, maintainable architecture and a simple user experience.

## Features

- Income and expense tracking
- Budget management and budget limit notifications
- Monthly financial summaries
- Recurring transactions
- Custom categories
- PDF report generation
- Daily and weekly local notifications
- Light and dark theme support
- Accent color customization

## Screenshots

<img width="250" alt="Home Screen" src="https://github.com/user-attachments/assets/d870a771-027f-4660-964d-7105ffa3b009" />
<img width="250" alt="Categories" src="https://github.com/user-attachments/assets/b730fd93-e80e-4b75-a23c-e33ea5279995" />
<img width="250" alt="Reports 1" src="https://github.com/user-attachments/assets/8f7d07e9-6616-4318-b747-4489f17db61f" />
<img width="250" alt="Reports 2" src="https://github.com/user-attachments/assets/1e1a132c-4b1e-4580-b58b-36412bdb5e8e" />
<img width="250" alt="Settings" src="https://github.com/user-attachments/assets/94ae67d6-0d2b-44d0-aa81-4fc435ab435d" />

## Tech Stack

- Flutter
- Dart
- Riverpod
- sqflite
- fl_chart
- flutter_local_notifications
- pdf
- printing

## Architecture

The project follows a Clean Architecture-inspired structure to keep business logic, data access and presentation responsibilities separated.

Main areas include:

- Presentation
- State management
- Domain logic
- Local data layer
- Services

## Data Storage

Finansio is designed as an offline-first application.

Financial data is stored locally using SQLite, allowing the application to work without requiring a constant internet connection.

## Notifications

The application uses local notifications for:

- Budget limit warnings
- Daily reminders
- Weekly financial summaries

## Reports

Users can generate PDF reports for selected periods and share or save them on the device.

## Author

Hasan Can Kula

GitHub: [@hasancan2004](https://github.com/hasancan2004)

## License

This project is licensed under the MIT License.

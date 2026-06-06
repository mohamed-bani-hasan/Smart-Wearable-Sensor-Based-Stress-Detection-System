# Smart Wearable Sensor-Based Stress Detection System

This project is a Flutter mobile application designed to monitor and detect stress levels using wearable sensor data and health-related vitals. It combines a modern user interface with Firebase-based authentication and real-time database support to provide a practical stress monitoring experience for both patients and healthcare professionals.

## What this project does

The app helps users:

- Track stress indicators and vital signs in real time.
- View stress status through an easy-to-read dashboard.
- Receive alerts and monitoring support for abnormal stress levels.
- Provide patient and doctor role-based access for better healthcare management.

## Key features

- Flutter-based cross-platform mobile interface
- Firebase Authentication for secure login and registration
- Firebase Realtime Database for live stress and health data storage
- Patient and doctor dashboards
- Stress level visualization and monitoring
- Clean, responsive UI designed for healthcare applications

## Tech stack

- Flutter
- Dart
- Firebase Auth
- Firebase Realtime Database
- Material Design UI components

## Project purpose

This application aims to make stress detection more accessible and practical by combining wearable sensor data with mobile technology. It is useful for demonstrating how health monitoring systems can support early awareness, continuous tracking, and improved decision-making in stress management.

## Getting started

1. Install Flutter and set up your environment.
2. Run the following command to install dependencies:

   ```bash
   flutter pub get
   ```

3. Start the app:

   ```bash
   flutter run
   ```

## Notes

Before running the app, make sure Firebase is configured correctly in your environment. The project already includes Firebase integration and platform configuration files for Android, iOS, Web, and desktop support.

## Folder overview

- lib/ - Main application code and screens
- lib/screens/ - UI screens for login, dashboard, profile, and doctor views
- lib/services/ - Firebase and health-related logic
- lib/models/ - Data models used by the application
- test/ - App tests


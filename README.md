# SplitTrip 🌍💰  
A production-ready Flutter application for collaborative expense splitting during group trips, built with real-time sync, offline-first support, and clean architecture principles.

SplitTrip demonstrates how to design and ship a complete mobile product with strong architecture, scalable backend integration, and professional engineering practices.

---

## 🚀 Key Highlights

- Real-time collaborative expense tracking using Firebase Firestore  
- Offline-first architecture with automatic background sync  
- Clean architecture (repositories, services, providers)  
- Production-ready authentication and data security  
- Optimized settlement algorithm for minimizing transactions  
- CI-ready structure and testable business logic  

---

## ✨ Features

### 💸 Expense Management
- Add and manage expenses with notes and categories  
- Multi-currency support  
- Flexible split options:
  - Equal split  
  - Percentage split  
  - Custom amount split  

### 👥 Trip & Expense Tracking
- Real-time sync across devices using Firestore  
- Add/remove participants and track their shares  
- Offline-first support with auto-sync  
- Smart settlement to minimize transactions  
- Live balance calculation (who owes whom)  

### 📊 Reports & Export
- PDF export for trip reports  
- Category-wise expense breakdown  
- Clear balance summary for each participant  

### 🔐 Authentication
- Google Sign-In  
- Anonymous login  
- Firebase Security Rules for data protection  

---

## 🏗️ Architecture

Built using Clean Architecture for maintainability and scalability.

```
lib/
├── models/          # Core data models
├── providers/       # Riverpod state management
├── repositories/    # Data access layer (Firestore, Storage)
├── screens/         # UI screens
├── services/        # Business logic (auth, currency, sync)
├── utils/           # Helpers and constants
└── widgets/         # Reusable UI components
```

---

## 🛠 Tech Stack

**Frontend**
- Flutter 3.24+  
- Riverpod (state management)  
- GoRouter (navigation)  

**Backend**
- Firebase Authentication  
- Cloud Firestore  
- Firebase Storage  

**Other**
- PDF generation  
- fl_chart (analytics)  

---

## 📱 Screenshots


| ![Trips](lib\docs\screenshorts\trip.jpg) | ![Expense](lib\docs\screenshorts\expenses.jpg) | ![Expense_detail](lib\docs\screenshorts\expense_detail.jpg) | ![Settlement](lib\docs\screenshorts\settlement.jpg) | ![Pdf_export](lib\docs\screenshorts\pdf_export.jpg) |



## ⚙️ Setup

```bash
git clone https://github.com/SAM389/split-trip.git
cd splittrip
flutter pub get
flutter run
```

Firebase is configured using FlutterFire:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

---

## 🎯 Purpose of This Project

SplitTrip was built to demonstrate:

- End-to-end product development
- Scalable mobile architecture
- Real-time backend integration
- Offline-first design
- Professional code organization and workflows

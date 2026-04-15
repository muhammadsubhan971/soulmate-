# 💕 Soul Mate - AI-Powered Matrimonial App

A professional, aesthetic matrimonial mobile application built with Flutter and Supabase that connects individuals for marriage based on detailed profiles, preferences, and AI-powered matchmaking.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E.svg)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green.svg)

## 🌟 Features

### 🔐 Authentication
- Email & Password authentication
- Secure user sessions
- Role-based access (User/Admin)

### 👤 Complete Profile System
- **Basic Info:** Name, Parents, Age, Gender, Profile Picture
- **Personal Details:** Caste, Religion, Marital Status, Height, Weight
- **Education & Career:** Qualification, Profession, Income
- **Contact & Location:** Phone, Address, City, Country
- **Lifestyle:** Hobbies, Personality Traits, Smoking/Drinking habits
- **Family Background:** Detailed family information

### 🏠 Smart Matching
- Tinder-like card swiping interface
- Daily profile limits based on subscription tier
- **AI-Powered Compatibility Scoring:**
  - Age compatibility
  - Location matching
  - Education & career alignment
  - Lifestyle preferences
  - Overall compatibility percentage

### 💎 Subscription Plans
| Tier | Profiles/Day | Price |
|------|--------------|-------|
| Free | 5 | PKR 0 |
| Silver | 20 | PKR 2,000/month |
| Gold | 50 | PKR 5,000/month + Priority |

### 💬 Real-Time Chat
- Available after mutual match
- Message history
- Read receipts
- Online status indicators

### 🔔 Notifications
- New match alerts
- Likes received
- Profile views
- Mutual matches
- New messages

### 🛠️ Admin Panel
- User management (view, block, delete)
- Profile verification
- Report review system
- Analytics dashboard
- Subscription management

### 🚨 Safety Features
- Report fake/inappropriate profiles
- Admin review system
- Profile blocking
- Identity verification (placeholder)

## 📱 Screenshots

*(Add your screenshots here)*

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Supabase account
- IDE (VS Code / Android Studio)

### Installation

1. **Clone the repository**
   ```bash
   cd soul_mate_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a project at [supabase.com](https://supabase.com)
   - Update credentials in `lib/core/constants/app_constants.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

4. **Set up Database**
   - Go to Supabase SQL Editor
   - Run the schema from `database/schema.sql`

5. **Create Storage Buckets**
   - `profile-images` (Public)
   - `verification-images` (Private)

6. **Run the app**
   ```bash
   flutter run -d chrome  # For web
   flutter run -d chrome --release  # Production build
   ```

## 📦 Project Structure

```
lib/
├── core/
│   ├── constants/          # App constants
│   ├── routes/             # Navigation routes
│   ├── theme/              # App theming
│   └── widgets/            # Common widgets
├── models/                 # Data models
│   ├── user_model.dart
│   ├── match_model.dart
│   ├── message_model.dart
│   ├── notification_model.dart
│   └── report_model.dart
├── screens/
│   ├── auth/               # Login, Register
│   ├── profile/            # Profile creation & view
│   ├── home/               # Home feed
│   ├── chat/               # Messaging
│   ├── subscription/       # Plans & payments
│   ├── notifications/      # Notification center
│   ├── admin/              # Admin panel
│   └── match/              # Matches screen
├── services/               # Supabase services
│   ├── auth/
│   ├── profile/
│   ├── match/
│   ├── chat/
│   └── notification/
└── main.dart               # Entry point
```

## 🎨 Theming

The app uses gender-based theming:
- **Female:** White + Pink (`#FF6B9D`)
- **Male:** White + Blue (`#4A90E2`)
- **Login/Register:** Purple gradient (`#667eea` → `#764ba2`)

Customize colors in `lib/core/theme/app_colors.dart`

## 🤖 AI Matchmaking Algorithm

The compatibility score is calculated based on:

| Factor | Weight |
|--------|--------|
| Age Difference | 20% |
| Location Match | 20% |
| Education Level | 15% |
| Profession | 10% |
| Income Similarity | 10% |
| Lifestyle (Smoking/Drinking) | 15% |
| Marital Status | 10% |

**Score Interpretation:**
- 90-100%: Excellent Match 💕
- 70-89%: Good Match 💖
- 50-69%: Moderate Match 💙
- Below 50%: Low Match 💔

## 🔧 Configuration

### Subscription Limits
Edit `lib/core/constants/app_constants.dart`:
```dart
static const int freeProfileLimit = 5;
static const int silverProfileLimit = 20;
static const int goldProfileLimit = 50;
```

### Payment Integration
Stripe placeholder is set up. Replace with:
- Stripe: `flutter_stripe`
- JazzCash/EasyPaisa: Custom integration

## 🛠️ Development

### Hot Reload
```bash
r  # Hot reload
R  # Hot restart
```

### Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

### Build Commands

**Web:**
```bash
flutter build web --release
```

**Android:**
```bash
flutter build apk --release
flutter build appbundle --release  # For Play Store
```

**iOS:**
```bash
flutter build ios --release
```

## 📋 Database Schema

Tables created in Supabase:
- `profiles` - User profiles
- `matches` - Like/skip/match data
- `messages` - Chat messages
- `notifications` - User notifications
- `reports` - User reports
- `subscriptions` - Payment history
- `verifications` - Identity verification

Row Level Security (RLS) policies ensure data privacy.

## 🔐 Security

- Supabase Auth for secure authentication
- Row Level Security (RLS) on all tables
- Secure password storage (handled by Supabase)
- Data encryption in transit (HTTPS)
- Protected API keys

## 📝 Roadmap

- [ ] Video call integration
- [ ] Push notifications (Firebase)
- [ ] Payment gateway (Stripe/JazzCash)
- [ ] AI image verification
- [ ] Voice messages
- [ ] Profile boost feature
- [ ] Multi-language support (Urdu, English)
- [ ] Advanced search filters
- [ ] Privacy controls
- [ ] Anonymous browsing

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is proprietary. All rights reserved.

## 👨‍💻 Author

**Soul Mate Team**
- Built with ❤️ using Flutter & Supabase
- Version: 1.0.0
- Release Date: April 13, 2026

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Email: support@soulmate.app (placeholder)

---

**Made with Flutter 💙 and Supabase 💚**

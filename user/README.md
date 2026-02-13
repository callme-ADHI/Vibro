# VIBRO User Application

## Overview
VIBRO is an AI-powered name detection and wearable alert system built with Flutter. This is the Phase 1 User Application implementing Clean Architecture principles.

## Project Architecture

```
VIBROO/
├── user/          → Flutter User Application (Phase 1 - Current)
├── admin/         → Admin Application (Future Phase)
├── backend/       → Supabase Backend (Future Phase)
├── device/        → ESP32 Firmware (Future Phase)
└── docs/          → Documentation (Future)
```

## User App Structure (Clean Architecture)

```
lib/
├── core/
│   ├── constants/     → App-wide constants & enums
│   ├── theme/         → Luxury navy blue design system
│   ├── errors/        → Custom exceptions
│   ├── utils/         → Utility functions
│   └── network/       → (Future) Network configuration
│
├── features/
│   ├── authentication/  → Phone OTP authentication
│   ├── home/            → Detection control & device management
│   ├── alerts/          → Live detection monitoring
│   ├── history/         → Detection history & analytics
│   ├── locations/       → Location-based configuration
│   ├── settings/        → App settings & model management
│   ├── model_training/  → Audio recording & model training
│   ├── ble_device/      → ESP32 wearable communication
│   └── subscription/    → Subscription management
│
├── data/              → Data layer
│   ├── models/        → Data models
│   ├── repositories_impl/
│   ├── datasources/
│   │   ├── local/     → Local storage
│   │   └── remote/    → Supabase API
│   └── mappers/
│
├── domain/            → Business logic layer
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│
├── presentation/      → UI layer
│   ├── pages/
│   ├── widgets/
│   └── state_management/
│
└── main.dart
```

## Design System

### Color Palette (Luxury Navy Blue Theme)
- **Deep Navy**: `#0A1F44` - Primary background
- **Dark Midnight**: `#081A38` - Card background
- **Steel Blue**: `#2E5BFF` - Active states & accents
- **Silver Gray**: `#B8C2D1` - Secondary text
- **Platinum White**: `#F5F7FA` - Primary text

### Typography
- **Font Family**: Inter (400, 500, 600, 700 weights)
- Professional, minimal, corporate aesthetic
- High letter spacing for refined appearance

### Design Principles
- Medical-grade reliability
- Enterprise-level professionalism
- 8pt spacing grid
- 16px corner radius
- Subtle shadows (12% opacity)
- No playful animations

## Tech Stack

### Core Framework
- **Flutter**: ^3.11.0
- **Dart**: ^3.11.0

### State Management
- **flutter_riverpod**: ^2.5.1
- **riverpod_annotation**: ^2.3.5

### Backend & Authentication
- **supabase_flutter**: ^2.6.0

### BLE Communication
- **flutter_blue_plus**: ^1.32.12

### Audio & ML
- **record**: ^5.1.2 (Audio recording)
- **tflite_flutter**: ^0.10.4 (ML inference)
- **permission_handler**: ^11.3.1

### UI & Navigation
- **go_router**: ^14.3.0
- **google_fonts**: ^6.1.0
- **shimmer**: ^3.0.0
- **lottie**: ^3.2.0
- **fl_chart**: ^0.69.2

## Features (Implementation Status)

### ✅ Completed
- [x] Root project structure
- [x] Clean Architecture folder structure
- [x] Luxury navy blue theme system
- [x] Core constants & utilities
- [x] Splash screen
- [x] Reusable widgets (VibroCard, ConfidenceBadge)
- [x] Dependencies configuration

### 🔨 In Progress
- [ ] Authentication flow (Phone OTP)
- [ ] Home page (Detection control)
- [ ] BLE device integration
- [ ] Audio recording module
- [ ] ML model inference
- [ ] Alerts page
- [ ] History page
- [ ] Locations management
- [ ] Settings page

### 📋 Planned
- [ ] Subscription management
- [ ] Model training flow
- [ ] Offline support
- [ ] Background detection
- [ ] Push notifications

## System Flow

1. **User records audio** → Upload to Supabase
2. **Colab trains model** → Model uploaded
3. **User downloads model** → Local inference
4. **Detection runs** (confidence ≥ 49%)
5. **BLE trigger** → ESP32 vibrates
6. **History stored** → Analytics available

## Configuration Required

### Supabase Setup
Edit `lib/core/constants/app_constants.dart`:
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### Fonts
Download and place Inter font files in:
```
assets/fonts/
├── Inter-Regular.ttf
├── Inter-Medium.ttf
├── Inter-SemiBold.ttf
└── Inter-Bold.ttf
```

## Running the App

```bash
cd user

# Get dependencies (already done)
flutter pub get

# Run on connected device
flutter run

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release
```

## Development Guidelines

### Clean Architecture Layers
1. **Presentation**: UI components, state management
2. **Domain**: Business logic, use cases (pure Dart)
3. **Data**: API calls, local storage, repositories

### Adding a New Feature
1. Create feature folder in `lib/features/`
2. Add domain entities and use cases
3. Implement data sources and repositories
4. Create presentation pages and widgets
5. Wire up with Riverpod providers

### Design Rules
- Use `VibroCard` for consistent card styling
- Use `ConfidenceBadge` for accuracy display
- Follow 8pt spacing grid
- Maintain deep navy color palette
- No bright or playful colors
- Professional animations only (200-300ms)

## Important Notes

⚠️ **Phase 1 Only**: This build contains ONLY the User App structure.

🚧 **Placeholders**: `admin/`, `backend/`, `device/` folders are structural placeholders.

🔐 **Security**: Configure Supabase credentials before deployment.

🎨 **Fonts**: Add actual Inter font files (placeholders currently).

📱 **Permissions**: Configure Android & iOS permissions for:
- Microphone
- Bluetooth
- Storage
- Notifications

## Next Development Phases

- **Phase 2**: Complete all feature implementations
- **Phase 3**: Admin Application
- **Phase 4**: Supabase Backend setup
- **Phase 5**: Google Colab training pipeline
- **Phase 6**: ESP32 firmware development

## License
Copyright © 2024 VIBRO. All rights reserved.

---

**VIBRO** - Precision. Intelligence. Trust.

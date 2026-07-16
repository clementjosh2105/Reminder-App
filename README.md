# Momentum

Momentum is a Flutter habit and reminder app with local storage, scheduled notifications, streak tracking, onboarding, statistics, Firebase Messaging support, AdMob support, and optional AI-generated coaching copy.

## Security

Do not hardcode third-party API keys in the Flutter client. AI coaching uses local fallback messages unless `GROQ_API_KEY` is supplied at build time:

```bash
flutter run --dart-define=GROQ_API_KEY=your_dev_key
```

For production, route AI requests through a backend such as Firebase Functions so the key is never shipped in the app binary.

## Firebase

Android Firebase options are configured in `lib/core/config/firebase_config.dart`. iOS and web intentionally throw until real platform options are added.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

If the generated Hive adapter changes, rebuild it with:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

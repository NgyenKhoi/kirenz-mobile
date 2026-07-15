# Kirenz Mobile

Run against the local API Gateway:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

## Google OAuth configuration

Google login uses `google_sign_in` and sends only the returned Google ID token to `POST /api/auth/google`. Kirenz access and refresh tokens remain the app session credentials.

Android requires an OAuth web client registered for the application package and signing SHA fingerprints. Pass its client id with:

```powershell
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

iOS additionally requires its OAuth client id and reversed-client-id callback URL scheme in `ios/Runner/Info.plist` or `GoogleService-Info.plist`:

```powershell
flutter run --dart-define=GOOGLE_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

OAuth identifiers and signing fingerprints are environment-specific and are not committed to this repository.

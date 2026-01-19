Local Google 'G' asset — instructions

To use the official Google 'G' logo locally in the app:

1. Download the official 'G' branding asset (single-color or full-color PNG) from Google's Brand Resources:
   - https://developers.google.com/identity/branding-guidelines

2. Save the PNG as `google_g_logo.png` inside the project's `assets/` directory:

   - `assets/google_g_logo.png`

3. `pubspec.yaml` already includes that asset entry. After placing the file, run:

```bash
flutter pub get
flutter run -d chrome
```

4. The login button uses `Image.asset('assets/google_g_logo.png')` and will fall back to a generic icon if the asset is missing or fails to load.

Note: Ensure you follow Google's branding guidelines when using their logo (size, clear space, color, and context rules). If you want, I can add the local asset file for you if you provide the image or approve fetching it from an external source.
# MediCare BD: Complete Setup (A to Z, Firebase Spark = free)

> Ei code ami likhechi kintu Flutter compiler diye chalate parini. Prothom bar `flutter analyze` e choto kichu error ashte pare. Seta paste kore amake pathan, thik kore dibo.

## 1. Ki free, ki bad
| Service | Plan | Status |
|---|---|---|
| Auth (Email/Password) | Spark free | ✅ |
| Firestore | Spark free (1 GB, 50k read, 20k write per day) | ✅ |
| Crashlytics, Analytics, FCM | Free | ✅ |
| Cloud Functions | Blaze (card dorkar) | ❌ bad. Server logic client transaction + Firestore rules diye kora |
| Cloud Storage (file upload) | Blaze dorkar (notun project) | ❌ bad. Record/report text hishebe save hoy |
| Phone OTP (SMS) | SMS charge | ❌ bad. Email login |
| Payment gateway (SSLCommerz/aamarPay) | Server dorkar | ❌ bad. bKash/Nagad/Rocket manual TrxID verify |
| App Check | Free | Phase 6 (README-r sheshe) |

Firebase pricing bodlate pare: firebase.google.com/pricing dekhe nin.

## 2. Tools
1. Flutter SDK (`flutter doctor` sob tick).
2. Node.js LTS.
3. ```
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```

## 3. Firebase project
1. console.firebase.google.com -> Add project -> `medicare-bd` -> Analytics ON.
2. Plan Spark-i thakbe.
3. Build -> Authentication -> Sign-in method -> **Email/Password** Enable.
4. Build -> Firestore Database -> Create -> location `asia-south1` -> Production mode.
5. Release & Monitor -> Crashlytics -> Enable.
6. Engage -> Messaging (FCM) ar kichu korte hobe na.

## 4. Flutter project
```
flutter create --org com.medicarebd --project-name medicare_bd medicare_bd
cd medicare_bd
```
Zip-er `lib/`, `test/`, `firestore.rules`, `firestore.indexes.json`, `firebase.json` project-e copy korun (lib/main.dart replace hobe).

Packages. **Riverpod 2.6 pin kora must**, code 2.x API-te lekha:
```
flutter pub add firebase_core firebase_auth cloud_firestore firebase_crashlytics firebase_analytics firebase_messaging go_router intl url_launcher pdf printing timezone
flutter pub add flutter_riverpod:^2.6.1 flutter_local_notifications:^18.0.1
```

## 5. Firebase connect
```
flutterfire configure
```
`medicare-bd` select, Android + iOS + Web tick. Eta `lib/firebase_options.dart` ar `google-services.json` toiri kore.

## 6. Android setup
`android/settings.gradle.kts` plugins-e (na thakle):
```
id("com.google.gms.google-services") version "4.4.2" apply false
id("com.google.firebase.crashlytics") version "3.0.2" apply false
```
`android/app/build.gradle.kts`:
```
plugins { id("com.google.gms.google-services"); id("com.google.firebase.crashlytics") }
android {
  defaultConfig { minSdk = 23 }
  compileOptions { isCoreLibraryDesugaringEnabled = true }
}
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
```
`android/app/src/main/AndroidManifest.xml` `<manifest>` er bhitore:
```
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
</queries>
```
`<application>` er bhitore (reboot-er pore reminder ferot ashar jonno):
```
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/></intent-filter>
</receiver>
```
Version number purono hole Firebase docs-er latest boshan.

## 7. iOS (Mac lagbe)
`ios/Runner/Info.plist`-e:
```
<key>LSApplicationQueriesSchemes</key><array><string>tel</string><string>https</string></array>
```
Tarpor `cd ios && pod install --repo-update`. Push-er jonno Apple Developer account ar APNs key dorkar (paid).

## 8. Rules + indexes deploy
```
firebase use --add
firebase deploy --only firestore:rules,firestore:indexes
```
Rule-gulo Firestore-e role dekhte `users/{uid}` read kore. Eta Spark-er read quota theke jay (shamanno).

## 9. Run
```
flutter pub get
dart format .
flutter analyze
flutter test
flutter run                 # Android / iOS
flutter run -d chrome       # Web (admin panel)
flutter build web           # Web release
flutter build apk --release
```

## 10. Prothom Super Admin
1. App-e register korun.
2. Console -> Firestore -> `users` -> apnar doc -> `role` = `super_admin`.
3. App-e Home-e "Admin panel" dekhabe. Users & roles theke onno admin role (verification_admin, finance_admin, support_admin, content_admin) din. Kewl super_admin role dite pare.

## 11. Provider verify kora
Doctor/Hospital/Pharmacy/Diagnostic/Ambulance: Profile tab -> "Apply as ...". Admin panel -> Verification -> Approve. Approve korle user-er role auto bodlay ar dashboard khule.

## 12. Crashlytics + Analytics test
- Crashlytics: `flutter run --release` e collect hoy. Debug-e off. Test: Profile tab-e "Test Crashlytics crash" (debug-only button, tai Crashlytics collection off thake). Real test: `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true)` temporarily main.dart-e din, button chapun, app abar kholun. Console-e 5 minute-e dekhabe.
- Analytics: `adb shell setprop debug.firebase.analytics.app com.medicarebd.medicare_bd` -> Console -> Analytics -> DebugView. Event: login, sign_up, appointment_booked, screen_view.
- Kono rogir naam/rog/oshudh Analytics ba Crashlytics-e pathano hoyni, shudhu user id.

## 13. Push notification (free)
Console -> Messaging -> New campaign -> Topic = `all`. Appointment-bhittik automatic push-er jonno Cloud Functions lagbe (Blaze), tai ei version-e nei. Local medicine reminder offline-e kaj kore.

## 14. Feature status (shotti kotha)
Ready (code ache, test kora hoyni):
Auth + consent + deactivate/delete request, role-based home, patient health profile, doctor search/filters, booking (transaction + rules double-booking block), cancel, doctor schedule, online call (Jitsi link) + secure chat, prescriptions (immutable) + PDF, reminders (offline local notification + taken/skipped), tracker + chart + BMI, medical records + consent sharing, hospitals, pharmacy (catalog, cart, Rx review, orders), diagnostics (tests, booking, text report), blood donation (private phone + consent), ambulance listing/request, health articles (review before publish), support tickets, announcements, manual payment verify, admin panel (verification, payments/refund mark, content, support, monitor, users/roles, audit, settings), Bangla/English (main menu only), Crashlytics, Analytics, firestore rules.

Ekhono nei:
- File upload (PDF/X-ray/MRI, profile photo, logo, product image): Storage = Blaze. Image URL field ache.
- Phone OTP, real payment gateway, refund automation, push on events: Server/Blaze lagbe.
- Firebase Custom Claims ar App Check enforcement: Functions/setup lagbe. Role Firestore `users.role` + rules diye hoy.
- Splash/onboarding screen, doctor-er hospital-er appointment overview, multiple roles per user (ekta user = ekta role).
- Bangla full translation (ekhon main menu), Bangla font PDF-e.
- Automated test: shudhu utils test. Widget/integration/rules test baki.
- Jitsi room private noy, link jante pare tar-i dhukte pare. Token-based secure room Functions chai.

## 15. App Check (Phase 6, free)
Console -> App Check -> Android: Play Integrity, iOS: App Attest, Web: reCAPTCHA v3. `flutter pub add firebase_app_check`, `main.dart`-e `await FirebaseAppCheck.instance.activate(...)`, kaj hole Console-e Enforce chalu korun.

# Deployment Guide

This guide covers deploying the Secure Document Scanner to production environments, including app stores and enterprise distribution.

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [iOS Deployment](#ios-deployment)
- [Android Deployment](#android-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [App Store Submission](#app-store-submission)
- [Enterprise Distribution](#enterprise-distribution)
- [Post-Deployment](#post-deployment)

## Pre-Deployment Checklist

### Code Review
- [ ] Security audit completed
- [ ] All tests passing
- [ ] No debug code in production
- [ ] No hardcoded secrets or API keys
- [ ] Error handling implemented
- [ ] Logging configured for production

### Configuration
- [ ] Update version number in `pubspec.yaml`
- [ ] Set build number/version code
- [ ] Configure release signing
- [ ] Update API endpoints for production
- [ ] Configure crash reporting
- [ ] Set up analytics (if using)

### Legal & Compliance
- [ ] Privacy policy created and accessible
- [ ] Terms of service prepared
- [ ] GDPR compliance verified
- [ ] Required licenses included
- [ ] Encryption export compliance (if applicable)

### Assets
- [ ] App icons for all sizes
- [ ] Splash screens
- [ ] Store screenshots
- [ ] App store description
- [ ] Promotional graphics

## iOS Deployment

### 1. Xcode Configuration

**Update Version and Build Number:**

`ios/Runner/Info.plist`:
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

Or use command line:
```bash
# Set version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.0" ios/Runner/Info.plist

# Increment build number
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ios/Runner/Info.plist)
NEW_BUILD=$((CURRENT_BUILD + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" ios/Runner/Info.plist
```

**Required Info.plist Entries:**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan documents</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed to import documents</string>

<key>NSFaceIDUsageDescription</key>
<string>Face ID is used for secure authentication</string>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>
<!-- Or <true/> with export compliance documentation -->
```

### 2. Code Signing

**Automatic Signing:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Signing & Capabilities tab
4. Enable "Automatically manage signing"
5. Select your Team

**Manual Signing:**
```bash
# Create provisioning profile at developer.apple.com
# Download and install

# Configure in Xcode:
# - Signing & Capabilities
# - Uncheck "Automatically manage signing"
# - Select Provisioning Profile
```

### 3. Build Release IPA

**Via Flutter:**
```bash
# Build release
flutter build ios --release

# Or with specific flavor
flutter build ios --release --flavor production
```

**Via Xcode:**
1. Open `ios/Runner.xcworkspace`
2. Select "Any iOS Device" as target
3. Product → Archive
4. Organizer opens with archive
5. Distribute App → App Store Connect

**Via Command Line:**
```bash
# Build archive
xcodebuild -workspace ios/Runner.xcworkspace \
           -scheme Runner \
           -configuration Release \
           -archivePath build/Runner.xcarchive \
           archive

# Export IPA
xcodebuild -exportArchive \
           -archivePath build/Runner.xcarchive \
           -exportPath build \
           -exportOptionsPlist ios/ExportOptions.plist
```

`ios/ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

### 4. Upload to App Store Connect

**Via Xcode Organizer:**
1. Window → Organizer
2. Select archive
3. Distribute App
4. App Store Connect
5. Upload

**Via Transporter App:**
1. Download from Mac App Store
2. Drag IPA file
3. Deliver

**Via Command Line:**
```bash
xcrun altool --upload-app \
             --type ios \
             --file build/Runner.ipa \
             --username YOUR_APPLE_ID \
             --password @keychain:APP_SPECIFIC_PASSWORD
```

### 5. TestFlight Distribution

1. Upload build to App Store Connect
2. Wait for processing (10-30 minutes)
3. App Store Connect → TestFlight
4. Select build
5. Provide "What to Test" notes
6. Add internal or external testers
7. Submit for review (external testers only)

## Android Deployment

### 1. Configure Signing

**Generate Keystore:**
```bash
keytool -genkey -v \
        -keystore ~/upload-keystore.jks \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -alias upload
```

**Store Credentials Securely:**

Create `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>/upload-keystore.jks
```

Add to `.gitignore`:
```
android/key.properties
*.jks
*.keystore
```

**Configure in `android/app/build.gradle`:**
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 2. ProGuard Configuration

`android/app/proguard-rules.pro`:
```proguard
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# SQLCipher
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

# Encryption libraries
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep app-specific classes
-keep class com.securescanner.doc_scanner.** { *; }
```

### 3. Update App Version

`android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        versionCode 1
        versionName "1.0.0"
        ...
    }
}
```

Or use Flutter versioning in `pubspec.yaml`:
```yaml
version: 1.0.0+1  # version+buildNumber
```

### 4. Build Release APK/AAB

**Build AAB (recommended for Play Store):**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

**Build APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Split APKs (smaller size)
flutter build apk --split-per-abi --release
```

**Build with different flavors:**
```bash
flutter build appbundle --release --flavor production
```

### 5. Test Release Build

```bash
# Install APK
flutter install --release

# Or manually
adb install build/app/outputs/flutter-apk/app-release.apk

# Test on real device (not emulator)
# Verify:
# - Signing works
# - Permissions request correctly
# - Biometric authentication
# - Camera functionality
```

### 6. Upload to Play Store

**Via Play Console:**
1. Go to [Play Console](https://play.google.com/console)
2. Create app (if first time)
3. Production → Create new release
4. Upload AAB file
5. Add release notes
6. Review and roll out

**Via Command Line (gradle-play-publisher):**
```gradle
// android/app/build.gradle
plugins {
    id 'com.github.triplet.play' version '3.7.0'
}

play {
    serviceAccountCredentials = file("../play-store-credentials.json")
    track = "internal" // or "alpha", "beta", "production"
    defaultToAppBundles = true
}
```

```bash
./gradlew publishReleaseBundle
```

### 7. Internal Testing / Closed Testing

1. Play Console → Testing → Internal testing
2. Create release
3. Upload AAB
4. Add testers (email addresses)
5. Share opt-in URL with testers

## CI/CD Pipeline

### GitHub Actions Example

`.github/workflows/deploy.yml`:
```yaml
name: Build and Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Build iOS
        run: flutter build ios --release --no-codesign

      - name: Upload to App Store
        env:
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
        run: |
          # Upload with fastlane or xcrun altool

  deploy-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-java@v3
        with:
          java-version: '11'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/upload-keystore.jks

      - name: Build AAB
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: flutter build appbundle --release

      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_JSON_KEY }}
          packageName: com.securescanner.doc_scanner
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal
```

### Fastlane Setup

**Install:**
```bash
sudo gem install fastlane
```

**iOS Fastfile:**

`ios/fastlane/Fastfile`:
```ruby
platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store"
    )
    upload_to_testflight
  end

  desc "Build and upload to App Store"
  lane :release do
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store"
    )
    upload_to_app_store
  end
end
```

**Android Fastfile:**

`android/fastlane/Fastfile`:
```ruby
platform :android do
  desc "Build and upload to Play Store (internal track)"
  lane :internal do
    gradle(
      task: "bundle",
      build_type: "Release"
    )
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab'
    )
  end

  desc "Promote internal to production"
  lane :promote_to_production do
    upload_to_play_store(
      track: 'internal',
      track_promote_to: 'production'
    )
  end
end
```

**Run:**
```bash
# iOS
cd ios
fastlane beta

# Android
cd android
fastlane internal
```

## App Store Submission

### iOS App Store

1. **App Store Connect Setup**
   - Create app record
   - Set bundle ID
   - Configure pricing
   - Add screenshots (all required sizes)
   - Add app description
   - Add keywords
   - Select category
   - Set content rating

2. **Required Screenshots**
   - 6.7" (iPhone 14 Pro Max): 1290 x 2796
   - 6.5" (iPhone 11 Pro Max): 1284 x 2778
   - 5.5" (iPhone 8 Plus): 1242 x 2208
   - 12.9" iPad Pro: 2048 x 2732

3. **App Review Information**
   - Demo account credentials (if login required)
   - Contact information
   - Review notes
   - Encryption compliance

4. **Privacy Policy**
   - Must be publicly accessible URL
   - Covers all data collection
   - Clear opt-out mechanisms

5. **Submit for Review**
   - Select build
   - Add version information
   - Submit

**Review Times:** Typically 24-48 hours

### Google Play Store

1. **Play Console Setup**
   - Create store listing
   - Add app details
   - Upload screenshots (all form factors)
   - Set content rating (questionnaire)
   - Select category
   - Add privacy policy URL

2. **Required Screenshots**
   - Phone: 16:9 or 9:16 aspect ratio, min 320px
   - 7-inch tablet: 1024w x 600h min
   - 10-inch tablet: 1920w x 1200h min

3. **Content Rating**
   - Complete questionnaire
   - Receive rating (Everyone, Teen, Mature, etc.)

4. **Release Management**
   - Internal testing (optional)
   - Closed testing (optional)
   - Open testing (optional)
   - Production

**Review Times:** Typically 1-3 days (first submission may take longer)

## Enterprise Distribution

### iOS Enterprise (In-House)

**Requirements:**
- Apple Developer Enterprise Program ($299/year)
- DUNS number

**Steps:**
1. Create Enterprise Distribution Certificate
2. Create In-House Provisioning Profile
3. Build with enterprise profile
4. Host IPA on web server
5. Create manifest file

`manifest.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>https://example.com/app.ipa</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>com.securescanner.doc_scanner</string>
                <key>bundle-version</key>
                <string>1.0.0</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>Doc Scanner</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
```

**Install Link:**
```html
<a href="itms-services://?action=download-manifest&url=https://example.com/manifest.plist">
  Install App
</a>
```

### Android Enterprise (MDM)

**Using Managed Google Play:**
1. Create Android Enterprise account
2. Upload APK/AAB to Google Play
3. Configure as private app
4. Distribute via MDM (Intune, Workspace ONE, etc.)

**Self-Hosted:**
```bash
# Host APK on internal server
# Configure MDM to download from URL
# Push to managed devices
```

## Post-Deployment

### Monitoring

**Crash Reporting:**
- Firebase Crashlytics
- Sentry
- Bugsnag

**Analytics:**
- Firebase Analytics
- Mixpanel
- Amplitude

**Performance Monitoring:**
- Firebase Performance Monitoring
- New Relic

### Versioning Strategy

**Semantic Versioning:**
```
MAJOR.MINOR.PATCH+BUILD

1.0.0+1  - Initial release
1.0.1+2  - Bug fix
1.1.0+3  - New feature
2.0.0+4  - Breaking change
```

### Rollback Plan

**iOS:**
- Can't rollback, but can:
  - Submit hotfix version
  - Phased release (pause at any %)

**Android:**
- Can halt rollout
- Can rollback to previous version (limited time)

### Release Notes Template

```
Version 1.1.0

What's New:
- Added PDF export functionality
- Improved OCR accuracy
- Enhanced document search

Bug Fixes:
- Fixed crash on large document sets
- Resolved backup upload issue
- Improved biometric authentication reliability

Performance:
- 30% faster document processing
- Reduced app size by 15%
```

## Security Checklist

Before deploying:

- [ ] All API keys in environment variables
- [ ] Debug logging disabled in release
- [ ] Certificate pinning enabled (if applicable)
- [ ] ProGuard/R8 enabled (Android)
- [ ] Bitcode enabled (iOS, if needed)
- [ ] Code obfuscation reviewed
- [ ] Third-party libraries audited
- [ ] Encryption export compliance completed
- [ ] Security scan completed (OWASP Mobile)
- [ ] Penetration testing done (if required)

## Useful Commands

```bash
# Check app size
flutter build apk --analyze-size
flutter build ios --analyze-size

# Generate changelog
git log --oneline v1.0.0..v1.1.0 > CHANGELOG.txt

# Tag release
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Bump version
# Update pubspec.yaml version: 1.0.1+2
flutter pub get

# Clean build
flutter clean
flutter pub get
```

---

For debugging and testing, see:
- [DEBUGGING.md](DEBUGGING.md)
- [TESTING.md](TESTING.md)

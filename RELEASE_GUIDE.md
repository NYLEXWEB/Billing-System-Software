# Android Release & Signing Guide

This guide details how to sign and compile the application for production deployment or APK generation.

## 1. Keystore Configuration

To publish or install production builds, the APK or Android App Bundle (AAB) must be signed with a release key.

### Generate a Keystore File
Run this command from your terminal:

```bash
keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
```

Keep this file safe. If you lose the keystore, you will not be able to push updates to existing installs.

---

## 2. Configure Key Signing in Flutter

Create a file named `android/key.properties` (do not commit this to version control):

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=my-key-alias
storeFile=C:/path/to/my-release-key.jks
```

Then, update your `android/app/build.gradle` to load this properties file and configure the signing configurations:

```groovy
def keystorePropertiesFile = rootProject.file('key.properties')
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new java.io.FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            if (keystoreProperties.containsKey('storeFile')) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
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

---

## 3. Building Production Binaries

Run the following Flutter build tasks:

```powershell
# 1. Generate standard Android App Bundle (Recommended for Google Play)
flutter build appbundle --release

# 2. Generate a universal standalone APK
flutter build apk --release

# 3. Generate split APKs (reduces download sizes by architecture)
flutter build apk --target-platform android-arm,android-arm64,android-x64 --split-per-abi
```

The resulting binaries will be saved under:
`build/app/outputs/bundle/release/app-release.aab` or `build/app/outputs/flutter-apk/app-release.apk`.

# ToggleTalk App Troubleshooting Guide

## Issue: App Icon Shows for Only a Second

This issue typically occurs when the app crashes during initialization or fails to properly load resources. Here's how to diagnose and fix it:

## Common Causes and Solutions

### 1. Asset Loading Issues

**Problem**: The app crashes when trying to load images or other assets.

**Solution**:
1. Verify all asset files exist in the correct directories:
   - `assets/icons/ToggleTalk.png`
   - `assets/bg/background.png`
   - `assets/json/Home.json`

2. Run `flutter pub get` to ensure all dependencies are installed.

3. Run `flutter clean` and then `flutter pub get` to clear any cached builds.

### 2. Permission Issues

**Problem**: The app crashes when requesting permissions on Android.

**Solution**:
1. Check that all required permissions are declared in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
   <uses-permission android:name="android.permission.WAKE_LOCK"/>
   ```

2. For Android 13+, add notification permission:
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```

### 3. Dependency Issues

**Problem**: Missing or incompatible dependencies cause the app to crash.

**Solution**:
1. Update dependencies:
   ```bash
   flutter pub upgrade
   ```

2. If issues persist, try downgrading specific packages:
   ```bash
   flutter pub downgrade
   ```

### 4. Initialization Errors

**Problem**: Complex initialization code in `initState()` causes crashes.

**Solution**:
1. Add comprehensive error handling to initialization code:
   ```dart
   @override
   void initState() {
     super.initState();
     _initializeApp();
   }

   Future<void> _initializeApp() async {
     try {
       // Your initialization code here
     } catch (e, stackTrace) {
       print('Error during initialization: $e');
       print('Stack trace: $stackTrace');
       // Handle error gracefully
     }
   }
   ```

## Debugging Steps

### 1. Run with Verbose Logging
```bash
flutter run -v
```
This will show detailed logs that can help identify where the crash occurs.

### 2. Check Android Logs
```bash
adb logcat
```
Look for error messages when the app crashes.

### 3. Test with Minimal Version
Use the minimal version of the app to isolate the issue:
1. Replace `main.dart` with `minimal_main.dart`
2. Run the app to see if it works
3. If it works, gradually add back components to identify the problematic code

### 4. Check for Platform-Specific Issues
Some packages may not work on all platforms:
1. Try running on a different device/emulator
2. Check if the issue occurs on both Android and iOS
3. Test on different Android versions

## Quick Fixes to Try

1. **Clean and Rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter build
   ```

2. **Delete Build Cache**:
   ```bash
   rm -rf build/
   rm -rf .dart_tool/
   flutter pub get
   ```

3. **Check Flutter Doctor**:
   ```bash
   flutter doctor -v
   ```
   Fix any issues reported.

4. **Update Flutter**:
   ```bash
   flutter upgrade
   ```

## Testing the Fix

1. After applying fixes, run:
   ```bash
   flutter run
   ```

2. If the app still crashes, check the logs for specific error messages.

3. If the minimal version works but the full version doesn't, compare the initialization code to identify problematic components.

## Contact Support

If none of these solutions work, please provide:
1. Full error logs from `flutter run -v`
2. Your device/emulator information
3. Flutter version (`flutter --version`)
4. Android/iOS version
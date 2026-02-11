# 🔔 Automatic Notification System for Detection Alerts

## Overview

This document describes the automatic push notification system implemented for the Dronia app. When a pest or disease is detected during drone scanning, the user automatically receives a push notification on their device.

## ✅ What's Been Implemented

### 1. **Local Push Notifications**
- Instant notifications when diseases/pests are detected
- Works even when app is in background
- Different notification styles based on severity:
  - 🚨 **Disease Detected** - High priority, red color
  - ⚠️ **Stress Detected** - Normal priority, orange color
  - ✅ **Healthy Crop** - Low priority, green color

### 2. **Files Added/Modified**

#### **New Files:**
- `lib/data/services/notification_service.dart` - Complete notification management service

#### **Modified Files:**
- `pubspec.yaml` - Added notification dependencies
- `lib/main.dart` - Initialize notification service on app startup
- `lib/data/services/detection_service.dart` - Integrated notifications with detection
- `android/app/src/main/AndroidManifest.xml` - Android notification permissions
- `ios/Runner/Info.plist` - iOS notification configuration

### 3. **Features**

✅ Automatic notifications on detection  
✅ Sound and vibration for alerts  
✅ Rich notifications with detailed information  
✅ Notification history in system tray  
✅ Configurable notification threshold (only critical alerts)  
✅ Support for scheduled notifications  
✅ iOS and Android support  

## 📱 How It Works

### Detection Flow:

```
Drone Scanning → Detection Occurs → Save to History → Send Notification → User Receives Alert
```

### Notification Types:

1. **Immediate Notifications** - Sent instantly when detection occurs
2. **Critical Alerts** - Only diseases with >70% confidence
3. **Summary Notifications** - After scanning session completes

## 🛠️ Configuration

### Customize Notification Behavior

Edit `lib/data/services/detection_service.dart`:

```dart
// Current: Send notification for ALL non-healthy detections
if (detection.type != DetectionType.healthy) {
  await _notificationService.notifyDetection(detection);
}

// Option 1: Only critical diseases (>70% confidence)
await _notificationService.notifyIfCritical(detection, threshold: 0.7);

// Option 2: Only diseases (no stress alerts)
if (detection.type == DetectionType.disease) {
  await _notificationService.notifyDetection(detection);
}
```

### Adjust Notification Priority

Edit `lib/data/services/notification_service.dart`:

```dart
// Line ~112-125: Change priority levels
case DetectionType.disease:
  priority = Priority.max;        // Change to max priority
  importance = Importance.max;    // Change to max importance
```

## 🎨 Customization Options

### Notification Channels

The app creates these notification channels:

1. **Detection Channel** (`detection_channel`)
   - For pest/disease detections
   - High priority with sound

2. **Summary Channel** (`summary_channel`)
   - For scan summaries
   - Medium priority

3. **Scheduled Channel** (`scheduled_channel`)
   - For planned interventions
   - High priority

### Notification Sounds

To add custom notification sounds:

1. **Android:** Place sound file in `android/app/src/main/res/raw/`
2. **iOS:** Add sound to Xcode project
3. Update `notification_service.dart`:

```dart
const androidDetails = AndroidNotificationDetails(
  'detection_channel',
  'Détections',
  sound: RawResourceAndroidNotificationSound('custom_sound'),
  // ... other settings
);
```

## 🧪 Testing Notifications

### Test the notification system:

```dart
// Add this to any screen for testing
import 'package:dronia/data/services/notification_service.dart';
import 'package:dronia/data/models/detection_model.dart';

// Test button
ElevatedButton(
  onPressed: () async {
    final testDetection = Detection(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Aphids',
      confidence: 0.92,
      timestamp: DateTime.now(),
      zone: 'Zone Test',
      type: DetectionType.disease,
    );
    
    await NotificationService().notifyDetection(testDetection);
  },
  child: Text('Test Notification'),
)
```

## 🚀 Advanced Features (Future Enhancement)

### 1. **Firebase Cloud Messaging (FCM)**

For remote notifications from backend:

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
```

### 2. **Email Notifications**

Backend integration with SendGrid/AWS SES:

```python
# backend/api/notifications.py
import sendgrid
from sendgrid.helpers.mail import Mail

def send_detection_email(user_email, detection_data):
    message = Mail(
        from_email='alerts@dronia.app',
        to_emails=user_email,
        subject='🚨 Detection Alert',
        html_content=f'Disease detected: {detection_data["label"]}'
    )
    sg = sendgrid.SendGridAPIClient(api_key=os.environ.get('SENDGRID_API_KEY'))
    sg.send(message)
```

### 3. **SMS Notifications**

Using Twilio for SMS alerts:

```python
from twilio.rest import Client

def send_sms_alert(phone_number, detection_label):
    client = Client(account_sid, auth_token)
    message = client.messages.create(
        body=f'🚨 Alert: {detection_label} detected in your field',
        from_='+1234567890',
        to=phone_number
    )
```

## 📊 Notification Settings (User Preferences)

To add user controls for notifications, create a settings screen:

```dart
// lib/presentation/screens/settings/notification_settings.dart

class NotificationSettings extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text('Enable Detection Alerts'),
      value: _notificationsEnabled,
      onChanged: (value) {
        setState(() => _notificationsEnabled = value);
        // Save to SharedPreferences
      },
    );
  }
}
```

## 🐛 Troubleshooting

### Notifications Not Showing

1. **Check Permissions:**
   ```dart
   final enabled = await NotificationService().areNotificationsEnabled();
   print('Notifications enabled: $enabled');
   ```

2. **Android 13+:** User must grant permission in system settings

3. **iOS:** Check Settings → Notifications → DronIA

4. **Test Initialization:**
   ```dart
   await NotificationService().initialize();
   print('Notification service initialized');
   ```

### iOS Simulator Issues

- Notifications may not work on iOS Simulator
- Test on physical device for accurate results

## 📝 Best Practices

1. **Don't Spam:** Only send notifications for actionable alerts
2. **Clear Content:** Include detection confidence and location
3. **Respect Do Not Disturb:** System handles this automatically
4. **Provide Context:** Link notifications to detection details
5. **Allow Opt-Out:** Give users control over notification types

## 🔐 Privacy Considerations

- All notifications are local (no data sent to external servers)
- Detection data stays on user's device
- No tracking or analytics on notifications
- User can clear notification history anytime

## 📚 Additional Resources

- [Flutter Local Notifications Docs](https://pub.dev/packages/flutter_local_notifications)
- [Android Notification Guidelines](https://developer.android.com/develop/ui/views/notifications)
- [iOS Notification Best Practices](https://developer.apple.com/design/human-interface-guidelines/notifications)

## 💡 Next Steps

1. Test notifications on physical devices
2. Gather user feedback on notification frequency
3. Consider implementing notification preferences screen
4. Add notification analytics (if needed)
5. Explore Firebase FCM for remote notifications

---

**Author:** Dronia Development Team  
**Last Updated:** February 2, 2026  
**Version:** 1.0.0

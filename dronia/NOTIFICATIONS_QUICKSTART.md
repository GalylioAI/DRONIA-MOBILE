# 🚀 Quick Start: Testing Notifications

## Immediate Testing Steps

### 1. **Run the App**

```bash
cd dronia
flutter run
```

### 2. **Test Notifications Using Test Screen**

Add this route to your app navigation (optional):

```dart
// In lib/core/routes/app_routes.dart
static const String notificationTest = '/test/notifications';

// In lib/core/routes/app_routes.dart generateRoute()
case AppRoutes.notificationTest:
  return MaterialPageRoute(
    builder: (_) => const NotificationTestScreen(),
  );
```

Or navigate directly:

```dart
// From any screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NotificationTestScreen(),
  ),
);
```

### 3. **Test During Actual Scanning**

The notifications work automatically when:

1. Start a drone mission
2. Wait for detection to occur (every 4 seconds)
3. When a disease/pest is detected, you'll see:
   - On-screen alert (existing feature)
   - **NEW:** Push notification on your device ✨

### 4. **Check Notification in System Tray**

- **Android:** Swipe down from top of screen
- **iOS:** Swipe down from top of screen

You should see notifications like:

```
🚨 Maladie Détectée!
Aphids détecté avec 92% de confiance dans la zone Zone Nord
```

## ✅ What to Verify

- [ ] Notification appears on screen
- [ ] Sound plays (if device not on silent)
- [ ] Device vibrates
- [ ] Notification shows in system tray
- [ ] Tapping notification shows in console (future: navigate to details)
- [ ] Notification works when app is in background

## 🎯 Customization Examples

### Send Only Critical Alerts (>80% confidence)

In `detection_service.dart`, change:

```dart
// FROM:
if (detection.type != DetectionType.healthy) {
  await _notificationService.notifyDetection(detection);
}

// TO:
await _notificationService.notifyIfCritical(detection, threshold: 0.8);
```

### Disable Notifications for Stress

```dart
// Only notify for diseases
if (detection.type == DetectionType.disease) {
  await _notificationService.notifyDetection(detection);
}
```

### Change Notification Sound/Priority

In `notification_service.dart`, line ~120:

```dart
final androidDetails = AndroidNotificationDetails(
  'detection_channel',
  'Détections',
  importance: Importance.max,    // Change priority
  priority: Priority.max,         // Change priority
  playSound: false,              // Disable sound
  enableVibration: false,        // Disable vibration
);
```

## 📱 Device-Specific Notes

### Android
- **Android 13+**: User will be prompted to allow notifications on first run
- **Settings**: Settings → Apps → DronIA → Notifications
- **Channels**: Can customize per channel (Detections, Summaries, etc.)

### iOS
- **First Run**: System prompts for notification permission
- **Settings**: Settings → Notifications → DronIA
- **Simulator**: Notifications may not work on simulator, use real device

## 🐛 Troubleshooting

**Notifications not showing?**

1. Check permissions:
```dart
final enabled = await NotificationService().areNotificationsEnabled();
print('Enabled: $enabled');
```

2. Re-run app after adding permissions

3. Check system settings:
   - Android: Settings → Apps → DronIA → Notifications
   - iOS: Settings → Notifications → DronIA

4. Ensure device is not in Do Not Disturb mode

**Build errors?**

```bash
flutter clean
flutter pub get
flutter run
```

## 🎨 Visual Examples

### Disease Detection Notification
```
┌────────────────────────────────┐
│ 🚨 Maladie Détectée!          │
│ Aphids détecté avec 92%        │
│ de confiance dans Zone Nord    │
│ Il y a 2 minutes               │
└────────────────────────────────┘
```

### Stress Detection Notification
```
┌────────────────────────────────┐
│ ⚠️ Stress Détecté             │
│ Stress Hydrique détecté avec   │
│ 78% de confiance dans Zone Est │
│ À l'instant                    │
└────────────────────────────────┘
```

## 📊 Next Features to Add

1. **Notification History Screen** - Show all past notifications
2. **Notification Settings** - Let users control notification types
3. **Grouped Notifications** - Group multiple detections
4. **Custom Sounds** - Different sounds for different severity
5. **Rich Media** - Include detection images in notifications

## 💡 Pro Tips

- Test on real device for best experience
- Check notification logs in console
- Use notification test screen for quick testing
- Customize notification copy for your users
- Consider notification frequency (don't spam!)

---

**Ready to test?** Run the app and start a drone scan! 🚁

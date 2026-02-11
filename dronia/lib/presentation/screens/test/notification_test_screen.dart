import 'package:flutter/material.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/models/detection_model.dart';

/// Test screen for notification functionality
/// Navigate to this screen to test notifications manually
class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
        backgroundColor: const Color(0xFF10B981),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Notification Test Panel',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap buttons below to test different notification types',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Test Disease Detection
            ElevatedButton.icon(
              onPressed: () => _testDiseaseNotification(context),
              icon: const Icon(Icons.bug_report),
              label: const Text('Test Disease Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Test Stress Detection
            ElevatedButton.icon(
              onPressed: () => _testStressNotification(context),
              icon: const Icon(Icons.warning),
              label: const Text('Test Stress Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Test Healthy Detection
            ElevatedButton.icon(
              onPressed: () => _testHealthyNotification(context),
              icon: const Icon(Icons.check_circle),
              label: const Text('Test Healthy Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Test Summary
            ElevatedButton.icon(
              onPressed: () => _testSummaryNotification(context),
              icon: const Icon(Icons.summarize),
              label: const Text('Test Summary Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),

            // Check Notification Status
            OutlinedButton.icon(
              onPressed: () => _checkNotificationStatus(context),
              icon: const Icon(Icons.info_outline),
              label: const Text('Check Notification Status'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Clear All Notifications
            OutlinedButton.icon(
              onPressed: () => _clearAllNotifications(context),
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All Notifications'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testDiseaseNotification(BuildContext context) async {
    final detection = Detection(
      id: 'test_disease_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Aphids',
      confidence: 0.92,
      timestamp: DateTime.now(),
      zone: 'Zone Test',
      type: DetectionType.disease,
    );

    await NotificationService().notifyDetection(detection);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Disease notification sent!'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testStressNotification(BuildContext context) async {
    final detection = Detection(
      id: 'test_stress_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Stress Hydrique',
      confidence: 0.78,
      timestamp: DateTime.now(),
      zone: 'Zone Centrale',
      type: DetectionType.stress,
    );

    await NotificationService().notifyDetection(detection);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Stress notification sent!'),
          backgroundColor: Color(0xFFF59E0B),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testHealthyNotification(BuildContext context) async {
    final detection = Detection(
      id: 'test_healthy_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Culture Saine',
      confidence: 0.95,
      timestamp: DateTime.now(),
      zone: 'Parcelle A1',
      type: DetectionType.healthy,
    );

    await NotificationService().notifyDetection(detection);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Healthy notification sent!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testSummaryNotification(BuildContext context) async {
    await NotificationService().notifyDetectionSummary(
      diseaseCount: 3,
      stressCount: 2,
      zone: 'Toutes les zones',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📊 Summary notification sent!'),
          backgroundColor: Color(0xFF3B82F6),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkNotificationStatus(BuildContext context) async {
    final enabled = await NotificationService().areNotificationsEnabled();
    final pending = await NotificationService().getPendingNotifications();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notification Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enabled: ${enabled ? "✅ Yes" : "❌ No"}'),
              const SizedBox(height: 8),
              Text('Pending: ${pending.length} notification(s)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearAllNotifications(BuildContext context) async {
    await NotificationService().cancelAll();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ All notifications cleared!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

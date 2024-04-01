import 'dart:ui';

class NotificationData {
  final String title;
  final String? body;
  final String? summary;
  final Color? color;
  final String? largeIcon;

  NotificationData({
    required this.title,
    this.body,
    this.summary,
    this.color,
    this.largeIcon,
  });
}

enum NotificationType {
  alert,
  reminder,
  creditTransaction,
  debitTransaction,
  transfer;
}
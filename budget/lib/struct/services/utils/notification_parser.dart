// TODO: make it user configurable from settings
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/notification_controller/models.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/widgets/util/deepLinks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

class Notification {
  final int id;
  final String title, message, packageName;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.packageName,
  });

  factory Notification.fromEvent(NotificationEvent event) => Notification(
        id: event.id ?? 1,
        title: event.title ?? '',
        message: NotificationParser.getSanitizedMessage(event.text),
        packageName: event.packageName!,
      );

  @override
  String toString() =>
      'Notification(id: $id, title: $title, message: $message, packageName: $packageName)';
}

const _sampleNotifications = [
  'Dear UPI user A/C *8389 debited by 110.00 on date 24Mar24 trf to ADI PANJABI Refno 408406270394. If not u? call 1800111109',
  '''Amt Sent Rs.40.00
From HDFC Bank A/C *5890
To HOTEL AND RESTAURANT
On 31-03
Ref 409157843802
Not You? Call 18002586161/SMS BLOCK UPI to 7308080808''',
  'HDFC Bank: Rs. 1000.00 credited to a/c XXXXXX5890 on 23-03-24 by a/c linked to VPA droy2ju@oksbi (UPI Ref No  408327542190).',
];

class NotificationParser {
  static List<Notification> recentNotifications = [];
  static List<String> recentNotificationMessages = [
    if (kDebugMode)
      for (final notification in _sampleNotifications)
        getSanitizedMessage(notification)
  ];

  static Notification? saveRecentNotification(NotificationEvent event) {
    final notification = Notification.fromEvent(event);

    final isDuplicate = recentNotifications.any((e) =>
        e.packageName == notification.packageName && e.id == notification.id);

    if (isDuplicate) {
      return null;
    }

    recentNotifications.insert(0, notification);
    recentNotifications = recentNotifications.take(10).toList();
    recentNotificationMessages =
        recentNotifications.map((e) => e.message).toList();

    print('Saved recent notification : ${notification}');

    return notification;
  }

  static Future<void> handleNotificationEvent(NotificationEvent event) async {
    final notification = await saveRecentNotification(event);
    if (notification == null) return;

    if (await handleTransactionNotification(notification)) return;

    await handleNonTransactionNotification(notification);
  }

  static Future<bool> handleTransactionNotification(
      Notification notification) async {
    final trxParams = await parseTransactionParams(notification);
    print('Parsed transaction params : ${trxParams}');
    if (trxParams.isEmpty) return false;

    final id = await addTransactionFromParams(trxParams);
    // TODO: Handle id == null if add transaction fails
    return id != null;
  }

  static Future<Map<String, String>> parseTransactionParams(
      Notification notification) async {
    String? title;
    double? amountDouble;
    ScannerTemplate? templateFound;

    List<ScannerTemplate> scannerTemplates =
        await database.getAllScannerTemplates();

    for (ScannerTemplate scannerTemplate in scannerTemplates) {
      final regExp = RegExp(scannerTemplate.regex);
      if (regExp.hasMatch(notification.message)) {
        templateFound = scannerTemplate;
        final match = regExp.firstMatch(notification.message)!;

        for (final group in match.groupNames) {
          final val = match.namedGroup(group);
          switch (group) {
            case 'title':
              title = val ?? '';
              break;
            case 'amount':
              amountDouble = double.tryParse((val ?? '').replaceAll(',', ''));
              break;
            default:
          }
        }
        break;
      }
    }

    if (templateFound == null || amountDouble == null || title == null)
      return {};

    final foundTitle =
        (await database.getSimilarAssociatedTitles(title: title)).firstOrNull;
    final category = foundTitle?.category ??
        await database
            .getCategoryInstanceOrNull(templateFound.defaultCategoryFk);

    return {
      'title': title,
      'amount': '${templateFound.income ? '' : '-'}$amountDouble',
      'walletPk': templateFound.walletFk,
      'notes': '[${notification.title}] ${notification.message}',
      if (category != null) 'category': category.name,
    };
  }

  static const possibleTransactionKeywords = [
    'debit',
    'credit',
    '5890',
    '8389'
  ];

  static Future<void> handleNonTransactionNotification(
      Notification notification) async {
    final message = notification.message;
    if (possibleTransactionKeywords
        .any((keyword) => message.contains(keyword))) {
      await notificationController.createNotification(
        content: NotificationData(
            title: 'New Transaction Detected, Add Scanner?', body: message),
        payload: {
          'type': 'addScannerTemplate',
        },
      );
    }
  }

  static String getSanitizedMessage(String? msg) => (msg ?? '')
      .replaceAll(RegExp(r'[,[\]*?:^$|{}]'), '')
      .replaceAll(RegExp(r'[\r\n\t]'), ' ');
}

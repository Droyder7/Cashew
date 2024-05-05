import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/main.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/upcomingOverdueTransactionsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/upcomingTransactionsFunctions.dart';
import 'package:budget/widgets/notificationsSettings.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

runNotificationPayLoadsNoContext() {
  if (navigatorKey.currentContext == null) return;
  // If the upcoming transaction notification tapped when app opened, auto pay overdue transaction
  if (notificationPayload == "upcomingTransaction") {
    Future.delayed(Duration.zero, () async {
      await markSubscriptionsAsPaid(navigatorKey.currentContext!);
      await markUpcomingAsPaid();
      await setUpcomingNotifications(navigatorKey.currentContext);
    });
  }
  runNotificationPayLoads(navigatorKey.currentContext);
}

Future<bool> runNotificationPayLoads(context) async {
  print("Notification payload: " + notificationPayload.toString());
  if (kIsWeb) return false;
  if (notificationPayload == null) return false;
  if (notificationPayload == "addTransaction") {
    pushRoute(
      context,
      AddTransactionPage(
        routesToPopAfterDelete: RoutesToPopAfterDelete.None,
      ),
    );
    return true;
  } else if (notificationPayload == "upcomingTransaction") {
    // When the notification comes in, the transaction is past due!
    pushRoute(
      context,
      UpcomingOverdueTransactions(overdueTransactions: null),
    );
    return true;
  } else if (notificationPayload?.split("?")[0] == "openTransaction") {
    Uri notificationPayloadUri = Uri.parse(notificationPayload ?? "");
    if (notificationPayloadUri.queryParameters["transactionPk"] == null)
      return false;
    String transactionPk =
        notificationPayloadUri.queryParameters["transactionPk"] ?? "";
    Transaction? transaction =
        await database.getTransactionFromPk(transactionPk);
    pushRoute(
      context,
      AddTransactionPage(
        transaction: transaction,
        routesToPopAfterDelete: RoutesToPopAfterDelete.One,
      ),
    );
    return true;
  }
  notificationPayload = "";
  return false;
}

Future<void> setDailyNotifications(context) async {
  if (kIsWeb) return;
  bool notificationsEnabled = appStateSettings["notifications"] == true;

  if (notificationsEnabled) {
    try {
      TimeOfDay timeOfDay = TimeOfDay(
          hour: appStateSettings["notificationHour"],
          minute: appStateSettings["notificationMinute"]);
      if (ReminderNotificationType
              .values[appStateSettings["notificationsReminderType"]] ==
          ReminderNotificationType.DayFromOpen) {
        timeOfDay = TimeOfDay(
            hour: appStateSettings["appOpenedHour"],
            minute: appStateSettings["appOpenedMinute"]);
      }
      await notificationController.scheduleDailyNotification(
          context, timeOfDay);
    } catch (e) {
      print(e.toString() +
          " Error setting up notifications for upcoming transactions");
    }
  }
}

Future<void> setUpcomingNotifications(context) async {
  if (kIsWeb) return;
  bool upcomingTransactionsNotificationsEnabled =
      appStateSettings["notificationsUpcomingTransactions"] == true;
  if (upcomingTransactionsNotificationsEnabled) {
    try {
      await notificationController
          .scheduleUpcomingTransactionsNotification(context);
    } catch (e) {
      print(e.toString() +
          " Error setting up notifications for upcoming transactions");
    }
  }
  return;
}

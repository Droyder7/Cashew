import 'dart:isolate';
import 'dart:ui';

import 'package:budget/struct/services/utils/notification_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

class NotificationListenerService {
  static const _portName = "notification_listener_port";
  static const whitelistedPackages = [
    if (!kDebugMode) 'com.google.android.apps.messaging'
  ];
  static const blackListedPackages = ['com.budget.tracker_app'];

  static ReceivePort? _receivePort;

  NotificationListenerService._();

  static final NotificationListenerService _instance =
      NotificationListenerService._();

  static NotificationListenerService get instance => _instance;

  factory NotificationListenerService() {
    return _instance;
  }

  Future<bool> init() async {
    var initialized = false;

    try {
      NotificationsListener.initialize(callbackHandle: _callback);
      initialized = true;
    } catch (e) {
      print('Error initializing notification listener: $e');
    }

    _receivePort = ReceivePort('Notification Listener ReceivePort')
      ..listen((event) => _onNotificationRecieved(event as NotificationEvent));

    // this can fix restart<debug> can't handle error
    IsolateNameServer.removePortNameMapping(_portName);
    initialized = IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, _portName);

    return initialized;
  }

  @pragma('vm:entry-point')
  static void _callback(NotificationEvent evt) {
    print('NotificationEvent callback : ${evt}');

    if (blackListedPackages.contains(evt.packageName) &&
        !whitelistedPackages.contains(evt.packageName)) {
      return;
    }

    if (_receivePort == null) {
      print('Listener callback called in parallel dart isolate.');
      final send = IsolateNameServer.lookupPortByName(_portName);
      if (send != null) {
        print('Redirecting the callback execution to main isolate process.');
        send.send(evt);
        return;
      }
    }

    print('Listener callback called in main dart isolate.');
    _onNotificationRecieved(evt);
  }

  static void _onNotificationRecieved(NotificationEvent event) async {
    print('Notification Recieved : ${event}');

    await NotificationParser.handleNotificationEvent(event);
  }

  Future<bool> requestPermission() async {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    final hasPermission = (await NotificationsListener.hasPermission) ?? false;
    if (!hasPermission) {
      print("no permission, so open settings");
      NotificationsListener.openPermissionSettings();
    }
    return hasPermission;
  }

  Future<bool> startService() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      return false;
    }

    var isRunning = await NotificationsListener.isRunning;
    if (!(isRunning ?? false)) {
      isRunning = await NotificationsListener.startService();
    }

    return isRunning ?? false;
  }

  Future<bool> stopService() async {
    final isRunning = (await NotificationsListener.isRunning) ?? false;
    if (isRunning) {
      return await NotificationsListener.stopService() ?? false;
    }

    return true;
  }
}

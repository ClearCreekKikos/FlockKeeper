// lib/shared/services/notification_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/inventory_repository.dart';

class NotificationService {
  final ReminderRepository _reminderRepository;
  final InventoryRepository _inventoryRepository;
  Timer? _periodicTimer;
  // Keys are "reminderId_yyyy-mm-dd" so each reminder notifies at most once
  // per day but is NOT permanently suppressed after its first early-window
  // notification — the due-today and overdue notices still fire on later days.
  final Set<String> _notifiedReminderKeys = {};
  final Set<String> _notifiedInventoryKeys = {};

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// local_notifier only supports desktop platforms (Windows, macOS, Linux).
  bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// flutter_local_notifications supports mobile platforms (iOS, Android).
  bool get _isMobile =>
      !kIsWeb &&
      (Platform.isIOS || Platform.isAndroid);

  NotificationService(this._reminderRepository, this._inventoryRepository);

  /// Initializes the notification service.
  Future<void> init() async {
    if (kIsWeb) return;
    if (_isDesktop) {
      await localNotifier.setup(
        appName: 'FlockKeeper',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } else if (_isMobile) {
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      );

      if (Platform.isIOS) {
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (Platform.isAndroid) {
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    }
  }

  Future<void> _showMobileNotification(
    int id,
    String title,
    String body,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'flockkeeper_reminders',
      'FlockKeeper Alerts',
      channelDescription: 'Alerts for reminders and inventory items',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  /// Starts the background periodic scan for due reminders.
  void startPeriodicChecks() {
    _periodicTimer?.cancel();
    
    // Perform an initial scan shortly after startup
    Future.delayed(const Duration(seconds: 3), () {
      checkRemindersAndNotify();
      checkInventoryAndNotify();
    });

    // Run scans every 1 hour
    _periodicTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      checkRemindersAndNotify();
      checkInventoryAndNotify();
    });
  }

  /// Stops periodic scanning.
  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Scans database for uncompleted reminders that are due and displays notifications.
  Future<void> checkRemindersAndNotify() async {
    if (!_isDesktop && !_isMobile) return;
    try {
      final now = DateTime.now();
      final upcoming = await _reminderRepository.getUpcomingActiveReminders();

      for (final reminder in upcoming) {
        if (reminder.id == null) continue;

        // Calculate the date we should start notifying the user
        final notifyStartDate = reminder.reminderDate.subtract(Duration(days: reminder.notifyDaysBefore));

        // Start of day comparison to make it trigger properly on date boundary
        final today = DateTime(now.year, now.month, now.day);
        final startNotifyDateOnly = DateTime(notifyStartDate.year, notifyStartDate.month, notifyStartDate.day);

        // Notify at most once per reminder per calendar day.
        final notifyKey = '${reminder.id}_${DateFormat('yyyy-MM-dd').format(today)}';
        if (_notifiedReminderKeys.contains(notifyKey)) continue;

        if (!today.isBefore(startNotifyDateOnly) && !reminder.isCompleted) {
          final diffDays = DateTime(reminder.reminderDate.year, reminder.reminderDate.month, reminder.reminderDate.day)
              .difference(today)
              .inDays;

          String dueText;
          if (diffDays == 0) {
            dueText = "is due today!";
          } else if (diffDays < 0) {
            dueText = "is OVERDUE by ${diffDays.abs()} days!";
          } else {
            dueText = "is due in $diffDays days (on ${DateFormat.yMMMd().format(reminder.reminderDate)})";
          }

          final targetName = reminder.animalName != null && reminder.animalName!.isNotEmpty
              ? "for ${reminder.animalName}"
              : "for the herd";

          final title = "${reminder.title} ($targetName)";
          final body = "${reminder.description ?? ''}\nScheduled date: ${DateFormat.yMMMd().format(reminder.reminderDate)} ($dueText)".trim();

          if (_isDesktop) {
            LocalNotification notification = LocalNotification(
              identifier: reminder.id.toString(),
              title: title,
              body: body,
            );

            notification.onClick = () {
              // Toast clicked logic
              debugPrint("Notification clicked: ${reminder.id}");
            };

            await notification.show();
          } else if (_isMobile) {
            await _showMobileNotification(reminder.id!, title, body);
          }
          _notifiedReminderKeys.add(notifyKey);
        }
      }
    } catch (e) {
      debugPrint("Error checking reminders: \$e");
    }
  }

  /// Scans inventory for low-stock and expiring items, notifies once per day.
  Future<void> checkInventoryAndNotify() async {
    if (!_isDesktop && !_isMobile) return;
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Low-stock items
      final lowStock = await _inventoryRepository.getLowStockItems();
      for (final item in lowStock) {
        if (item.id == null) continue;
        final key = 'low_${item.id}_$today';
        if (_notifiedInventoryKeys.contains(key)) continue;

        final qty = item.currentQuantity % 1 == 0
            ? item.currentQuantity.toInt().toString()
            : item.currentQuantity.toString();

        if (_isDesktop) {
          LocalNotification notification = LocalNotification(
            identifier: 'inv_low_${item.id}',
            title: item.isOutOfStock
                ? 'OUT OF STOCK: ${item.name}'
                : 'Low Stock: ${item.name}',
            body: item.isOutOfStock
                ? '${item.name} is out of stock! Minimum: ${item.minimumQuantity.toInt()} ${item.unit}'
                : 'Only $qty ${item.unit} left (minimum: ${item.minimumQuantity.toInt()} ${item.unit})',
          );
          await notification.show();
        } else if (_isMobile) {
          final title = item.isOutOfStock
              ? 'OUT OF STOCK: ${item.name}'
              : 'Low Stock: ${item.name}';
          final body = item.isOutOfStock
              ? '${item.name} is out of stock! Minimum: ${item.minimumQuantity.toInt()} ${item.unit}'
              : 'Only $qty ${item.unit} left (minimum: ${item.minimumQuantity.toInt()} ${item.unit})';
          await _showMobileNotification(item.id.hashCode ^ 888, title, body);
        }
        _notifiedInventoryKeys.add(key);
      }

      // Expiring items (within 7 days)
      final expiring = await _inventoryRepository.getExpiringItems(7);
      for (final item in expiring) {
        if (item.id == null || item.expirationDate == null) continue;
        final key = 'exp_${item.id}_$today';
        if (_notifiedInventoryKeys.contains(key)) continue;

        final daysLeft = item.expirationDate!.difference(DateTime.now()).inDays;
        final expText = item.isExpired
            ? 'EXPIRED on ${DateFormat.yMMMd().format(item.expirationDate!)}'
            : 'expires in $daysLeft days (${DateFormat.yMMMd().format(item.expirationDate!)})';

        if (_isDesktop) {
          LocalNotification notification = LocalNotification(
            identifier: 'inv_exp_${item.id}',
            title: item.isExpired
                ? 'EXPIRED: ${item.name}'
                : 'Expiring Soon: ${item.name}',
            body: '${item.name} $expText',
          );
          await notification.show();
        } else if (_isMobile) {
          final title = item.isExpired
              ? 'EXPIRED: ${item.name}'
              : 'Expiring Soon: ${item.name}';
          final body = '${item.name} $expText';
          await _showMobileNotification(item.id.hashCode ^ 999, title, body);
        }
        _notifiedInventoryKeys.add(key);
      }
    } catch (e) {
      debugPrint("Error checking inventory: $e");
    }
  }
}

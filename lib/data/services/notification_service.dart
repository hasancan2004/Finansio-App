// lib/data/services/notification_service.dart
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import '../../../main.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Channel IDs
  static const String _channelDailyId = 'daily_reminders';
  static const String _channelBudgetId = 'budget_alerts';
  static const String _channelTrendId = 'trend_alerts';
  static const String _channelCategoryId = 'category_alerts';
  static const String _channelDownloadId = 'download_alerts';

  // Fixed IDs
  static const int dailyReminderId = 1001;
  static const int weeklyTrendId = 1002;

  // Pref keys
  static const String _kDailyEnabled = 'notif_daily_enabled';
  static const String _kDailyHour = 'notif_daily_hour';
  static const String _kDailyMinute = 'notif_daily_minute';

  static const String _kBudgetEnabled = 'notif_budget_enabled';
  static const String _kTrendEnabled = 'notif_trend_enabled';
  static const String _kCategoryEnabled = 'notif_category_enabled';

  // Cache
  static bool _dailyEnabled = false;
  static bool _budgetEnabled = true;
  static bool _trendEnabled = true;
  static bool _categoryEnabled = true;

  static TimeOfDay _dailyTime = const TimeOfDay(hour: 21, minute: 0);

  static bool get dailyEnabled => _dailyEnabled;
  static bool get budgetEnabled => _budgetEnabled;
  static bool get trendEnabled => _trendEnabled;
  static bool get categoryEnabled => _categoryEnabled;
  static TimeOfDay get dailyTime => _dailyTime;

  // -------------------------------------------------
  // INIT
  // -------------------------------------------------
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final iconCandidates = [
        '@mipmap/ic_launcher',
        '@mipmap/launcher_icon',
        '@drawable/launch_background'
      ];
      bool isInitOk = false;

      for (String icon in iconCandidates) {
        try {
          final androidInit = AndroidInitializationSettings(icon);
          final initSettings = InitializationSettings(android: androidInit);

          await _plugin.initialize(
            initSettings,
            onDidReceiveNotificationResponse: (NotificationResponse response) async {
              final payload = response.payload;
              if (payload != null && payload.isNotEmpty) {
                debugPrint('[Notif] Bildirime tıklandı, payload: $payload');

                if (payload.startsWith('/')) {
                  globalNavigatorKey.currentState?.pushNamed(payload);
                } else {
                  await OpenFilex.open(payload);
                }
              }
            },
          );
          isInitOk = true;
          debugPrint('[Notif] Bildirim servisi şu ikonla başarıyla başlatıldı: $icon');
          break;
        } catch (e) {
          debugPrint('[Notif] İkon denemesi başarısız ($icon): $e');
        }
      }

      if (!isInitOk) {
        debugPrint('[Notif] DİKKAT: Hiçbir ikon çalışmadı, bildirimler gönderilemeyebilir!');
      }

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelDailyId,
          'Günlük Hatırlatmalar',
          description: 'Günlük harcama giriş hatırlatmaları',
          importance: Importance.defaultImportance,
        ),
      );

      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelBudgetId,
          'Bütçe Uyarıları',
          description: 'Limit aşımı ve bütçe uyarıları',
          importance: Importance.high,
        ),
      );

      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelTrendId,
          'Harcama Trendleri',
          description: 'Aylık/Haftalık trend bildirimleri',
          importance: Importance.defaultImportance,
        ),
      );

      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelCategoryId,
          'Kategori Değişimleri',
          description: 'Kategori bazlı artış/azalış uyarıları',
          importance: Importance.defaultImportance,
        ),
      );

      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelDownloadId,
          'Dosya İşlemleri',
          description: 'İndirme ve dışa aktarma bildirimleri',
          importance: Importance.high,
        ),
      );

      tz.initializeTimeZones();
      await _setupLocalTimezoneSafe();
      await loadSettings();
    } catch (e) {
      debugPrint('[Notif] init ERROR: $e');
    } finally {
      // Hata olsa da olmasa da sistemi başlatıldı kabul ediyoruz ki kilitlenmesin
      _initialized = true;
      debugPrint('[Notif] init ok. tz=${tz.local.name}');
    }
  }

  static Future<void> _setupLocalTimezoneSafe() async {
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();

      String? timeZoneName;

      if (tzResult is String) {
        timeZoneName = tzResult;
      } else {
        try {
          timeZoneName = (tzResult as dynamic).identifier as String?;
        } catch (_) {
          try {
            timeZoneName = (tzResult as dynamic).name as String?;
          } catch (_) {}
        }
      }

      if (timeZoneName == null ||
          timeZoneName.isEmpty ||
          timeZoneName == 'GMT' ||
          timeZoneName == 'UTC') {
        timeZoneName = 'Europe/Istanbul';
      }

      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('[Notif] Timezone set: $timeZoneName');
    } catch (e) {
      debugPrint('[Notif] Timezone error: $e');
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      debugPrint('[Notif] Timezone fallback: Europe/Istanbul');
    }
  }

  static Future<bool> requestPermission() async {
    try {
      await init();

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidImpl?.requestNotificationsPermission();
      debugPrint('[Notif] requestPermission -> $granted');

      // ✅ Android 12 ve altı cihazlarda "granted" null döner. 'false' değil 'true' kabul ediyoruz.
      return granted ?? true;
    } catch (e) {
      debugPrint('[Notif] requestPermission ERROR: $e');
      return true; // Hata verirse UI kilitlenmesin diye izin verilmiş gibi davranıyoruz
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      await init();

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final enabled = await androidImpl?.areNotificationsEnabled();
      debugPrint('[Notif] areNotificationsEnabled -> $enabled');
      return enabled ?? true;
    } catch (e) {
      debugPrint('[Notif] areNotificationsEnabled ERROR: $e');
      return true; // Şalterlerin bozulmaması için true dönüyoruz
    }
  }

  static Future<void> openAppNotificationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } catch (e) {
      debugPrint('[Notif] openAppNotificationSettings ERROR: $e');
    }
  }

  static Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _dailyEnabled = prefs.getBool(_kDailyEnabled) ?? false;

      final h = prefs.getInt(_kDailyHour);
      final m = prefs.getInt(_kDailyMinute);

      _dailyTime = (h != null && m != null)
          ? TimeOfDay(hour: h, minute: m)
          : const TimeOfDay(hour: 21, minute: 0);

      _budgetEnabled = prefs.getBool(_kBudgetEnabled) ?? true;
      _trendEnabled = prefs.getBool(_kTrendEnabled) ?? true;
      _categoryEnabled = prefs.getBool(_kCategoryEnabled) ?? true;
    } catch (e) {
      debugPrint('[Notif] loadSettings ERROR: $e');
    }
  }

  static Future<void> setDailyEnabled(bool enabled) async {
    try {
      await init();

      _dailyEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDailyEnabled, enabled);

      if (!enabled) {
        await cancelDailyReminder();
      } else {
        await ensureDailyScheduled();
      }
    } catch (e) {
      debugPrint('[Notif] setDailyEnabled ERROR: $e');
    }
  }

  static Future<void> setDailyTime(TimeOfDay time) async {
    try {
      await init();

      _dailyTime = time;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDailyHour, time.hour);
      await prefs.setInt(_kDailyMinute, time.minute);

      if (_dailyEnabled) {
        await ensureDailyScheduled();
      }
    } catch (e) {
      debugPrint('[Notif] setDailyTime ERROR: $e');
    }
  }

  static Future<void> setBudgetEnabled(bool enabled) async {
    try {
      await init();

      _budgetEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBudgetEnabled, enabled);
    } catch (e) {
      debugPrint('[Notif] setBudgetEnabled ERROR: $e');
    }
  }

  static Future<void> setTrendEnabled(bool enabled) async {
    try {
      await init();

      _trendEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrendEnabled, enabled);

      await ensureWeeklyTrendScheduled();
    } catch (e) {
      debugPrint('[Notif] setTrendEnabled ERROR: $e');
    }
  }

  static Future<void> setCategoryEnabled(bool enabled) async {
    try {
      await init();

      _categoryEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCategoryEnabled, enabled);
    } catch (e) {
      debugPrint('[Notif] setCategoryEnabled ERROR: $e');
    }
  }

  static AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      playSound: true,
    );
  }

  static NotificationDetails _dailyDetails() => NotificationDetails(
    android: _androidDetails(
      channelId: _channelDailyId,
      channelName: 'Günlük Hatırlatmalar',
      channelDesc: 'Günlük harcama giriş hatırlatmaları',
    ),
  );

  static NotificationDetails _budgetDetails() => NotificationDetails(
    android: _androidDetails(
      channelId: _channelBudgetId,
      channelName: 'Bütçe Uyarıları',
      channelDesc: 'Limit aşımı ve bütçe uyarıları',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static NotificationDetails _trendDetails() => NotificationDetails(
    android: _androidDetails(
      channelId: _channelTrendId,
      channelName: 'Harcama Trendleri',
      channelDesc: 'Aylık/Haftalık trend bildirimleri',
    ),
  );

  static NotificationDetails _categoryDetails() => NotificationDetails(
    android: _androidDetails(
      channelId: _channelCategoryId,
      channelName: 'Kategori Değişimleri',
      channelDesc: 'Kategori bazlı artış/azalış uyarıları',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static NotificationDetails _downloadDetails() => NotificationDetails(
    android: _androidDetails(
      channelId: _channelDownloadId,
      channelName: 'Dosya İşlemleri',
      channelDesc: 'İndirme ve dışa aktarma bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> showDownloadNotification(String filePath) async {
    try {
      await init();

      final fileName = filePath.split('/').last;

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'İndirme Başarılı ✅',
        '$fileName cihazına kaydedildi. Açmak için dokun.',
        _downloadDetails(),
        payload: filePath,
      );
    } catch (e) {
      debugPrint('[Notif] showDownloadNotification ERROR: $e');
    }
  }

  // -------------------------------------------------
  // DEBUG
  // -------------------------------------------------
  static Future<void> debugShowNow() async {
    try {
      await init();
      await _plugin.show(
        9999,
        'Test Bildirimi ✅',
        'Eğer bunu görüyorsan bildirim sistemi çalışıyor.',
        _dailyDetails(),
      );
    } catch (e) {
      debugPrint('[Notif] debugShowNow ERROR: $e');
    }
  }

  static Future<void> debugWeeklySummaryNow() async {
    try {
      await init();
      await showWeeklySummary(
        income: 12500,
        expense: -8400,
      );
    } catch (e) {
      debugPrint('[Notif] debugWeeklySummaryNow ERROR: $e');
    }
  }

  static Future<void> debugCategorySpikeNow() async {
    try {
      await init();
      await showCategorySpike(
        categoryName: 'Yemek',
        changePercent: 42.5,
        thisPeriodExpense: 7500,
        lastPeriodExpense: 5260,
      );
    } catch (e) {
      debugPrint('[Notif] debugCategorySpikeNow ERROR: $e');
    }
  }

  static Future<void> debugPendingNotifications() async {
    try {
      await init();

      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('[Notif] pending count = ${pending.length}');

      for (final item in pending) {
        debugPrint(
          '[Notif] pending -> id=${item.id}, title=${item.title}, body=${item.body}',
        );
      }
    } catch (e) {
      debugPrint('[Notif] debugPendingNotifications ERROR: $e');
    }
  }

  // -------------------------------------------------
  // DAILY REMINDER
  // -------------------------------------------------
  static Future<void> ensureDailyScheduled() async {
    try {
      await init();
      await loadSettings();

      if (!_dailyEnabled) {
        await cancelDailyReminder();
        return;
      }

      final enabled = await areNotificationsEnabled();
      if (!enabled) return;

      await cancelDailyReminder();

      await scheduleDailyReminder(
        timeOfDay: _dailyTime,
        title: 'Günün harcamalarını ekledin mi?',
        body: 'Bugünün gelir/giderlerini Finansio\'ya kaydetmeyi unutma.',
      );
    } catch (e, st) {
      debugPrint('[Notif] ensureDailyScheduled ERROR: $e');
    }
  }

  static Future<void> scheduleDailyReminder({
    required TimeOfDay timeOfDay,
    required String title,
    required String body,
  }) async {
    try {
      await init();

      final now = tz.TZDateTime.now(tz.local);

      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      if (scheduled.isBefore(now) || scheduled.isAtSameMomentAs(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        dailyReminderId,
        title,
        body,
        scheduled,
        _dailyDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('[Notif] scheduleDailyReminder ERROR: $e');
    }
  }

  static Future<void> cancelDailyReminder() async {
    try {
      await init();
      await _plugin.cancel(dailyReminderId);
    } catch (e) {
      debugPrint('[Notif] cancelDailyReminder ERROR: $e');
    }
  }

  // -------------------------------------------------
  // HAFTALIK BİLDİRİM (PAZAR 19:00)
  // -------------------------------------------------
  static Future<void> ensureWeeklyTrendScheduled() async {
    try {
      await init();
      await loadSettings();

      if (!_trendEnabled) {
        await _plugin.cancel(weeklyTrendId);
        return;
      }

      final enabled = await areNotificationsEnabled();
      if (!enabled) return;

      await _plugin.cancel(weeklyTrendId);

      tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0);

      while (scheduledDate.weekday != DateTime.sunday || scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        weeklyTrendId,
        'Haftalık Finans Özeti 📊',
        'Geçen hafta ne kadar harcadın? Cebinde ne kaldı? Özetini görmek için hemen dokun. 👀',
        scheduledDate,
        _trendDetails(),
        payload: '/weekly_summary',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      debugPrint('[Notif] Haftalık trend bildirimi Pazar 19:00 için kuruldu.');
    } catch (e) {
      debugPrint('[Notif] ensureWeeklyTrendScheduled ERROR: $e');
    }
  }

  // -------------------------------------------------
  // BUDGET
  // -------------------------------------------------
  static Future<void> showBudgetExceeded({
    required String categoryName,
    required double spent,
    required double limit,
  }) async {
    try {
      await init();
      await loadSettings();

      if (!_budgetEnabled) return;

      final formatter = NumberFormat("#,##0", "tr_TR");

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Bütçe Limiti Aşıldı 🚨',
        '${formatter.format(limit)} ₺\'lik $categoryName bütçeni, toplam ${formatter.format(spent)} ₺ harcayarak aştın. 💸',
        _budgetDetails(),
        payload: '/budgets',
      );
    } catch (e) {
      debugPrint('[Notif] showBudgetExceeded ERROR: $e');
    }
  }

  static Future<void> showBudgetWarning({
    required String categoryName,
    required double percent,
  }) async {
    try {
      await init();
      await loadSettings();

      if (!_budgetEnabled) return;

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Bütçe Uyarısı ⚠️',
        '$categoryName bütçenin %${percent.toStringAsFixed(0)}\'sine ulaştın. Harcamalarına dikkat etmelisin! 👀',
        _budgetDetails(),
        payload: '/budgets',
      );
    } catch (e) {
      debugPrint('[Notif] showBudgetWarning ERROR: $e');
    }
  }

  // -------------------------------------------------
  // TREND / WEEKLY SUMMARY
  // -------------------------------------------------
  static Future<void> showWeeklySummary({
    required double income,
    required double expense,
  }) async {
    try {
      await init();
      await loadSettings();

      if (!_trendEnabled) return;

      final absExpense = expense.abs();
      final net = income + expense;

      final body = '📊 Haftalık Finans Özeti\n\n'
          '• Gelir: ${income.toStringAsFixed(0)} ₺\n'
          '• Gider: ${absExpense.toStringAsFixed(0)} ₺\n'
          '• Net: ${net.toStringAsFixed(0)} ₺';

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Haftalık Finans Özeti',
        body,
        _trendDetails(),
        payload: '/weekly_summary',
      );
    } catch (e) {
      debugPrint('[Notif] showWeeklySummary ERROR: $e');
    }
  }

  // -------------------------------------------------
  // CATEGORY SPIKE (KATEGORİ DEĞİŞİM UYARISI)
  // -------------------------------------------------
  static Future<void> showCategorySpike({
    required String categoryName,
    required double changePercent,
    required double thisPeriodExpense,
    required double lastPeriodExpense,
  }) async {
    try {
      await init();
      await loadSettings();

      if (!_categoryEnabled) return;

      final trendWord = changePercent >= 0
          ? '%${changePercent.toStringAsFixed(1)} artış'
          : '%${(-changePercent).toStringAsFixed(1)} azalış';

      final body = '$categoryName kategorisinde $trendWord var.\n'
          'Geçen ay: ${lastPeriodExpense.toStringAsFixed(0)} ₺ • Bu ay: ${thisPeriodExpense.toStringAsFixed(0)} ₺';

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Kategori Harcama Değişimi 📈',
        body,
        _categoryDetails(),
        payload: '/category_spike',
      );
    } catch (e) {
      debugPrint('[Notif] showCategorySpike ERROR: $e');
    }
  }
}
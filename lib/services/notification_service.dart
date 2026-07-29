// lib/services/notification_service.dart
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:open_filex/open_filex.dart'; // ✅ OPEN_FILEX PAKETİ EKLENDİ

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

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    // ✅ BİLDİRİME TIKLANDIĞINDA ÇALIŞACAK FONKSİYON (PAYLOAD YAKALAMA)
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null && response.payload!.isNotEmpty) {
          debugPrint('[Notif] Dosya açılıyor: ${response.payload}');
          // OpenFilex cihazdaki "Birlikte Aç" menüsünü (PDF Okuyucuları) tetikler
          await OpenFilex.open(response.payload!); // ✅ SONUNA SADECE ÜNLEM (!) EKLENDİ
        }
      },
    );

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

    _initialized = true;
    debugPrint('[Notif] init ok. tz=${tz.local.name}');
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

  // -------------------------------------------------
  // PERMISSION
  // -------------------------------------------------
  static Future<bool> requestPermission() async {
    await init();

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidImpl?.requestNotificationsPermission();
    debugPrint('[Notif] requestPermission -> $granted');
    return granted ?? false;
  }

  static Future<bool> areNotificationsEnabled() async {
    await init();

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final enabled = await androidImpl?.areNotificationsEnabled();
    debugPrint('[Notif] areNotificationsEnabled -> $enabled');
    return enabled ?? true;
  }

  static Future<void> openAppNotificationSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  // -------------------------------------------------
  // SETTINGS
  // -------------------------------------------------
  static Future<void> loadSettings() async {
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

    debugPrint(
      '[Notif] loadSettings -> daily=$_dailyEnabled time=${_dailyTime.hour}:${_dailyTime.minute}, '
          'budget=$_budgetEnabled, trend=$_trendEnabled, category=$_categoryEnabled',
    );
  }

  static Future<void> setDailyEnabled(bool enabled) async {
    await init();

    _dailyEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyEnabled, enabled);

    if (!enabled) {
      await cancelDailyReminder();
      debugPrint('[Notif] Daily reminder disabled');
    } else {
      await ensureDailyScheduled();
      debugPrint('[Notif] Daily reminder enabled + scheduled');
    }
  }

  static Future<void> setDailyTime(TimeOfDay time) async {
    await init();

    _dailyTime = time;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyHour, time.hour);
    await prefs.setInt(_kDailyMinute, time.minute);

    debugPrint('[Notif] Daily time updated -> ${time.hour}:${time.minute}');

    if (_dailyEnabled) {
      await ensureDailyScheduled();
    }
  }

  static Future<void> setBudgetEnabled(bool enabled) async {
    await init();

    _budgetEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBudgetEnabled, enabled);
  }

  static Future<void> setTrendEnabled(bool enabled) async {
    await init();

    _trendEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTrendEnabled, enabled);
  }

  static Future<void> setCategoryEnabled(bool enabled) async {
    await init();

    _categoryEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCategoryEnabled, enabled);
  }

  // -------------------------------------------------
  // DETAILS
  // -------------------------------------------------
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
    ),
  );

  // ✅ YENİ: İndirme Bildirimleri Detayları
  static NotificationDetails _downloadDetails() => NotificationDetails(
    android: _androidDetails(
      channelId: _channelDownloadId,
      channelName: 'Dosya İşlemleri',
      channelDesc: 'İndirme ve dışa aktarma bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // -------------------------------------------------
  // ✅ YENİ: DOSYA İNDİRME BİLDİRİMİ GÖSTERME
  // -------------------------------------------------
  static Future<void> showDownloadNotification(String filePath) async {
    await init();

    // Uzun yol yerine sadece dosyanın adını alıyoruz
    final fileName = filePath.split('/').last;

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'İndirme Başarılı ✅',
      '$fileName cihazına kaydedildi. Açmak için dokun.',
      _downloadDetails(),
      payload: filePath, // ✅ PAYLOAD OLARAK DOSYA YOLUNU VERİYORUZ
    );
  }

  // -------------------------------------------------
  // DEBUG
  // -------------------------------------------------
  static Future<void> debugShowNow() async {
    await init();
    debugPrint('[Notif] debugShowNow()');

    await _plugin.show(
      9999,
      'Test Bildirimi ✅',
      'Eğer bunu görüyorsan bildirim sistemi çalışıyor.',
      _dailyDetails(),
    );
  }

  static Future<void> debugWeeklySummaryNow() async {
    await init();
    debugPrint('[Notif] debugWeeklySummaryNow()');

    await showWeeklySummary(
      income: 12500,
      expense: -8400,
    );
  }

  static Future<void> debugPeriodSummaryNow() async {
    await init();
    debugPrint('[Notif] debugPeriodSummaryNow()');

    await showPeriodSummary(
      periodLabel: 'Mart 2026',
      income: 52000,
      expense: -38950,
    );
  }

  static Future<void> debugPendingNotifications() async {
    await init();

    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('[Notif] pending count = ${pending.length}');

    for (final item in pending) {
      debugPrint(
        '[Notif] pending -> id=${item.id}, title=${item.title}, body=${item.body}',
      );
    }
  }

  // -------------------------------------------------
  // DAILY REMINDER
  // -------------------------------------------------
  static Future<void> ensureDailyScheduled() async {
    await init();
    await loadSettings();

    if (!_dailyEnabled) {
      debugPrint('[Notif] daily disabled -> cancel + skip');
      await cancelDailyReminder();
      return;
    }

    final enabled = await areNotificationsEnabled();
    if (!enabled) {
      debugPrint('[Notif] notifications disabled on system -> schedule skipped');
      return;
    }

    await cancelDailyReminder();

    try {
      await scheduleDailyReminder(
        timeOfDay: _dailyTime,
        title: 'Günün harcamalarını ekledin mi?',
        body: 'Bugünün gelir/giderlerini Finansio\'ya kaydetmeyi unutma.',
      );

      await debugPendingNotifications();
    } catch (e, st) {
      debugPrint('[Notif] ensureDailyScheduled ERROR: $e');
      debugPrint('$st');
    }
  }

  static Future<void> scheduleDailyReminder({
    required TimeOfDay timeOfDay,
    required String title,
    required String body,
  }) async {
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

    debugPrint('[Notif] now=$now');
    debugPrint('[Notif] scheduling daily at=$scheduled');
    debugPrint('[Notif] tz=${tz.local.name}');

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

    debugPrint('[Notif] Daily scheduled successfully');
  }

  static Future<void> cancelDailyReminder() async {
    await init();
    await _plugin.cancel(dailyReminderId);
    debugPrint('[Notif] cancelDailyReminder()');
  }

  // -------------------------------------------------
  // BUDGET
  // -------------------------------------------------
  static Future<void> showBudgetExceeded({
    required String categoryName,
    required double spent,
    required double limit,
  }) async {
    await init();
    await loadSettings();

    if (!_budgetEnabled) {
      debugPrint('[Notif] Budget notification skipped: disabled');
      return;
    }

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Bütçe Limiti Aşıldı',
      '$categoryName kategorisinde ${spent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} ₺ harcama yaptın.',
      _budgetDetails(),
    );
  }

  static Future<void> showBudgetWarning({
    required String categoryName,
    required double percent,
  }) async {
    await init();
    await loadSettings();

    if (!_budgetEnabled) {
      debugPrint('[Notif] Budget warning skipped: disabled');
      return;
    }

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Bütçe Uyarısı',
      '$categoryName kategorisinde bütçenin %${percent.toStringAsFixed(0)}\'ine ulaştın.',
      _budgetDetails(),
    );
  }

  // -------------------------------------------------
  // TREND / PERIOD
  // -------------------------------------------------
  static Future<void> showWeeklySummary({
    required double income,
    required double expense,
  }) async {
    await init();
    await loadSettings();

    if (!_trendEnabled) {
      debugPrint('[Notif] Weekly summary skipped: disabled');
      return;
    }

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
    );
  }

  static Future<void> showPeriodSummary({
    required String periodLabel,
    required double income,
    required double expense,
  }) async {
    await init();
    await loadSettings();

    if (!_trendEnabled) {
      debugPrint('[Notif] Period summary skipped: disabled');
      return;
    }

    final absExpense = expense.abs();
    final net = income + expense;

    final body = '📅 $periodLabel Özeti\n\n'
        '• Toplam Gelir: ${income.toStringAsFixed(0)} ₺\n'
        '• Toplam Gider: ${absExpense.toStringAsFixed(0)} ₺\n'
        '• Net: ${net.toStringAsFixed(0)} ₺';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '$periodLabel Özeti',
      body,
      _trendDetails(),
    );
  }

  // -------------------------------------------------
  // CATEGORY SPIKE
  // -------------------------------------------------
  static Future<void> showCategorySpike({
    required String categoryName,
    required double changePercent,
    required double thisPeriodExpense,
    required double lastPeriodExpense,
  }) async {
    await init();
    await loadSettings();

    if (!_categoryEnabled) {
      debugPrint('[Notif] Category spike skipped: disabled');
      return;
    }

    final trendWord = changePercent >= 0
        ? '%${changePercent.toStringAsFixed(1)} artış'
        : '%${(-changePercent).toStringAsFixed(1)} azalış';

    final body = '$categoryName kategorisinde $trendWord var.\n'
        'Önceki dönem: ${lastPeriodExpense.toStringAsFixed(0)} ₺\n'
        'Bu dönem: ${thisPeriodExpense.toStringAsFixed(0)} ₺';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Kategori Harcama Değişimi',
      body,
      _categoryDetails(),
    );
  }
}
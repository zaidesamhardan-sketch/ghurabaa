import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

// ════════════════════════════════════════════════
//  ENTRY POINT
// ════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const GhurabaApp());
}

// ════════════════════════════════════════════════
//  THEME & DESIGN TOKENS
// ════════════════════════════════════════════════
class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF1C1208);
  static const Color oud = Color(0xFF3D2712);
  static const Color cedar = Color(0xFF6B4226);
  static const Color brass = Color(0xFFB8893A);
  static const Color sand = Color(0xFFE8D5B0);
  static const Color parchment = Color(0xFFF7F1E6);
  static const Color cream = Color(0xFFFCF9F3);
  static const Color mist = Color(0xFFEEE5D3);
  static const Color success = Color(0xFF4A7C59);
  static const Color successBg = Color(0xFFE8F5EE);
  static const Color aiBlue = Color(0xFF1A3A5C);
  static const Color aiBlueBg = Color(0xFFE8F0F7);
}

class AppTextStyles {
  AppTextStyles._();

  static const String _amiri = 'Amiri';
  static const String _scheherazade = 'ScheherazadeNew';

  static const TextStyle displayAr = TextStyle(
    fontFamily: _amiri,
    fontSize: 38,
    fontWeight: FontWeight.bold,
    color: AppColors.oud,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static const TextStyle headingAr = TextStyle(
    fontFamily: _amiri,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.oud,
    height: 1.5,
  );

  static const TextStyle bodyAr = TextStyle(
    fontFamily: _amiri,
    fontSize: 18,
    color: AppColors.ink,
    height: 1.8,
  );

  static const TextStyle quranAr = TextStyle(
    fontFamily: _scheherazade,
    fontSize: 20,
    color: AppColors.oud,
    height: 2.0,
  );

  static const TextStyle labelAr = TextStyle(
    fontFamily: _amiri,
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.cedar,
    letterSpacing: 0.3,
  );

  static const TextStyle captionAr = TextStyle(
    fontFamily: _amiri,
    fontSize: 12,
    color: AppColors.cedar,
  );
}

// ════════════════════════════════════════════════
//  VIBRATION HELPER
// ════════════════════════════════════════════════
Future<void> vibrateIfAvailable({int duration = 30, int amplitude = 80}) async {
  try {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: duration, amplitude: amplitude);
    }
  } catch (_) {}
}

// ════════════════════════════════════════════════
//  HIJRI DATE SERVICE
// ════════════════════════════════════════════════
class HijriService {
  HijriService._();

  static String getTodayHijri() {
    try {
      final h = HijriCalendar.now();
      const months = [
        'محرم',
        'صفر',
        'ربيع الأول',
        'ربيع الآخر',
        'جمادى الأولى',
        'جمادى الآخرة',
        'رجب',
        'شعبان',
        'رمضان',
        'شوال',
        'ذو القعدة',
        'ذو الحجة',
      ];
      final monthName = months[(h.hMonth - 1).clamp(0, 11)];
      return '${h.hDay} $monthName ${h.hYear} هـ';
    } catch (_) {
      return '';
    }
  }
}

// ════════════════════════════════════════════════
//  PRAYER TIME SERVICE
// ════════════════════════════════════════════════
class PrayerTimeService {
  PrayerTimeService._();

  static PrayerTimes calculate({
    required double latitude,
    required double longitude,
  }) {
    final coordinates = Coordinates(latitude, longitude);
    final date = DateComponents.from(DateTime.now());
    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi;
    return PrayerTimes(coordinates, date, params);
  }

  static Map<String, DateTime> toMap(PrayerTimes pt) => {
        'الفجر': pt.fajr,
        'الظهر': pt.dhuhr,
        'العصر': pt.asr,
        'المغرب': pt.maghrib,
        'العشاء': pt.isha,
      };

  static (String, Duration) nextPrayer(Map<String, DateTime> times) {
    final now = DateTime.now();
    for (final entry in times.entries) {
      if (entry.value.isAfter(now)) {
        return (entry.key, entry.value.difference(now));
      }
    }
    final fajrKey = times.keys.first;
    final fajrTime = times[fajrKey]!.add(const Duration(days: 1));
    return (fajrKey, fajrTime.difference(now));
  }
}

// ════════════════════════════════════════════════
//  NOTIFICATIONS SERVICE
// ════════════════════════════════════════════════
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings, // ✅ named argument
      onDidReceiveNotificationResponse: (_) {},
    );
  }

  static Future<void> showAdhanNotification(String prayerName) async {
    const details = AndroidNotificationDetails(
      'adhan_v2',
      'أوقات الصلاة',
      channelDescription: 'إشعارات أذان الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      color: AppColors.oud,
    );
    await _plugin.show(
      id: 0, // ✅
      title: 'حان وقت $prayerName', // ✅
      body: 'الله أكبر، الله أكبر', // ✅
      notificationDetails: const NotificationDetails(android: details), // ✅
    );
  }

  static Future<void> showPrePrayerNotification(
    String prayerName,
    int minutes,
  ) async {
    const details = AndroidNotificationDetails(
      'pre_prayer_v1',
      'تذكير ما قبل الصلاة',
      channelDescription: 'تذكير بالاستعداد للصلاة',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      color: AppColors.brass,
    );
    await _plugin.show(
      id: 1,
      title: 'تذكير: $prayerName بعد $minutes دقائق',
      body: 'حان وقت الوضوء والاستعداد للصلاة 🕌',
      notificationDetails: const NotificationDetails(android: details),
    );
  }
}

// ════════════════════════════════════════════════
//  STATS & GAMIFICATION SERVICE
// ════════════════════════════════════════════════
class StatsService {
  StatsService._();

  static Future<Map<String, dynamic>> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    // Load daily prayer completion (last 7 days)
    final List<double> weekData = [];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final k = '${d.year}-${d.month}-${d.day}';
      final count = prefs.getInt('prayers_$k') ?? 0;
      weekData.add(count.toDouble());
    }

    final totalDhikrDays = prefs.getInt('total_dhikr_days') ?? 0;
    final streak = prefs.getInt('streak') ?? 0;
    final totalPrayers = prefs.getInt('total_prayers') ?? 0;
    final todayPrayers = prefs.getInt('prayers_$todayKey') ?? 0;

    return {
      'weekData': weekData,
      'totalDhikrDays': totalDhikrDays,
      'streak': streak,
      'totalPrayers': totalPrayers,
      'todayPrayers': todayPrayers,
      'todayKey': todayKey,
    };
  }

  static Future<void> markPrayerDone(String todayKey) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('prayers_$todayKey') ?? 0;
    if (current >= 5) return;
    await prefs.setInt('prayers_$todayKey', current + 1);
    await prefs.setInt(
      'total_prayers',
      (prefs.getInt('total_prayers') ?? 0) + 1,
    );
    if (current + 1 == 5) {
      await prefs.setInt('streak', (prefs.getInt('streak') ?? 0) + 1);
    }
  }

  static Future<void> markDhikrCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'total_dhikr_days',
      (prefs.getInt('total_dhikr_days') ?? 0) + 1,
    );
  }

  static List<Map<String, String>> getBadges(Map<String, dynamic> stats) {
    final badges = <Map<String, String>>[];
    final streak = stats['streak'] as int;
    final total = stats['totalPrayers'] as int;
    final dhikr = stats['totalDhikrDays'] as int;

    if (streak >= 1) {
      badges.add({
        'icon': '🌙',
        'title': 'مواظب',
        'desc': 'يوم كامل من الصلوات',
      });
    }
    if (streak >= 7) {
      badges.add({'icon': '⭐', 'title': 'أسبوع نور', 'desc': '٧ أيام متتالية'});
    }
    if (streak >= 30) {
      badges.add({
        'icon': '🏆',
        'title': 'شهر إيمان',
        'desc': '٣٠ يوماً متتالياً',
      });
    }
    if (total >= 50) {
      badges.add({
        'icon': '💎',
        'title': 'خمسون صلاة',
        'desc': 'أتممت ٥٠ صلاة',
      });
    }
    if (dhikr >= 3) {
      badges.add({
        'icon': '📿',
        'title': 'ذاكر',
        'desc': 'ٍأتممت الأذكار ٣ مرات',
      });
    }
    if (dhikr >= 10) {
      badges.add({
        'icon': '🌟',
        'title': 'كثير الذكر',
        'desc': 'أتممت الأذكار ١٠ مرات',
      });
    }

    return badges;
  }
}

// ════════════════════════════════════════════════
//  AI COMPANION SERVICE
// ════════════════════════════════════════════════
class AiCompanionService {
  AiCompanionService._();

  // ردود ذكية بناءً على الكلمات الدلالية في رسالة المستخدم
  static Map<String, dynamic> getResponse(String userMessage) {
    final msg = userMessage.toLowerCase();

    // ضيق / حزن / قلق
    if (_contains(msg, [
      'ضيق',
      'حزن',
      'حزين',
      'تعبان',
      'تعب',
      'مهموم',
      'هموم',
      'هم',
      'غم',
      'مضايق',
    ])) {
      return {
        'reply': 'أخي الكريم، اعلم أن الضيق مؤقت والفرج آتٍ بإذن الله.\n\n'
            'قال تعالى: ﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾\n\n'
            'أنصحك بالإكثار من الاستغفار، فقد قال النبي ﷺ:\n"من لزم الاستغفار جعل الله له من كل ضيق مخرجاً".',
        'suggestion':
            'أَسْتَغْفِرُ اللهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ.',
        'count': 70,
        'icon': '🤲',
        'category': 'استغفار',
      };
    }

    // خوف / قلق
    if (_contains(msg, [
      'خائف',
      'خوف',
      'قلق',
      'قلقان',
      'أخاف',
      'أخشى',
      'خشية',
      'توتر',
      'متوتر',
    ])) {
      return {
        'reply': 'لا تخف، فالله معك في كل لحظة.\n\n'
            'قال تعالى: ﴿وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ﴾\n\n'
            'ردد هذا الذكر لتطمئن قلبك:',
        'suggestion': 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ.',
        'count': 40,
        'icon': '🛡️',
        'category': 'توكل',
      };
    }

    // وحدة / غربة
    if (_contains(msg, [
      'وحيد',
      'وحدة',
      'وحده',
      'غريب',
      'غربة',
      'مغترب',
      'بعيد',
      'مش موجود',
    ])) {
      return {
        'reply': 'الغربة في هذه الدنيا علامة صدق الإيمان.\n\n'
            'قال النبي ﷺ: "طوبى للغرباء".\n\n'
            'اعلم أن الله أقرب إليك من حبل الوريد، وهذا الذكر يُحضر قلبك معه:',
        'suggestion':
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، عَلَيْكَ تَوَكَّلْتُ وَأَنْتَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
        'count': 7,
        'icon': '💙',
        'category': 'اطمئنان',
      };
    }

    // ذنب / معصية / خطيئة
    if (_contains(msg, [
      'ذنب',
      'ذنوب',
      'معصية',
      'أخطأت',
      'خطيئة',
      'خطأ',
      'نادم',
      'ندم',
      'تبت',
      'توبة',
    ])) {
      return {
        'reply': 'التوبة باب الرحمة المفتوح دائماً.\n\n'
            'قال تعالى: ﴿قُلْ يَا عِبَادِيَ الَّذِينَ أَسْرَفُوا عَلَىٰ أَنفُسِهِمْ لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ﴾\n\n'
            'استغفر الله واعزم على عدم العودة، وردد سيد الاستغفار:',
        'suggestion':
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي، فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
        'count': 3,
        'icon': '🕊️',
        'category': 'توبة واستغفار',
      };
    }

    // فرح / سعادة / حمد
    if (_contains(msg, [
      'سعيد',
      'سعادة',
      'فرحان',
      'فرح',
      'الحمد',
      'شاكر',
      'نعمة',
      'بخير',
      'تمام',
      'ممتاز',
    ])) {
      return {
        'reply': 'الحمد لله على نعمة السعادة! اشكر الله يزدك.\n\n'
            'قال تعالى: ﴿لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ﴾\n\n'
            'وأحسن الشكر أن تردد:',
        'suggestion':
            'الْحَمْدُ لِلَّهِ حَمْدًا كَثِيرًا طَيِّبًا مُبَارَكًا فِيهِ.',
        'count': 10,
        'icon': '🌟',
        'category': 'شكر وحمد',
      };
    }

    // مرض / صحة
    if (_contains(msg, [
      'مريض',
      'مرض',
      'وجع',
      'ألم',
      'تعب',
      'صحة',
      'علاج',
      'شفاء',
    ])) {
      return {
        'reply': 'شفاك الله وعافاك. المرض كفارة وطهارة.\n\n'
            'قال النبي ﷺ: "ما يصيب المسلم من وصب ولا نصب... إلا كفّر الله به من خطاياه".\n\n'
            'ردد دعاء الشفاء:',
        'suggestion':
            'اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا.',
        'count': 7,
        'icon': '💚',
        'category': 'دعاء الشفاء',
      };
    }

    // عمل / رزق / مال
    if (_contains(msg, [
      'رزق',
      'مال',
      'عمل',
      'وظيفة',
      'فقر',
      'ضيقة',
      'دين',
      'ديون',
    ])) {
      return {
        'reply': 'الرزق بيد الله وحده، وقد ضمنه لكل مخلوق.\n\n'
            'قال تعالى: ﴿وَمَا مِن دَابَّةٍ فِي الْأَرْضِ إِلَّا عَلَى اللَّهِ رِزْقُهَا﴾\n\n'
            'أكثر من هذا الذكر ففيه سر عجيب في توسيع الرزق:',
        'suggestion':
            'اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ، وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ.',
        'count': 10,
        'icon': '🌿',
        'category': 'دعاء الرزق',
      };
    }

    // أذكار الصباح
    if (_contains(msg, ['صباح', 'فجر', 'بوكرة', 'فجرت', 'أذكار'])) {
      return {
        'reply': 'صباح النور والإيمان!\n\n'
            'الإنسان الذي يبدأ يومه بأذكار الصباح يمشي بحصن من الله طوال يومه.\n\n'
            'ابدأ بهذا الذكر العظيم:',
        'suggestion':
            'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ.',
        'count': 1,
        'icon': '☀️',
        'category': 'أذكار الصباح',
      };
    }

    // مساء / ليل
    if (_contains(msg, [
      'مساء',
      'عشاء',
      'مغرب',
      'ليل',
      'نوم',
      'نايم',
      'ليلة',
    ])) {
      return {
        'reply': 'ليلة مباركة! اختم يومك بذكر الله وستنام بقلب مطمئن.\n\n'
            'قال النبي ﷺ أنه كان يقرأ المعوذتين والإخلاص قبل النوم وينفث في راحتيه.\n\n'
            'ابدأ بذكر المساء:',
        'suggestion':
            'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ.',
        'count': 1,
        'icon': '🌙',
        'category': 'أذكار المساء',
      };
    }

    // سلام عليكم / تحية
    if (_contains(msg, ['السلام', 'مرحبا', 'هلا', 'أهلا', 'هلو', 'كيف'])) {
      return {
        'reply': 'وعليكم السلام ورحمة الله وبركاته 🌟\n\n'
            'أهلاً وسهلاً بك في رحاب غُرَبَاء.\n\n'
            'أنا رفيقك الروحي، يمكنك مشاركتي ما تشعر به أو سؤالي عن دعاء أو ذكر مناسب لحالك.',
        'suggestion': '',
        'count': 0,
        'icon': '✨',
        'category': '',
      };
    }

    // رد افتراضي
    return {
      'reply': 'بارك الله فيك أخي الكريم.\n\n'
          'أنا هنا لأكون رفيقك الروحي. أخبرني كيف حالك أو ما الذي تشعر به، '
          'وسأقترح عليك الذكر أو الدعاء المناسب لحالك.\n\n'
          'يمكنك قول مثلاً: "أشعر بضيق" أو "قلق من شيء" أو "أريد أذكار الصباح".',
      'suggestion':
          'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      'count': 10,
      'icon': '💬',
      'category': 'ذكر عام',
    };
  }

  static bool _contains(String msg, List<String> keywords) =>
      keywords.any((k) => msg.contains(k));
}

// ════════════════════════════════════════════════
//  SPLASH SCREEN
// ════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _ornamentFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _ornamentFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2800), _navigateToHome);
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, error, stack) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SplashBgPainter()),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 32),
                    const Text('غُـرَبَـاء', style: AppTextStyles.displayAr),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _ornamentFade,
                      child: _buildOrnament(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CustomPaint(
            size: Size(160, 160),
            painter: OrnamentalRingPainter(color: AppColors.brass, rings: 3),
          ),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cream,
              border: Border.all(color: AppColors.brass, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.oud.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.mosque, size: 55, color: AppColors.oud),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrnament() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _hLine(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: CustomPaint(
                size: Size(12, 12),
                painter: _DiamondPainter(AppColors.brass),
              ),
            ),
            _hLine(),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.brass.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'تطوير المهندس زيد حردان',
            style: AppTextStyles.labelAr,
          ),
        ),
      ],
    );
  }

  Widget _hLine() => Container(
        width: 50,
        height: 1,
        color: AppColors.brass.withValues(alpha: 0.5),
      );
}

// ──────────────────────────────────────────────
//  Painters
// ──────────────────────────────────────────────
class _SplashBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brass.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.1),
        size.width * 0.15 * (i + 1),
        paint,
      );
    }
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.85),
        size.width * 0.12 * (i + 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DiamondPainter extends CustomPainter {
  final Color color;
  const _DiamondPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ════════════════════════════════════════════════
//  HOME SCREEN
// ════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _tab = 0;
  late final TabController _tabCtrl;

  // Prayer state
  Map<String, DateTime> _prayerTimes = {};
  String _nextPrayerName = 'الفجر';
  Duration _remaining = Duration.zero;
  String _locationStatus = 'جاري تحديد موقعك…';
  bool _locationLoaded = false;
  Timer? _countdown;
  bool _prePrayerAlertSent = false;

  // Sebha state
  int _sebhaCount = 0;
  int _sebhaPhase = 0;

  static const List<String> _sebhaTexts = [
    'سُبْحَانَ اللهِ',
    'الْحَمْدُ لِلَّهِ',
    'اللهُ أَكْبَرُ',
  ];

  // Audio
  final AudioPlayer _audio = AudioPlayer();
  bool _adhanEnabled = true;
  bool _prePrayerAlert = true;

  // Stats
  Map<String, dynamic> _stats = {};
  String _todayKey = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this)
      ..addListener(() => setState(() => _tab = _tabCtrl.index));

    final today = DateTime.now();
    _todayKey = '${today.year}-${today.month}-${today.day}';

    _loadPrefs();
    NotificationService.init();
    _initLocation();
    _loadStats();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _audio.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────
  //  Preferences
  // ──────────────────────────────────────
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sebhaCount = prefs.getInt('sebha_count') ?? 0;
      _sebhaPhase = prefs.getInt('sebha_phase') ?? 0;
      _adhanEnabled = prefs.getBool('adhan_enabled') ?? true;
      _prePrayerAlert = prefs.getBool('pre_prayer_alert') ?? true;
    });
  }

  Future<void> _saveSebhaPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('sebha_count', _sebhaCount),
      prefs.setInt('sebha_phase', _sebhaPhase),
    ]);
  }

  Future<void> _loadStats() async {
    final s = await StatsService.loadStats();
    if (!mounted) return;
    setState(() => _stats = s);
  }

  // ──────────────────────────────────────
  //  Location & Prayer Times
  // ──────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      final svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) {
        _fallbackTimes('خدمة الموقع مغلقة، تم اعتماد توقيت عمّان الافتراضي');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _fallbackTimes('تم رفض إذن الموقع، تم اعتماد توقيت عمّان');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final pt = PrayerTimeService.calculate(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      setState(() {
        _prayerTimes = PrayerTimeService.toMap(pt);
        _locationStatus = 'تم مزامنة المواقيت بناءً على موقعك الجغرافي';
        _locationLoaded = true;
      });
      _startCountdown();
    } catch (_) {
      _fallbackTimes('تعذّر تحديد الموقع، تم اعتماد توقيت عمّان');
    }
  }

  void _fallbackTimes(String msg) {
    final pt = PrayerTimeService.calculate(
      latitude: 31.9539,
      longitude: 35.9106,
    );
    if (!mounted) return;
    setState(() {
      _prayerTimes = PrayerTimeService.toMap(pt);
      _locationStatus = msg;
      _locationLoaded = true;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _updateRemaining();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_updateRemaining);
    });
  }

  void _updateRemaining() {
    if (_prayerTimes.isEmpty) return;
    final (name, dur) = PrayerTimeService.nextPrayer(_prayerTimes);

    // تنبيه ما قبل الصلاة بـ 10 دقائق
    if (_prePrayerAlert &&
        dur.inMinutes == 10 &&
        dur.inSeconds <= 600 &&
        dur.inSeconds > 598 &&
        !_prePrayerAlertSent) {
      _prePrayerAlertSent = true;
      NotificationService.showPrePrayerNotification(name, 10);
    }
    if (dur.inMinutes > 10) _prePrayerAlertSent = false;

    // تشغيل الأذان عند دخول الوقت
    if (_remaining.inSeconds <= 1 &&
        _remaining.inSeconds > 0 &&
        _nextPrayerName == name &&
        _adhanEnabled) {
      _triggerAdhan(name);
    }

    _nextPrayerName = name;
    _remaining = dur;
  }

  Future<void> _triggerAdhan(String name) async {
    await NotificationService.showAdhanNotification(name);
    try {
      await _audio.play(AssetSource('audio/adhan.mp3'));
    } catch (_) {}
    // سجّل الصلاة في الإحصائيات
    await StatsService.markPrayerDone(_todayKey);
    await _loadStats();
  }

  // ──────────────────────────────────────
  //  Sebha
  // ──────────────────────────────────────
  Future<void> _onSebhaTap() async {
    await vibrateIfAvailable(duration: 30, amplitude: 80);
    setState(() {
      _sebhaCount++;
      if (_sebhaCount % 33 == 0) {
        _sebhaPhase = (_sebhaPhase + 1) % 3;
      }
    });
    await _saveSebhaPrefs();
  }

  Future<void> _onSebhaReset() async {
    setState(() {
      _sebhaCount = 0;
      _sebhaPhase = 0;
    });
    await _saveSebhaPrefs();
  }

  // ──────────────────────────────────────
  //  Build
  // ──────────────────────────────────────
  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _PrayerTab(
        prayerTimes: _prayerTimes,
        nextPrayerName: _nextPrayerName,
        remaining: _remaining,
        locationStatus: _locationStatus,
        locationLoaded: _locationLoaded,
        pad: _pad,
      ),
      const _AdhkarTab(),
      _SebhaTab(
        count: _sebhaCount,
        phase: _sebhaPhase,
        phaseTexts: _sebhaTexts,
        onTap: _onSebhaTap,
        onReset: _onSebhaReset,
      ),
      const _QiblaTab(),
      _AiCompanionTab(),
      _StatsTab(stats: _stats),
    ];

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.025,
              child: CustomPaint(painter: _AmbientPatternPainter()),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(key: ValueKey(_tab), child: tabs[_tab]),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) {
          setState(() => _tab = i);
          _tabCtrl.animateTo(i);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  BOTTOM NAVIGATION BAR
// ════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.mosque_outlined, Icons.mosque, 'الرئيسية'),
    (Icons.menu_book_outlined, Icons.menu_book, 'الأذكار'),
    (Icons.blur_circular_outlined, Icons.blur_circular, 'التسبيح'),
    (Icons.explore_outlined, Icons.explore, 'القبلة'),
    (Icons.smart_toy_outlined, Icons.smart_toy, 'الرفيق'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'الإنجازات'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.oud,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(
              _items.length,
              (i) => _NavItem(
                index: i,
                icon: _items[i].$1,
                activeIcon: _items[i].$2,
                label: _items[i].$3,
                isActive: currentIndex == i,
                onTap: () => onTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.brass.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? AppColors.brass : Colors.white54,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppColors.brass : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  TAB 1 — PRAYER TIMES
// ════════════════════════════════════════════════
class _PrayerTab extends StatelessWidget {
  final Map<String, DateTime> prayerTimes;
  final String nextPrayerName;
  final Duration remaining;
  final String locationStatus;
  final bool locationLoaded;
  final String Function(int) pad;

  const _PrayerTab({
    required this.prayerTimes,
    required this.nextPrayerName,
    required this.remaining,
    required this.locationStatus,
    required this.locationLoaded,
    required this.pad,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = pad(dt.minute);
    final period = dt.hour < 12 ? 'ص' : 'م';
    return '${pad(h)}:$m $period';
  }

  String get _todayLabel {
    const days = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    return days[DateTime.now().weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildHijriChip()),
          SliverToBoxAdapter(child: _buildCountdownCard()),
          SliverToBoxAdapter(child: _buildSectionTitle()),
          if (!locationLoaded)
            const SliverToBoxAdapter(child: _LoadingPrayerCards())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final entry = prayerTimes.entries.elementAt(i);
                final isNext = entry.key == nextPrayerName;
                return _PrayerCard(
                  name: entry.key,
                  time: _formatTime(entry.value),
                  isNext: isNext,
                  index: i,
                );
              }, childCount: prayerTimes.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
          SliverToBoxAdapter(child: _buildFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // شريحة التاريخ الهجري
  Widget _buildHijriChip() {
    final hijriDate = HijriService.getTodayHijri();
    if (hijriDate.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.brass.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: AppColors.brass, size: 16),
            const SizedBox(width: 8),
            Text(
              hijriDate,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.oud,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: AppColors.brass),
          const SizedBox(width: 10),
          const Text('مواقيت الصلاة', style: AppTextStyles.headingAr),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brass, width: 2),
              color: AppColors.cream,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.mosque, color: AppColors.oud, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('غُرَبَاء', style: AppTextStyles.headingAr),
                const SizedBox(height: 2),
                Text(
                  locationStatus,
                  style: AppTextStyles.captionAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.oud,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _todayLabel,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 11,
                color: AppColors.sand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    final h = pad(remaining.inHours);
    final m = pad(remaining.inMinutes % 60);
    final s = pad(remaining.inSeconds % 60);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.oud, Color(0xFF2A1A0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.oud.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: CustomPaint(
              size: const Size(100, 100),
              painter: OrnamentalRingPainter(
                color: AppColors.brass.withValues(alpha: 0.15),
                rings: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'المتبقي لأذان $nextPrayerName',
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 18,
                    color: AppColors.sand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TimeUnit(value: h, label: 'ساعة'),
                    const _ColonDivider(),
                    _TimeUnit(value: m, label: 'دقيقة'),
                    const _ColonDivider(),
                    _TimeUnit(value: s, label: 'ثانية'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        '﷽',
        style: TextStyle(
          fontFamily: 'Amiri',
          fontSize: 24,
          color: AppColors.cedar.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final String value, label;
  const _TimeUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brass.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.captionAr.copyWith(color: AppColors.brass),
        ),
      ],
    );
  }
}

class _ColonDivider extends StatelessWidget {
  const _ColonDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20, left: 6, right: 6),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.brass,
        ),
      ),
    );
  }
}

class _LoadingPrayerCards extends StatelessWidget {
  const _LoadingPrayerCards();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        5,
        (_) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.mist,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  final String name, time;
  final bool isNext;
  final int index;

  const _PrayerCard({
    required this.name,
    required this.time,
    required this.isNext,
    required this.index,
  });

  static const Map<String, IconData> _icons = {
    'الفجر': Icons.wb_twilight,
    'الظهر': Icons.wb_sunny,
    'العصر': Icons.sunny_snowing,
    'المغرب': Icons.nights_stay,
    'العشاء': Icons.dark_mode,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isNext ? AppColors.oud : AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNext ? AppColors.brass : AppColors.mist,
          width: isNext ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isNext
                ? AppColors.oud.withValues(alpha: 0.25)
                : AppColors.ink.withValues(alpha: 0.04),
            blurRadius: isNext ? 16 : 6,
            offset: Offset(0, isNext ? 6 : 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isNext
                  ? AppColors.brass.withValues(alpha: 0.2)
                  : AppColors.sand.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icons[name] ?? Icons.access_time,
              size: 20,
              color: isNext ? AppColors.brass : AppColors.cedar,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isNext ? AppColors.sand : AppColors.oud,
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brass.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'التالية',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 11,
                  color: AppColors.brass,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            time,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isNext ? Colors.white : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  TAB 2 — ADHKAR CATEGORIES
// ════════════════════════════════════════════════
class _AdhkarTab extends StatelessWidget {
  const _AdhkarTab();

  static const _cats = [
    ('أذكار الصباح', Icons.wb_sunny_rounded, 'ورد الصباح وحصنه'),
    ('أذكار المساء', Icons.nightlight_round, 'ورد المساء وحفظه'),
    ('أذكار النوم', Icons.bedtime_rounded, 'أذكار ما قبل النوم'),
    ('أذكار بعد الصلاة', Icons.auto_awesome_rounded, 'التسبيح والتحميد'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 3, height: 28, color: AppColors.brass),
                      const SizedBox(width: 12),
                      const Text(
                        'حِصْنُ الْمُسْلِم',
                        style: AppTextStyles.displayAr,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: Text(
                      'اختر ورد الأذكار',
                      style: AppTextStyles.labelAr.copyWith(
                        color: AppColors.cedar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _cats.length,
                  itemBuilder: (ctx, i) {
                    final (name, icon, sub) = _cats[i];
                    return _AdhkarCategoryCard(
                      name: name,
                      subtitle: sub,
                      icon: icon,
                      onTap: () => Navigator.push(
                        ctx,
                        _slideRoute(AdhkarDetailScreen(categoryName: name)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Route<void> _slideRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (context, error, stack) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      );
}

// ──────────────────────────────────────────────
//  Adhkar category card
// ──────────────────────────────────────────────
class _AdhkarCategoryCard extends StatefulWidget {
  final String name, subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdhkarCategoryCard({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AdhkarCategoryCard> createState() => _AdhkarCategoryCardState();
}

class _AdhkarCategoryCardState extends State<_AdhkarCategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  static const _cardGradient = LinearGradient(
    colors: [AppColors.oud, AppColors.cedar],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          decoration: BoxDecoration(
            gradient: _cardGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.brass.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.oud.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -12,
                child: Opacity(
                  opacity: 0.07,
                  child: Icon(widget.icon, size: 90, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brass.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.icon,
                        color: AppColors.brass,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 12,
                        color: AppColors.sand.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  TAB 3 — SEBHA
// ════════════════════════════════════════════════
class _SebhaTab extends StatelessWidget {
  final int count, phase;
  final List<String> phaseTexts;
  final VoidCallback onTap, onReset;

  const _SebhaTab({
    required this.count,
    required this.phase,
    required this.phaseTexts,
    required this.onTap,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (count % 33) / 33.0;
    final cyclesDone = count ~/ 33;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const Text('السُّبْحَة', style: AppTextStyles.displayAr),
          const SizedBox(height: 6),
          Text(
            phaseTexts[phase],
            style: AppTextStyles.headingAr.copyWith(color: AppColors.brass),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(220, 220),
                    painter: _SebhaRingPainter(progress: progress),
                  ),
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brass.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.oud.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: AppColors.oud,
                          ),
                        ),
                        const Text(
                          '/ 33',
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 14,
                            color: AppColors.cedar,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (cyclesDone > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.brass,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text('اكتملت $cyclesDone دورة', style: AppTextStyles.labelAr),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'اضغط للتسبيح',
            style: AppTextStyles.captionAr.copyWith(color: AppColors.cedar),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.cedar,
                size: 18,
              ),
              label: const Text(
                'تصفير العداد',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 15,
                  color: AppColors.cedar,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                side: BorderSide(color: AppColors.cedar.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SebhaRingPainter extends CustomPainter {
  final double progress;
  const _SebhaRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.mist
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -pi / 2,
      progress * 2 * pi,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [AppColors.brass, AppColors.cedar],
          startAngle: 0,
          endAngle: pi * 2,
        ).createShader(rect)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final angle = -pi / 2 + progress * 2 * pi;
    canvas.drawCircle(
      Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
      7,
      Paint()
        ..color = AppColors.brass
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SebhaRingPainter old) =>
      old.progress != progress;
}

// ════════════════════════════════════════════════
//  TAB 4 — QIBLA (AR-READY)
// ════════════════════════════════════════════════
class _QiblaTab extends StatelessWidget {
  const _QiblaTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // بوصلة تفاعلية
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cream,
                  border: Border.all(color: AppColors.brass, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.oud.withValues(alpha: 0.2),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // حلقات زخرفية
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: OrnamentalRingPainter(
                        color: AppColors.brass.withValues(alpha: 0.15),
                        rings: 2,
                      ),
                    ),
                    // إبرة البوصلة (باتجاه الجنوب الغربي ~ 202° لعمّان)
                    Transform.rotate(
                      angle: 202 * pi / 180,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 55,
                            decoration: BoxDecoration(
                              color: AppColors.oud,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.brass,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 6,
                            height: 45,
                            decoration: BoxDecoration(
                              color: AppColors.brass.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // نقطة المركز
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.brass,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('اتجاه القِبلة', style: AppTextStyles.displayAr),
              const SizedBox(height: 10),
              // معلومات المسافة
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brass.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.brass.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: AppColors.brass, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'المسافة إلى مكة: ١٢٢٨ كم',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.oud,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.mist),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.explore, color: AppColors.brass, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'للأردن: اتجاه القبلة نحو الجنوب الغربي (٢٠٢° جنوباً).',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 15,
                              color: AppColors.ink,
                              height: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.cedar,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تجربة الواقع المعزز (AR) قادمة في الإصدار القادم — ستتيح لك توجيه كاميرا هاتفك لرؤية خط مضيء باتجاه القبلة.',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 13,
                              color: AppColors.cedar,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  TAB 5 — AI COMPANION
// ════════════════════════════════════════════════
class _AiCompanionTab extends StatefulWidget {
  @override
  State<_AiCompanionTab> createState() => _AiCompanionTabState();
}

class _AiCompanionTabState extends State<_AiCompanionTab> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMsg> _msgs = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // رسالة ترحيب
    _msgs.add(
      const _ChatMsg(
        isAi: true,
        text: 'السلام عليكم ورحمة الله وبركاته 🌙\n\n'
            'أنا رفيقك الروحي في غُرَبَاء.\n\n'
            'أخبرني كيف حالك أو ما الذي تشعر به، وسأقترح لك الذكر أو الدعاء الذي يناسب حالك.\n\n'
            'يمكنك قول مثلاً:\n• "أشعر بضيق"\n• "أنا خائف من شيء"\n• "أريد أذكار الصباح"',
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _msgs.add(_ChatMsg(isAi: false, text: text));
      _isTyping = true;
    });
    _ctrl.clear();
    _scrollDown();

    // محاكاة وقت المعالجة
    await Future.delayed(const Duration(milliseconds: 800));

    final response = AiCompanionService.getResponse(text);

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _msgs.add(
        _ChatMsg(
          isAi: true,
          text: response['reply'] as String,
          suggestion: response['suggestion'] as String,
          count: response['count'] as int,
          icon: response['icon'] as String,
          category: response['category'] as String,
        ),
      );
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            // هيدر
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.oud,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.brass.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      color: AppColors.brass,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرفيق الروحي',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'مستعد للمساعدة دائماً',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 12,
                          color: AppColors.sand,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // المحادثة
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _msgs.length + (_isTyping ? 1 : 0),
                itemBuilder: (_, i) {
                  if (_isTyping && i == _msgs.length) {
                    return const _TypingIndicator();
                  }
                  return _ChatBubble(msg: _msgs[i]);
                },
              ),
            ),

            // مربع الإدخال
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                border: Border(top: BorderSide(color: AppColors.mist)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'أخبرني كيف حالك…',
                        hintStyle: const TextStyle(
                          fontFamily: 'Amiri',
                          color: AppColors.cedar,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.parchment,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.oud,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: AppColors.brass,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// رسالة في المحادثة
class _ChatMsg {
  final bool isAi;
  final String text;
  final String suggestion;
  final int count;
  final String icon;
  final String category;

  const _ChatMsg({
    required this.isAi,
    required this.text,
    this.suggestion = '',
    this.count = 0,
    this.icon = '',
    this.category = '',
  });
}

// فقاعة الرسالة
class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            msg.isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: msg.isAi ? AppColors.cream : AppColors.oud,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(msg.isAi ? 4 : 18),
                bottomRight: Radius.circular(msg.isAi ? 18 : 4),
              ),
              border: msg.isAi ? Border.all(color: AppColors.mist) : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              msg.text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 16,
                height: 1.8,
                color: msg.isAi ? AppColors.ink : AppColors.sand,
              ),
            ),
          ),

          // بطاقة الاقتراح الروحي
          if (msg.isAi && msg.suggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brass.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.brass.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(msg.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        msg.category,
                        style: AppTextStyles.labelAr.copyWith(
                          color: AppColors.brass,
                        ),
                      ),
                      const Spacer(),
                      if (msg.count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.oud,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '× ${msg.count}',
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: AppColors.brass,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg.suggestion,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 17,
                      color: AppColors.oud,
                      height: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// مؤشر الكتابة
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final offset = sin((_ctrl.value * 2 * pi) + (i * pi / 3));
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                transform: Matrix4.translationValues(0, -offset * 4, 0),
                decoration: BoxDecoration(
                  color: AppColors.brass.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  TAB 6 — STATS & GAMIFICATION
// ════════════════════════════════════════════════
class _StatsTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brass),
      );
    }

    final weekData = (stats['weekData'] as List<double>);
    final streak = stats['streak'] as int;
    final totalPrayers = stats['totalPrayers'] as int;
    final totalDhikr = stats['totalDhikrDays'] as int;
    final todayPrayers = stats['todayPrayers'] as int;
    final badges = StatsService.getBadges(stats);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(width: 3, height: 28, color: AppColors.brass),
                  const SizedBox(width: 12),
                  const Text('إنجازاتي', style: AppTextStyles.displayAr),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'رحلة الالتزام والمواظبة',
                style: AppTextStyles.labelAr.copyWith(color: AppColors.cedar),
              ),
              const SizedBox(height: 24),

              // بطاقات الإحصاء السريع
              Row(
                children: [
                  _StatCard(
                    icon: Icons.local_fire_department,
                    value: '$streak',
                    label: 'أيام متتالية',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.mosque,
                    value: '$todayPrayers/5',
                    label: 'صلوات اليوم',
                    color: AppColors.oud,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.auto_awesome,
                    value: '$totalDhikr',
                    label: 'ختم الأذكار',
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // رسم بياني للصلوات الأسبوعية
              const Text('صلوات الأسبوع', style: AppTextStyles.headingAr),
              const SizedBox(height: 14),
              Container(
                height: 180,
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.mist),
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 5,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            const days = [
                              'أح',
                              'إث',
                              'ثل',
                              'أر',
                              'خم',
                              'جم',
                              'سب',
                            ];
                            final idx = value.toInt();
                            if (idx < 0 || idx >= days.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              days[idx],
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 11,
                                color: AppColors.cedar,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, _) {
                            if (value % 1 != 0) return const SizedBox.shrink();
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 10,
                                color: AppColors.cedar,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: AppColors.mist, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(weekData.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: weekData[i],
                            color: weekData[i] >= 5
                                ? AppColors.success
                                : AppColors.brass,
                            width: 22,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // الشارات
              const Text('شاراتي', style: AppTextStyles.headingAr),
              const SizedBox(height: 14),

              if (badges.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.mist),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        color: AppColors.cedar,
                        size: 40,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'واصل المداومة على الصلاة والأذكار لتفتح أولى شاراتك!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 15,
                          color: AppColors.cedar,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (_, i) => _BadgeCard(badge: badges[i]),
                ),

              const SizedBox(height: 28),

              // إجمالي الإحصائيات
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.oud, Color(0xFF2A1A0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'إجمالي رحلتك',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sand,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TotalStat(
                          value: '$totalPrayers',
                          label: 'صلاة أُدِّيت',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.brass.withValues(alpha: 0.3),
                        ),
                        _TotalStat(value: '$totalDhikr', label: 'يوم ذِكر'),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.brass.withValues(alpha: 0.3),
                        ),
                        _TotalStat(value: '$streak', label: 'يوم تواصل'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.mist),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 11,
                color: AppColors.cedar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Map<String, String> badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brass.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(badge['icon']!, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            badge['title']!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.oud,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            badge['desc']!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 10,
              color: AppColors.cedar,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalStat extends StatelessWidget {
  final String value, label;
  const _TotalStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.brass,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontSize: 12,
            color: AppColors.sand,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
//  SETTINGS TAB — (مدمج الآن في صفحة الإنجازات — الإعدادات تُفتح كصفحة منفصلة)
//  نُبقي على كود الإعدادات قابلاً للاستدعاء من الشاشة الرئيسية
// ════════════════════════════════════════════════
class SettingsScreen extends StatelessWidget {
  final bool adhanEnabled;
  final bool prePrayerAlert;
  final ValueChanged<bool> onAdhanChanged;
  final ValueChanged<bool> onPrePrayerChanged;

  const SettingsScreen({
    super.key,
    required this.adhanEnabled,
    required this.prePrayerAlert,
    required this.onAdhanChanged,
    required this.onPrePrayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.oud,
        iconTheme: const IconThemeData(color: AppColors.sand),
        title: const Text(
          'الإعدادات',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.sand,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Developer card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.oud, Color(0xFF2A1A0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.brass.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.brass, width: 2),
                      color: AppColors.cream,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.code,
                          color: AppColors.brass,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تطوير المهندس زيد حردان',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'جميع حقوق التطوير والنشر محفوظة © ٢٠٢٦',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text('الصوت والإشعارات', style: AppTextStyles.headingAr),
            const SizedBox(height: 14),

            _SettingsTile(
              icon: Icons.volume_up_outlined,
              title: 'أذان الصلاة',
              subtitle: 'تشغيل صوت الأذان عند دخول وقت الصلاة',
              trailing: Switch.adaptive(
                value: adhanEnabled,
                activeTrackColor: AppColors.brass,
                onChanged: onAdhanChanged,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.notifications_active_outlined,
              title: 'تنبيه ما قبل الصلاة',
              subtitle: 'إرسال تذكير ١٠ دقائق قبل دخول وقت الصلاة',
              trailing: Switch.adaptive(
                value: prePrayerAlert,
                // بدلاً من activeColor استخدم activeTrackColor أو activeThumbColor
                activeTrackColor: AppColors.brass,
                onChanged: onPrePrayerChanged,
              ),
            ),
            const SizedBox(height: 10),
            const _SettingsTile(
              icon: Icons.near_me_outlined,
              title: 'مزامنة الموقع',
              subtitle: 'تحديث مواقيت الصلاة تلقائياً عبر GPS',
              trailing: Icon(Icons.check_circle, color: AppColors.success),
            ),
            const SizedBox(height: 28),

            const Text('عن التطبيق', style: AppTextStyles.headingAr),
            const SizedBox(height: 14),

            const _SettingsTile(
              icon: Icons.info_outline,
              title: 'الإصدار',
              subtitle: 'غُرَبَاء v2.1.0',
              trailing: null,
            ),
            const SizedBox(height: 10),
            const _SettingsTile(
              icon: Icons.calculate_outlined,
              title: 'طريقة حساب المواقيت',
              subtitle: 'رابطة العالم الإسلامي — مذهب الشافعي',
              trailing: null,
            ),
            const SizedBox(height: 10),
            const _SettingsTile(
              icon: Icons.calendar_today,
              title: 'التقويم الهجري',
              subtitle: 'يُحتسب تلقائياً بناءً على التاريخ الميلادي',
              trailing: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mist),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.oud, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelAr.copyWith(
                    fontSize: 15,
                    color: AppColors.oud,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.captionAr),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  ADHKAR DETAIL SCREEN
// ════════════════════════════════════════════════
class AdhkarDetailScreen extends StatefulWidget {
  final String categoryName;
  const AdhkarDetailScreen({super.key, required this.categoryName});

  @override
  State<AdhkarDetailScreen> createState() => _AdhkarDetailScreenState();
}

class _AdhkarDetailScreenState extends State<AdhkarDetailScreen> {
  late final List<Map<String, dynamic>> _list;
  late final PageController _pageCtrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _list = AdhkarData.get(widget.categoryName);
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final item = _list[_page];
    if ((item['current'] as int) >= (item['target'] as int)) return;

    setState(() => item['current'] = (item['current'] as int) + 1);

    if (item['current'] == item['target']) {
      await vibrateIfAvailable(duration: 60, amplitude: 128);

      // إذا اكتمل آخر ذكر → سجّل ختم الأذكار
      if (_page == _list.length - 1) {
        await StatsService.markDhikrCompleted();
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted && _page < _list.length - 1) {
        await _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _list[_page];
    final isDone = (item['current'] as int) >= (item['target'] as int);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.oud,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.sand),
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.sand,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Text(
                '${_page + 1} / ${_list.length}',
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 14,
                  color: AppColors.brass,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_page + 1) / _list.length,
            backgroundColor: AppColors.mist,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brass),
            minHeight: 3,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _list.length,
              itemBuilder: (_, i) {
                final it = _list[i];
                final done = (it['current'] as int) >= (it['target'] as int);
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: i == _page ? _handleTap : null,
                    child: _AdhkarCard(item: it, isDone: done),
                  ),
                );
              },
            ),
          ),
          _AdhkarBottomControls(
            item: item,
            isDone: isDone,
            onTap: _handleTap,
            onPrev: _page > 0
                ? () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    )
                : null,
            onNext: _page < _list.length - 1
                ? () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

class _AdhkarCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDone;
  const _AdhkarCard({required this.item, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDone ? AppColors.successBg : AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone ? AppColors.success : AppColors.mist,
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(40, 8),
              painter: _OrnamentDividerPainter(),
            ),
            const SizedBox(height: 20),
            Text(
              item['text'] as String,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: item['isQuran'] == true
                  ? AppTextStyles.quranAr
                  : AppTextStyles.bodyAr.copyWith(
                      fontSize: 20,
                      color: isDone ? AppColors.success : AppColors.ink,
                    ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.mist),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isDone
                  ? const [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'تم بحمد الله',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ]
                  : [
                      Text(
                        'اضغط للعدّ',
                        style: AppTextStyles.captionAr.copyWith(
                          color: AppColors.cedar,
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrnamentDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brass
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width * 0.3, 0), paint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width, 0), paint);
    final path = Path()
      ..moveTo(size.width * 0.4, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width * 0.6, 0)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _AdhkarBottomControls extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback? onPrev, onNext;

  const _AdhkarBottomControls({
    required this.item,
    required this.isDone,
    required this.onTap,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final current = item['current'] as int;
    final target = item['target'] as int;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.mist)),
      ),
      child: Column(
        children: [
          _CounterChip(current: current, target: target),
          const SizedBox(height: 14),
          Row(
            children: [
              _NavButton(icon: Icons.arrow_forward_ios, onTap: onPrev),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: isDone
                          ? const LinearGradient(
                              colors: [AppColors.success, Color(0xFF3A6347)],
                            )
                          : const LinearGradient(
                              colors: [AppColors.oud, AppColors.cedar],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isDone ? AppColors.success : AppColors.oud)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isDone ? 'تم ✓' : 'عدّ — $current / $target',
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _NavButton(icon: Icons.arrow_back_ios, onTap: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  final int current, target;
  const _CounterChip({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final pct = (current / target).clamp(0.0, 1.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.mist,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brass),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$current / $target',
          style: AppTextStyles.labelAr.copyWith(
            color: current >= target ? AppColors.success : AppColors.cedar,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 52,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.sand : AppColors.mist,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onTap != null
                ? AppColors.brass.withValues(alpha: 0.4)
                : AppColors.mist,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null
              ? AppColors.oud
              : AppColors.cedar.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  ADHKAR DATA
// ════════════════════════════════════════════════
class AdhkarData {
  AdhkarData._();

  static List<Map<String, dynamic>> get(String category) {
    switch (category) {
      case 'أذكار الصباح':
        return _morning();
      case 'أذكار المساء':
        return _evening();
      case 'أذكار النوم':
        return _sleep();
      case 'أذكار بعد الصلاة':
        return _afterPrayer();
      default:
        return [];
    }
  }

  static Map<String, dynamic> _z(
    String text,
    int target, {
    bool isQuran = false,
  }) =>
      {'text': text, 'target': target, 'current': 0, 'isQuran': isQuran};

  // ── Morning ──────────────────────────────────
  static List<Map<String, dynamic>> _morning() => [
        _z(
          'آية الكرسي:\n﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ﴾',
          1,
          isQuran: true,
        ),
        _z(
          '﴿قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ﴾',
          3,
          isQuran: true,
        ),
        _z(
          '﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ﴾',
          3,
          isQuran: true,
        ),
        _z(
          '﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ﴾',
          3,
          isQuran: true,
        ),
        _z(
          'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي، فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
          1,
        ),
        _z(
          'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ.',
          1,
        ),
        _z(
          'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ.',
          1,
        ),
        _z(
          'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
          3,
        ),
        _z(
          'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا.',
          3,
        ),
        _z('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', 10),
        _z('أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.',
            3),
        _z(
          'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي.',
          1,
        ),
        _z('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', 100),
        _z(
          'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.',
          3,
        ),
        _z(
          'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
          7,
        ),
      ];

  // ── Evening ──────────────────────────────────
  static List<Map<String, dynamic>> _evening() => [
        _z(
          'آية الكرسي:\n﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ﴾',
          1,
          isQuran: true,
        ),
        _z(
          '﴿قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ﴾',
          3,
          isQuran: true,
        ),
        _z(
          '﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ﴾',
          3,
          isQuran: true,
        ),
        _z(
          '﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ﴾',
          3,
          isQuran: true,
        ),
        _z(
          'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي، فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
          1,
        ),
        _z(
          'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
          1,
        ),
        _z(
          'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ.',
          1,
        ),
        _z(
          'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
          3,
        ),
        _z(
          'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا.',
          3,
        ),
        _z('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', 10),
        _z('أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.',
            3),
        _z('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', 100),
        _z(
          'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.',
          3,
        ),
        _z(
          'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
          7,
        ),
      ];

  // ── Sleep ────────────────────────────────────
  static List<Map<String, dynamic>> _sleep() => [
        _z(
          'آية الكرسي (من قرأها عند النوم حفظه الله حتى الصباح):\n﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ﴾',
          1,
          isQuran: true,
        ),
        _z(
          'آخر آيتين من سورة البقرة:\n﴿آمَنَ الرَّسُولُ بِمَا أُنزِلَ إِلَيْهِ مِن رَّبِّهِ وَالْمُؤْمِنُونَ ۚ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ﴾',
          1,
          isQuran: true,
        ),
        _z(
          '﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾ و ﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ﴾ و ﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ﴾\n(تُقرأ ثلاثًا ثم تنفث في راحتيك وتمسح بهما جسدك)',
          3,
          isQuran: true,
        ),
        _z('بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.', 1),
        _z(
          'بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، فَإِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ.',
          1,
        ),
        _z('اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.', 3),
        _z('سُبْحَانَ اللَّهِ (تسبيح فاطمة)', 33),
        _z('الْحَمْدُ لِلَّهِ (تسبيح فاطمة)', 33),
        _z('اللَّهُ أَكْبَرُ (تسبيح فاطمة)', 34),
        _z(
          'اللَّهُمَّ رَبَّ السَّمَاوَاتِ وَرَبَّ الْأَرْضِ وَرَبَّ الْعَرْشِ الْعَظِيمِ، رَبَّنَا وَرَبَّ كُلِّ شَيْءٍ، فَالِقَ الْحَبِّ وَالنَّوَى، أَعُوذُ بِكَ مِنْ شَرِّ كُلِّ شَيْءٍ أَنْتَ آخِذٌ بِنَاصِيَتِهِ.',
          1,
        ),
      ];

  // ── After Prayer ─────────────────────────────
  static List<Map<String, dynamic>> _afterPrayer() => [
        _z('أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ.', 3),
        _z(
          'اللَّهُمَّ أَنْتَ السَّلامُ وَمِنْكَ السَّلامُ، تَبَارَكْتَ ذَا الْجَلالِ وَالإِكْرَامِ.',
          1,
        ),
        _z(
          'لا إِلَهَ إِلا اللهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
          1,
        ),
        _z(
          'اللَّهُمَّ لا مَانِعَ لِمَا أَعْطَيْتَ، وَلا مُعْطِيَ لِمَا مَنَعْتَ، وَلا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ.',
          1,
        ),
        _z('سُبْحَانَ اللهِ', 33),
        _z('الْحَمْدُ للهِ', 33),
        _z('اللهُ أَكْبَرُ', 33),
        _z(
          'لا إِلَهَ إِلا اللهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
          1,
        ),
        _z(
          'آية الكرسي:\n﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ﴾ ... إلى آخر الآية',
          1,
          isQuran: true,
        ),
        _z('﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾', 1, isQuran: true),
        _z('﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ﴾', 1, isQuran: true),
        _z('﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ﴾', 1, isQuran: true),
        _z(
          'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ، وَشُكْرِكَ، وَحُسْنِ عِبَادَتِكَ.',
          1,
        ),
      ];
}

// ════════════════════════════════════════════════
//  SHARED PAINTERS
// ════════════════════════════════════════════════
class OrnamentalRingPainter extends CustomPainter {
  final Color color;
  final int rings;
  const OrnamentalRingPainter({required this.color, this.rings = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width / 2;
    for (int i = 1; i <= rings; i++) {
      canvas.drawCircle(center, base * i / rings, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OrnamentalRingPainter old) =>
      old.color != color || old.rings != rings;
}

class _AmbientPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const step = 80.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        final center = Offset(x + step / 2, y + step / 2);
        canvas.drawCircle(center, step * 0.3, paint);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(pi / 4);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: step * 0.4,
            height: step * 0.4,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ════════════════════════════════════════════════
//  APP ROOT
// ════════════════════════════════════════════════
class GhurabaApp extends StatelessWidget {
  const GhurabaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'غُرَبَاء',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Amiri',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.oud,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.parchment,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

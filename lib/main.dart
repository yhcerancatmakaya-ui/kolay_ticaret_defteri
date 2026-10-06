/* 
  🛡 TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/foundation.dart'; // 👈 kIsWeb ve defaultTargetPlatform için gerekli
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'google_drive_servisi.dart';
import 'google_drive_oturum_servisi.dart';
import 'yedek_esitleme_servisi.dart';
import 'bulut_seviye.dart';
import 'pin_ekrani.dart';
import 'banner_reklam_widget.dart';
import 'fintek_paneli.dart';
import 'tema_renk_paleti.dart';
import 'grafik.dart';
import 'ayarlar_ekrani.dart';
import 'kisi_listesi_ekrani.dart';
import 'stok_ekrani.dart';

enum AktifGorunumModu {
  normalSekme,
  ayarlar,
}

class KullaniciProfili {
  final bool stokTakibiVarMi;
  final bool ortaklikYapisiVarMi;
  final bool taksitliSatisVarMi;
  final String isletmeAdi;

  KullaniciProfili({
    this.stokTakibiVarMi = true,
    this.ortaklikYapisiVarMi = true,
    this.taksitliSatisVarMi = true,
    this.isletmeAdi = "Kolay Ticaret Defteri",
  });
}

class BulutDurumServisi {
  static final BulutDurumServisi _instance = BulutDurumServisi._internal();
  factory BulutDurumServisi() => _instance;
  BulutDurumServisi._internal();

  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<BulutSeviye> seviyeNotifier = ValueNotifier<BulutSeviye>(BulutSeviye.yesil);
  static final ValueNotifier<bool> yereldeYeniVeriVarNotifier = ValueNotifier<bool>(false);

  // Canlı dinamik başlık ve açıklamaları saklayan değişkenler
  static String sonBaslik = "Bulut Senkronize";
  static String sonAciklama = "Google Drive yedeği güncel ve tam senkronize.";

  static void guncelle({
    required BulutSeviye seviye,
    required String baslik,
    required String aciklama,
  }) {
    seviyeNotifier.value = seviye;
    sonBaslik = baslik;
    sonAciklama = aciklama;

    if (seviye == BulutSeviye.yesil) {
      isOnlineNotifier.value = true;
      yereldeYeniVeriVarNotifier.value = false;
    } else {
      isOnlineNotifier.value = false;
    }
  }
}

class GlobalSessionGuard extends StatefulWidget {
  final Widget child;
  const GlobalSessionGuard({super.key, required this.child});

  static bool isSessionActive = true;

  @override
  State<GlobalSessionGuard> createState() => _GlobalSessionGuardState();
}

class _GlobalSessionGuardState extends State<GlobalSessionGuard> with WidgetsBindingObserver {
  Timer? _heartbeatTimer;
  Timer? _periyodikYedekTimer;
  final Duration _sorguAraligi = const Duration(seconds: 90);
  final Duration _yedekAraligi = const Duration(minutes: 15);

  final GoogleDriveServisi _driveServisi = GoogleDriveServisi();
  late final GoogleDriveOturumServisi _oturumServisi;
  final YedekEsitlemeServisi _esitlemeServisi = YedekEsitlemeServisi();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isSyncOrCheckRunning = false; // Ortak kilit bayrağı

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _oturumServisi = GoogleDriveOturumServisi(driveServisi: _driveServisi);

    YedekEsitlemeServisi.syncStatusNotifier.addListener(_syncStatusDinle);
  
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessizSorguCalistir();
    });

    _kalpAtisiniBaslat();
    _periyodikYedeklemeyiBaslat();
  }

  void _syncStatusDinle() {
    final status = YedekEsitlemeServisi.syncStatusNotifier.value;
    if (status == "baska_cihaz_aktif" && GlobalSessionGuard.isSessionActive) {
      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.kirmizi,
        baslik: "Aktif Oturum Çakışması",
        aciklama: "Bu defter başka bir cihazda aktif edildi.",
      );
      _oturumuAnindaSonlandirVeFirlat();
    }
  }

  void _periyodikYedeklemeyiBaslat() {
    _periyodikYedekTimer?.cancel();
    _periyodikYedekTimer = Timer.periodic(_yedekAraligi, (timer) async {
      if (GlobalSessionGuard.isSessionActive && !_isSyncOrCheckRunning) {
        final String? driveAktifMi = await _storage.read(key: 'drive_aktif_mi');
        if (driveAktifMi != 'evet') return; // Drive pasifse periyodik yedeklemeyi durdur

        _isSyncOrCheckRunning = true;
        try {
          await _esitlemeServisi.otomatikSenkronizasyonuBaslat();
        } finally {
          _isSyncOrCheckRunning = false;
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && GlobalSessionGuard.isSessionActive) {
      _sessizSorguCalistir();
    }
  }

  void _kalpAtisiniBaslat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_sorguAraligi, (timer) {
      _sessizSorguCalistir();
    });
  }

  /// 🛡️ 5 ADIMLI KORUMA KALKANI İLE SESSIZ SORGU
  Future<void> _sessizSorguCalistir() async {
    if (!GlobalSessionGuard.isSessionActive || _isSyncOrCheckRunning) return;

    // ADIM 1: Ana Ekran Kontrolü - drive_aktif_mi kontrolü
    final String? driveAktifMi = await _storage.read(key: 'drive_aktif_mi');
    if (driveAktifMi != 'evet') {
      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.gri,
        baslik: "Google Drive Pasif",
        aciklama: "Google Drive senkronizasyonu kapalı.",
      );
      return; // DUR
    }

    // ADIM 2: Soğuma Süresi Kontrolü
    if (!await _driveServisi.sogumaSuresiDolduMu()) {
      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.sari,
        baslik: "Bekleme Modu",
        aciklama: "Son bağlantı hatası nedeniyle Drive sorgusu ertelendi.",
      );
      return; // DUR
    }

    // ADIM 3: Gerçek İnternet Kontrolü (Google sunucularına ping)
    final bool internetVar = await _driveServisi.internetVarMi();
    if (!internetVar) {
      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.sari,
        baslik: "İnternet Bağlantısı Yok",
        aciklama: "Defteriniz çevrimdışı modda çalışıyor.",
      );
      return; // DUR
    }

    _isSyncOrCheckRunning = true;

    try {
      // ADIM 4 & 5: Güvenli Çağrı (Timeout & lightweight authentication)
      final kilitDurumu = await _oturumServisi.kilitDurumunuSorgula(forceInteractive: false);
      if (kilitDurumu == OturumKilitDurumu.baskaCihazAktif) {
        BulutDurumServisi.guncelle(
          seviye: BulutSeviye.kirmizi,
          baslik: "Aktif Oturum Çakışması",
          aciklama: "Bu defter başka bir cihazda aktif edildi.",
        );
        _oturumuAnindaSonlandirVeFirlat();
        return;
      } else if (kilitDurumu == OturumKilitDurumu.hata) {
        BulutDurumServisi.guncelle(
          seviye: BulutSeviye.sari,
          baslik: "Drive Bağlantı Uyarısı",
          aciklama: "Google sunucularına erişilemedi.",
        );
        return;
      }

      final ReconciliationResult sonuc = await _esitlemeServisi.yoklamaVeEsitlemeKarariAl();
      switch (sonuc) {
        case ReconciliationResult.guncel:
          BulutDurumServisi.guncelle(
            seviye: BulutSeviye.yesil,
            baslik: "Bulut Eşitlendi",
            aciklama: "Google Drive yedeği güncel ve tam senkronize.",
          );
          break;
        case ReconciliationResult.yerelYeniSessizceYedekle:
          BulutDurumServisi.guncelle(
            seviye: BulutSeviye.sari,
            baslik: "Aktarılmamış Kayıtlar Var",
            aciklama: "Yerel verileriniz henüz buluta yedeklenmedi.",
          );
          break;
        case ReconciliationResult.bulutYeniOnayIste:
          BulutDurumServisi.guncelle(
            seviye: BulutSeviye.sari,
            baslik: "Bulutta Güncel Yedek Var",
            aciklama: "Buluttaki veriler cihazınızdakinden daha yeni.",
          );
          break;
        case ReconciliationResult.hata:
          BulutDurumServisi.guncelle(
            seviye: BulutSeviye.sari,
            baslik: "Eşitleme Uyarısı",
            aciklama: "Bulut veri durumu doğrulanamadı.",
          );
          break;
      }
    } catch (e) {
      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.sari,
        baslik: "Bağlantı Bekleniyor",
        aciklama: "Google Drive erişimi kontrol ediliyor.",
      );
    } finally {
      _isSyncOrCheckRunning = false;
    }
  }

  void _oturumuAnindaSonlandirVeFirlat() {
    GlobalSessionGuard.isSessionActive = false;
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/pin', (route) => false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    YedekEsitlemeServisi.syncStatusNotifier.removeListener(_syncStatusDinle);
    _heartbeatTimer?.cancel();
    _periyodikYedekTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox('defterKutusu');
  await Hive.openBox('stokKutusu');
  await Hive.openBox('stokGruplariKutusu');
  await Hive.openBox('kisiKutusu');
  await Hive.openBox('ayarlarKutusu');

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint("Mobil Reklam Başlatma Hatası: $e");
    }
  }

  runApp(const KolayTicaretApp());
}

class KolayTicaretApp extends StatelessWidget {
  const KolayTicaretApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kolay Ticaret Defteri',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('tr', 'TR'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.cardBackground,
          foregroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      initialRoute: '/pin',
      routes: {
        '/': (context) => GlobalSessionGuard(
              child: AnaEkran(
                profil: KullaniciProfili(
                  stokTakibiVarMi: true,
                  ortaklikYapisiVarMi: true,
                  taksitliSatisVarMi: true,
                ),
              ),
            ),
        '/pin': (context) => const PinEkrani(),
      },
    );
  }
}

class AnaEkran extends StatefulWidget {
  final KullaniciProfili profil;
  const AnaEkran({super.key, required this.profil});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _seciliSekme = 0;
  BulutSeviye _mevcutSeviye = BulutSeviye.yesil;
  AktifGorunumModu _aktifGorunumModu = AktifGorunumModu.normalSekme;
  final String _appVersion = "1.0.0";

  late List<Widget> _sayfalar;
  late List<BottomNavigationBarItem> _navigasyonOgeleri;

  @override
  void initState() {
    super.initState();
    _ekranYapisiniOlustur();

    _mevcutSeviye = BulutDurumServisi.seviyeNotifier.value;
    BulutDurumServisi.seviyeNotifier.addListener(_durumGuncelle);
  }

  void _durumGuncelle() {
    if (mounted) {
      setState(() {
        _mevcutSeviye = BulutDurumServisi.seviyeNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    BulutDurumServisi.seviyeNotifier.removeListener(_durumGuncelle);
    super.dispose();
  }

  Color _getDurumRengi(BulutSeviye seviye) {
    switch (seviye) {
      case BulutSeviye.yesil:
        return AppColors.success;
      case BulutSeviye.sari:
        return Colors.amber;
      case BulutSeviye.kirmizi:
        return AppColors.error;
      case BulutSeviye.gri:
        return AppColors.inactive;
    }
  }

  /// 💡 Lambaya dokunulduğunda 2.5 saniyeliğine görünen yarı saydam durum bildirimi
  void _bulutDurumBildirimiGoster(BuildContext context) {
    final Color durumRengi = _getDurumRengi(_mevcutSeviye);
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        elevation: 0,
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.90), // Yarı saydam arka plan
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: durumRengi.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: durumRengi.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.add_to_drive_rounded,
                  color: durumRengi,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      BulutDurumServisi.sonBaslik,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      BulutDurumServisi.sonAciklama,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.2,
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

  void _ekranYapisiniOlustur() {
    _sayfalar = [];
    _navigasyonOgeleri = [];

    _sayfalar.add(const FintekGecisPaneli());
    _navigasyonOgeleri.add(const BottomNavigationBarItem(
      icon: Icon(Icons.home_rounded, size: 22),
      label: 'Ana Sayfa',
    ));

    _sayfalar.add(const KisiListesiEkrani());
    _navigasyonOgeleri.add(const BottomNavigationBarItem(
      icon: Icon(Icons.people_alt_rounded, size: 22),
      label: 'Kişiler',
    ));

    if (widget.profil.stokTakibiVarMi) {
      _sayfalar.add(const StokEkrani());
      _navigasyonOgeleri.add(const BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_rounded, size: 22),
        label: 'Stok / Al - Sat',
      ));
    }

    _sayfalar.add(const IstatistikVeRaporEkrani());
    _navigasyonOgeleri.add(const BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_rounded, size: 22),
      label: 'Grafikler',
    ));
  }

  Widget _ortaGovdeIceriginiGetir() {
    switch (_aktifGorunumModu) {
      case AktifGorunumModu.ayarlar:
        return Stack(
          children: [
            const AyarlarEkrani(),
            _kapatButonu(),
          ],
        );
      case AktifGorunumModu.normalSekme:
        return IndexedStack(
          index: _seciliSekme,
          children: _sayfalar,
        );
    }
  }

  Widget _kapatButonu() {
    return Positioned(
      top: 10,
      right: 12,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close_rounded, color: AppColors.primary, size: 18),
          onPressed: () {
            setState(() {
              _aktifGorunumModu = AktifGorunumModu.normalSekme;
            });
          },
        ),
      ),
    );
  }

  void _bulutYedeklemeOnayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text("Bulut Yedekleme", style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Text(
          "Yerel cihazınızda henüz buluta aktarılmamış kayıtlar var. Verileriniz Google Drive hesabınıza yedeklensin mi?",
          style: TextStyle(fontSize: 12.5, color: AppColors.primary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Vazgeç", style: TextStyle(color: AppColors.inactive, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final esitlemeServisi = YedekEsitlemeServisi();
              await esitlemeServisi.yerelVeriyiGarantiliYedekle();
              BulutDurumServisi.yereldeYeniVeriVarNotifier.value = false;
              BulutDurumServisi.seviyeNotifier.value = BulutSeviye.yesil;
            },
            child: const Text("Şimdi Yedekle", style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _hakkindaDialogGoster(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              "Kolay Ticaret Defteri",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "KoTiDef",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "v$_appVersion",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Ticari işlemlerin, borç-alacak takibinin ve stok yönetiminin kolay ve pratik bir şekilde yürütülmesi amacıyla tasarlanmıştır.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.inactive, height: 1.3),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),
            Text(
              "© 2026 Hasan CERAN\nTüm hakları saklıdır.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.primary.withValues(alpha: 0.6)),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Kapat",
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color aktifRenk = _getDurumRengi(_mevcutSeviye);
    final double mediaQueryWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Container(
        margin: const EdgeInsets.only(top: kToolbarHeight + 8, bottom: 56),
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
          child: SizedBox(
            width: mediaQueryWidth * 0.72,
            child: Drawer(
              backgroundColor: AppColors.cardBackground,
              elevation: 4,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.profil.isletmeAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "KoTiDef",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withValues(alpha: 0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Ticari işlemlerin yönetimi ve takibi",
                          style: TextStyle(fontSize: 11, color: AppColors.inactive),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.home_rounded, color: AppColors.primary, size: 20),
                          title: const Text("Ana Sayfa", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _seciliSekme = 0;
                              _aktifGorunumModu = AktifGorunumModu.normalSekme;
                            });
                          },
                        ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
                          title: const Text("Kişiler", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _seciliSekme = 1;
                              _aktifGorunumModu = AktifGorunumModu.normalSekme;
                            });
                          },
                        ),
                        if (widget.profil.stokTakibiVarMi)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                            title: const Text("Stok / Al - Sat", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _seciliSekme = 2;
                                _aktifGorunumModu = AktifGorunumModu.normalSekme;
                              });
                            },
                          ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
                          title: const Text("Grafikler", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _seciliSekme = widget.profil.stokTakibiVarMi ? 3 : 2;
                              _aktifGorunumModu = AktifGorunumModu.normalSekme;
                            });
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Divider(height: 1, thickness: 0.6),
                        ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.settings_outlined, color: AppColors.primary, size: 20),
                          title: const Text("Ayarlar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _aktifGorunumModu = AktifGorunumModu.ayarlar;
                            });
                          },
                        ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                          title: const Text("İşlem Dökümü", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("İşlem Dökümü modülü hazırlanacak...")),
                            );
                          },
                        ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                          title: const Text("Hakkında", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            _hakkindaDialogGoster(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      "v$_appVersion • Kolay Ticaret Defteri",
                      style: const TextStyle(fontSize: 10, color: AppColors.inactive, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.primary, size: 22),
            tooltip: "Menü",
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "KOLAY TİCARET DEFTERİ",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.primary.withValues(alpha: 0.75),
                  size: 19,
                ),
                tooltip: "Ayarlar",
                onPressed: () {
                  setState(() {
                    _aktifGorunumModu = AktifGorunumModu.ayarlar;
                  });
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: BulutDurumServisi.isOnlineNotifier,
                builder: (context, isOnline, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: BulutDurumServisi.yereldeYeniVeriVarNotifier,
                    builder: (context, yeniVeriVar, _) {
                      final bool butonAktif = isOnline && yeniVeriVar;

                      return IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        icon: Icon(
                          Icons.cloud_upload_rounded,
                          size: 19,
                          color: butonAktif ? AppColors.primary : AppColors.inactive.withValues(alpha: 0.35),
                        ),
                        tooltip: butonAktif ? "Yedeklenmemiş verileri buluta aktar" : "Bulut güncel",
                        onPressed: butonAktif ? () => _bulutYedeklemeOnayDialog(context) : null,
                      );
                    },
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0, left: 3.0),
                child: Tooltip(
                  message: BulutDurumServisi.sonBaslik,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _bulutDurumBildirimiGoster(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: aktifRenk.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_to_drive_rounded,
                          color: aktifRenk,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: _ortaGovdeIceriginiGetir(),
          ),
          const BannerReklamWidget(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSekme,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.cardBackground,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.inactive,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, height: 1.1),
        unselectedLabelStyle: const TextStyle(fontSize: 10, height: 1.1),
        onTap: (index) {
          setState(() {
            _seciliSekme = index;
            _aktifGorunumModu = AktifGorunumModu.normalSekme;
          });
        },
        items: _navigasyonOgeleri,
      ),
    );
  }
}
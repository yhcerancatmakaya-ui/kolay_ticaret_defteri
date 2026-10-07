/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/foundation.dart'; // 👈 kIsWeb kontrolü için eklendi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'main.dart';
import 'tema_renk_paleti.dart';
import 'google_drive_servisi.dart';
import 'google_drive_oturum_servisi.dart';
import 'yedek_esitleme_servisi.dart';

enum PinEkraniDurumu {
  yukleniyor,
  ilkKurulum,
  standartGiris,
  sifreSifirlama,
}

class PinEkrani extends StatefulWidget {
  final bool askiyaAlindiMi;
  final String? hataMesaji;

  const PinEkrani({
    super.key,
    this.askiyaAlindiMi = false,
    this.hataMesaji,
  });

  @override
  State<PinEkrani> createState() => _PinEkraniState();
}

class _PinEkraniState extends State<PinEkrani> with SingleTickerProviderStateMixin {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final GoogleDriveOturumServisi _oturumServisi;
  final YedekEsitlemeServisi _esitlemeServisi = YedekEsitlemeServisi();
  
  final TextEditingController _kullaniciAdiController = TextEditingController();
  final TextEditingController _cevapController = TextEditingController();
  final TextEditingController _sifirlamaCevapController = TextEditingController();

  PinEkraniDurumu _ekranDurumu = PinEkraniDurumu.yukleniyor;
  int _kurulumAdimi = 0;
  
  String? _kayitliPin;
  String? _kayitliKullaniciAdi;
  String? _kayitliSoru;
  String? _kayitliCevap;

  final List<String> _girilenPin = [];
  final List<String> _yeniPin = [];
  final List<String> _yeniPinTekrar = [];
  
  String? _secilenSoru;
  bool _isActionLoading = false;
  bool _isError = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final List<String> _guvenlikSorulari = [
    'Doğduğunuz şehrin adı nedir?',
    'Hangi futbol takımını tutuyorsunuz?',
    'En sevdiğiniz yemek nedir?',
    'İlkokul öğretmeninizin adı nedir?',
    'İlk evcil hayvanınızın adı nedir?',
  ];

  @override
  void initState() {
    super.initState();
    _oturumServisi = GoogleDriveOturumServisi(driveServisi: GoogleDriveServisi());

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    GlobalSessionGuard.isSessionActive = false;
    _cihazTaramaVeSorgula();
    
    if (widget.askiyaAlindiMi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _askiyaAlindiBilgilendirmeKalkani();
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _kullaniciAdiController.dispose();
    _cevapController.dispose();
    _sifirlamaCevapController.dispose();
    super.dispose();
  }

  Future<void> _cihazTaramaVeSorgula() async {
    try {
      final String? pin = await _storage.read(key: 'uygulama_pin');
      final String? kullanici = await _storage.read(key: 'kullanici_adi');
      final String? soru = await _storage.read(key: 'guvenlik_sorusu');
      final String? cevap = await _storage.read(key: 'guvenlik_cevabi');

      final Box defterKutusu = Hive.box('defterKutusu');
      final bool yerelVeriVarMi = defterKutusu.isNotEmpty;

      if (!mounted) return;

      setState(() {
        _kayitliPin = pin;
        _kayitliKullaniciAdi = kullanici;
        _kayitliSoru = soru;
        _kayitliCevap = cevap;
      });

      if (_kayitliPin != null && _kayitliPin!.isNotEmpty) {
        setState(() => _ekranDurumu = PinEkraniDurumu.standartGiris);
      } else if (yerelVeriVarMi) {
        setState(() => _ekranDurumu = PinEkraniDurumu.ilkKurulum);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cihazda önceden kaydedilmiş veriler bulundu. Lütfen güvenlik bilgilerinizi yeniden tanımlayın.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        setState(() => _ekranDurumu = PinEkraniDurumu.ilkKurulum);
      }
    } catch (hata) {
      debugPrint("Cihaz Tarama Hatası: $hata");
      if (mounted) {
        setState(() => _ekranDurumu = PinEkraniDurumu.ilkKurulum);
      }
    }
  }

  void _anaEkranaGec() {
    GlobalSessionGuard.isSessionActive = true;
    Navigator.pushReplacementNamed(context, '/');
  }

  void _askiyaAlindiBilgilendirmeKalkani() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.gavel_rounded, color: AppColors.borc, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OTURUM ASKIDA', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(
            widget.hataMesaji ?? 
            "Oturum Kapatıldı: Bu defter başka bir cihazda aktif edilmiştir. "
            "Veri çakışmasını önlemek için oturumunuz askıya alınmış olabilir.",
            style: const TextStyle(fontSize: 12.5, color: AppColors.primary, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ANLADIM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  // Web uyumlu Drive Giriş Akışı
  Future<void> _driveHesapSorgulaVeKilitKontrolEt() async {
    setState(() => _isActionLoading = true);
    try {
      final OturumKilitDurumu durum = await _oturumServisi.oturumKilitDurumuKontrolEt(forceAc: true);

      if (!mounted) return;

      if (durum == OturumKilitDurumu.kilitAlindi) {
        await _storage.write(key: 'drive_aktif_mi', value: 'evet');

        final bool indirmeBasarili = await _esitlemeServisi.bulutVerisiniYereleVeDepoyaUygula();

        if (!mounted) return;

        if (indirmeBasarili) {
          final String? yuklenenPin = await _storage.read(key: 'uygulama_pin');
          final String? yuklenenKullanici = await _storage.read(key: 'kullanici_adi');
          final String? yuklenenSoru = await _storage.read(key: 'guvenlik_sorusu');
          final String? yuklenenCevap = await _storage.read(key: 'guvenlik_cevabi');

          if (yuklenenPin != null && yuklenenPin.isNotEmpty) {
            setState(() {
              _kayitliPin = yuklenenPin;
              _kayitliKullaniciAdi = yuklenenKullanici;
              _kayitliSoru = yuklenenSoru;
              _kayitliCevap = yuklenenCevap;
              _ekranDurumu = PinEkraniDurumu.standartGiris;
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bulut yedeği başarıyla yüklendi. Lütfen PIN kodunuzu girin.'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bulut yedeği indirildi ancak geçerli bir PIN kaydı bulunamadı.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seçilen hesapta herhangi bir kayıt bulunmuyor.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else if (durum == OturumKilitDurumu.baskaCihazdaAcik) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu defter başka bir cihazda aktif durumda. Lütfen diğer cihazdaki oturumu kapatın.'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Drive bağlantısı veya oturum kilit kontrolü sağlanamadı.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  void _standartPinTusaBasildi(String rakam) {
    if (!kIsWeb) HapticFeedback.lightImpact();
    if (_isError) setState(() => _isError = false);

    if (_girilenPin.length < 4) {
      setState(() => _girilenPin.add(rakam));
      if (_girilenPin.length == 4) _standartPinKontrolEt();
    }
  }

  void _standartPinSil() {
    if (_girilenPin.isNotEmpty) {
      if (!kIsWeb) HapticFeedback.selectionClick();
      setState(() {
        _girilenPin.removeLast();
        _isError = false;
      });
    }
  }

  Future<void> _standartPinKontrolEt() async {
    String birlesikPin = _girilenPin.join();
    if (birlesikPin == _kayitliPin) {
      if (!kIsWeb) HapticFeedback.mediumImpact();
      setState(() => _isActionLoading = true);

      try {
        final String? driveAktifMi = await _storage.read(key: 'drive_aktif_mi');
        if (driveAktifMi == 'evet') {
          final ReconciliationResult sonuc = await _esitlemeServisi.yoklamaVeEsitlemeKarariAl();
          if (!mounted) return;
          if (sonuc == ReconciliationResult.bulutYeniOnayIste) {
            setState(() => _isActionLoading = false);
            final bool? indirilsinMi = await _bulutGuncelUyariDialogGoster();
            if (!mounted) return;
            if (indirilsinMi == true) {
              setState(() => _isActionLoading = true);
              await _esitlemeServisi.bulutVerisiniYereleVeDepoyaUygula();
            }
          }
        }
      } catch (e) {
        debugPrint("PIN Girişi Bulut Kontrol Hatası: $e");
      } finally {
        if (mounted) {
          setState(() => _isActionLoading = false);
        }
      }

      if (!mounted) return;
      _anaEkranaGec();
    } else {
      if (!kIsWeb) HapticFeedback.vibrate();
      setState(() => _isError = true);
      _shakeController.forward(from: 0.0).then((_) {
        if (mounted) setState(() => _girilenPin.clear());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatalı PIN kodu!'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<bool?> _bulutGuncelUyariDialogGoster() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.cloud_download_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('BULUT VERİSİ DAHA GÜNCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
              ),
            ],
          ),
          content: const Text(
            'Google Drive yedeklerinizdeki veriler cihazınızdaki verilerden daha güncel görünmektedir. Nasıl devam etmek istersiniz?',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.primary),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Yerel Kayıttan Devam Et', style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 11.5)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Buluttan Güncel Veriyi İndir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
            ),
          ],
        );
      },
    );
  }

  void _kurulumPinTusaBasildi(String rakam) {
    if (!kIsWeb) HapticFeedback.lightImpact();
    if (_kurulumAdimi == 1) {
      if (_yeniPin.length < 4) {
        setState(() => _yeniPin.add(rakam));
        if (_yeniPin.length == 4) {
          setState(() => _kurulumAdimi = 2);
        }
      }
    } else if (_kurulumAdimi == 2) {
      if (_yeniPinTekrar.length < 4) {
        setState(() => _yeniPinTekrar.add(rakam));
        if (_yeniPinTekrar.length == 4) {
          _kurulumPinDogrulaVeKaydet();
        }
      }
    }
  }

  void _kurulumPinSil() {
    if (!kIsWeb) HapticFeedback.selectionClick();
    if (_kurulumAdimi == 1 && _yeniPin.isNotEmpty) {
      setState(() => _yeniPin.removeLast());
    } else if (_kurulumAdimi == 2 && _yeniPinTekrar.isNotEmpty) {
      setState(() => _yeniPinTekrar.removeLast());
    }
  }

  void _kurulumPinDogrulaVeKaydet() async {
    if (_yeniPin.join() == _yeniPinTekrar.join()) {
      final pin = _yeniPin.join();
      await _storage.write(key: 'uygulama_pin', value: pin);
      await _storage.write(key: 'kullanici_adi', value: _kullaniciAdiController.text.trim());
      await _storage.write(key: 'guvenlik_sorusu', value: _secilenSoru);
      await _storage.write(key: 'guvenlik_cevabi', value: _cevapController.text.trim().toLowerCase());

      _kayitliPin = pin;
      _kayitliKullaniciAdi = _kullaniciAdiController.text.trim();

      if (!mounted) return;
      _anaEkranaGec();
    } else {
      if (!kIsWeb) HapticFeedback.vibrate();
      setState(() {
        _yeniPin.clear();
        _yeniPinTekrar.clear();
        _kurulumAdimi = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN kodları eşleşmedi. Lütfen tekrar oluşturun.'), backgroundColor: AppColors.error),
      );
    }
  }

  void _hesabiSifirLaOnayDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_rounded, color: AppColors.borc, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('HESABI SIFIRLA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
              ),
            ],
          ),
          content: const Text(
            'Mevcut tüm yerel verileriniz temizlenecek ve uygulama ilk kurulum ekranına dönecektir. Devam etmek istediğinize emin misiniz?',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.primary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('VAZGEÇ', style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.borc, elevation: 0),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _tumVerileriTemizleVeSifirla();
              },
              child: const Text('EVET, SIFIRLA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tumVerileriTemizleVeSifirla() async {
    setState(() => _isActionLoading = true);
    try {
      await _storage.deleteAll();
      final box = Hive.box('defterKutusu');
      await box.clear();

      if (!mounted) return;

      setState(() {
        _kayitliPin = null;
        _kayitliKullaniciAdi = null;
        _kayitliSoru = null;
        _kayitliCevap = null;
        _girilenPin.clear();
        _yeniPin.clear();
        _yeniPinTekrar.clear();
        _kurulumAdimi = 0;
        _ekranDurumu = PinEkraniDurumu.ilkKurulum;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sıfırlama hatası: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  void _sifreSifirlamaDogrula() async {
    final girilenCevap = _sifirlamaCevapController.text.trim().toLowerCase();
    if (_kayitliCevap != null && girilenCevap == _kayitliCevap) {
      _sifirlamaCevapController.clear();
      setState(() {
        _yeniPin.clear();
        _yeniPinTekrar.clear();
        _kurulumAdimi = 1;
        _ekranDurumu = PinEkraniDurumu.ilkKurulum;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güvenlik sorusu doğrulandı. Yeni PIN belirleyin.'), backgroundColor: AppColors.success),
        );
      }
    } else {
      if (!kIsWeb) HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güvenlik sorusu cevabı yanlış!'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  InputDecoration _inputDekorasyon(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      labelStyle: const TextStyle(color: AppColors.inactive, fontSize: 11.5),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.inactive.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.inactive.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!kIsWeb) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _isActionLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _buildEkranIcerigi(),
        ),
      ),
    );
  }

  Widget _buildEkranIcerigi() {
    switch (_ekranDurumu) {
      case PinEkraniDurumu.yukleniyor:
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      case PinEkraniDurumu.ilkKurulum:
        return _durumAIlkKurulumArayuzu();
      case PinEkraniDurumu.standartGiris:
        return _durumBStandartGirisArayuzu();
      case PinEkraniDurumu.sifreSifirlama:
        return _durumCSifreSifirlamaArayuzu();
    }
  }

  Widget _durumAIlkKurulumArayuzu() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.import_contacts_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            const Text(
              'KOLAY TİCARET DEFTERİ',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.1),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hoş Geldiniz! Lütfen kurulum bilgilerini doldurun.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inactive),
            ),
            const SizedBox(height: 24),

            if (_kurulumAdimi == 0) ...[
              TextField(
                controller: _kullaniciAdiController,
                style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                decoration: _inputDekorasyon("Kullanıcı / İşletme Adı", Icons.store_outlined),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _secilenSoru,
                style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                decoration: _inputDekorasyon("Güvenlik Sorusu", Icons.help_outline_rounded),
                hint: const Text("Soru seçiniz", style: TextStyle(fontSize: 12, color: AppColors.inactive)),
                items: _guvenlikSorulari.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _secilenSoru = val),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _cevapController,
                style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                decoration: _inputDekorasyon("Güvenlik Sorusu Cevabı", Icons.question_answer_outlined),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_kullaniciAdiController.text.trim().isNotEmpty &&
                      _secilenSoru != null &&
                      _cevapController.text.trim().isNotEmpty) {
                    setState(() => _kurulumAdimi = 1);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen tüm alanları doldurun.'), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text("DEVAM ET (PIN OLUŞTUR)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.backgroundDarker,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 46),
                  side: BorderSide(color: AppColors.inactive.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _driveHesapSorgulaVeKilitKontrolEt,
                icon: const Icon(Icons.add_to_drive_rounded, size: 18, color: AppColors.primary),
                label: const Text(
                  "BULUT YEDEĞİ İLE OTURUM AÇ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primary),
                ),
              ),
            ] else ...[
              Text(
                _kurulumAdimi == 1 ? "4 Haneli Yeni PIN Belirleyin" : "PIN Kodunu Tekrar Girin",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final list = _kurulumAdimi == 1 ? _yeniPin : _yeniPinTekrar;
                  bool dolu = index < list.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: dolu ? 14 : 11,
                    height: dolu ? 14 : 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dolu ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: dolu ? AppColors.primary : AppColors.inactive.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              _daireselKlavyeGoster(_kurulumPinTusaBasildi, _kurulumPinSil),
            ],
          ],
        ),
      ),
    );
  }

  Widget _durumBStandartGirisArayuzu() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
              child: const Icon(Icons.import_contacts_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'KOLAY TİCARET DEFTERİ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hoş Geldiniz',
              style: TextStyle(fontSize: 12, color: AppColors.inactive),
            ),
            const SizedBox(height: 2),
            Text(
              _kayitliKullaniciAdi ?? 'Sayın Esnafımız',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),

        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _girilenPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: isFilled ? 15 : 11,
                    height: isFilled ? 15 : 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? AppColors.borc
                          : (isFilled ? AppColors.primary : Colors.transparent),
                      border: Border.all(
                        color: _isError
                            ? AppColors.borc
                            : (isFilled ? AppColors.primary : AppColors.inactive.withValues(alpha: 0.4)),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),

        _daireselKlavyeGoster(_standartPinTusaBasildi, _standartPinSil),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => setState(() => _ekranDurumu = PinEkraniDurumu.sifreSifirlama),
              child: const Text('Şifremi Unuttum', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: _hesabiSifirLaOnayDialog,
              child: const Text('Yeni Kullanıcı / Hesabı Sıfırla', style: TextStyle(color: AppColors.borc, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _durumCSifreSifirlamaArayuzu() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.06),
            ),
            child: const Icon(Icons.lock_reset_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text(
            'ŞİFRE SIFIRLAMA',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          const Text(
            'Yeni bir PIN kodu belirlemek için güvenlik sorunuzu yanıtlayın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.inactive),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inactive.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kayıtlı Güvenlik Sorunuz:', style: TextStyle(fontSize: 10.5, color: AppColors.inactive, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_kayitliSoru ?? 'Soru Bulunamadı', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _sifirlamaCevapController,
            style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
            decoration: _inputDekorasyon("Cevabınız", Icons.question_answer_outlined),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 46),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _sifreSifirlamaDogrula,
            child: const Text("DOĞRULA VE YENİ PIN BELİRLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: () => setState(() => _ekranDurumu = PinEkraniDurumu.standartGiris),
            child: const Text("Giriş Ekranına Dön", style: TextStyle(color: AppColors.inactive, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _daireselKlavyeGoster(
    Function(String) onRakam,
    VoidCallback onSil,
  ) {
    final List<List<String>> rakamGruplari = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    final List<List<String>> harfGruplari = [
      ['', 'ABC', 'DEF'],
      ['GHI', 'JKL', 'MNO'],
      ['PQRS', 'TUV', 'WXYZ'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (j) {
                return _daireselTusBileseni(
                  number: rakamGruplari[i][j],
                  subtext: harfGruplari[i][j],
                  onTap: () => onRakam(rakamGruplari[i][j]),
                );
              }),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 64, height: 64),
              _daireselTusBileseni(
                number: '0',
                subtext: '',
                onTap: () => onRakam('0'),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  onPressed: onSil,
                  icon: const Icon(Icons.backspace_outlined, size: 22),
                  splashRadius: 32,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _daireselTusBileseni({
    required String number,
    required String subtext,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.inactive.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              if (subtext.isNotEmpty)
                Text(
                  subtext,
                  style: const TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inactive,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
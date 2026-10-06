/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';
import 'bulut_seviye.dart';
import 'tema_renk_paleti.dart';
import 'yedek_esitleme_servisi.dart';
import 'google_drive_servisi.dart';
import 'google_drive_oturum_servisi.dart';

class AyarlarEkrani extends StatefulWidget {
  final Function(String title)? onTitleChanged;

  const AyarlarEkrani({super.key, this.onTitleChanged});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  final _storage = const FlutterSecureStorage();
  bool _yukleniyor = false;
  bool _driveSenkronizasyonAktif = false;

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
    _driveDurumunuYukle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTitleChanged?.call('AYARLAR');
    });
  }

  /// Drive senkronizasyon anahtarının yerel durumunu oku
  Future<void> _driveDurumunuYukle() async {
    final String? durum = await _storage.read(key: 'drive_aktif_mi');
    if (mounted) {
      setState(() {
        _driveSenkronizasyonAktif = (durum == 'evet');
      });
    }
  }

  /// Drive senkronizasyon şalteri değiştirildiğinde çalışan işlev
  Future<void> _driveSenkronizasyonDegistir(bool yeniDeger) async {
  setState(() => _yukleniyor = true);
  try {
    if (yeniDeger) {
      // GoogleDriveOturumServisi ile oturum ve kilit akışını başlatıyoruz
      final oturumServisi = GoogleDriveOturumServisi();
      final kilitSonuc = await oturumServisi.oturumKilitDurumuKontrolEt(forceAc: true);
      
      final bool oturumBasarili = (kilitSonuc == OturumKilitDurumu.kilitAlindi || 
                                   kilitSonuc == OturumKilitDurumu.kilitBizde);
      
      if (oturumBasarili) {
        await _storage.write(key: 'drive_aktif_mi', value: 'evet');
        await _storage.write(key: 'drive_bagli_mi', value: 'evet');
        
        if (mounted) {
          setState(() {
            _driveSenkronizasyonAktif = true;
          });
        }

        BulutDurumServisi.guncelle(
          seviye: BulutSeviye.sari,
          baslik: "Drive Bağlandı",
          aciklama: "Otomatik senkronizasyon ve eşitleme aktif.",
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Otomatik Google Drive Senkronizasyonu aktifleştirildi.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        await _storage.write(key: 'drive_aktif_mi', value: 'hayir');
        if (mounted) {
          setState(() {
            _driveSenkronizasyonAktif = false;
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Drive oturumu açılamadığı için senkronizasyon başlatılamadı.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      // Senkronizasyon kapatıldığında kilidi de kaldırıyoruz
      final oturumServisi = GoogleDriveOturumServisi();
      await oturumServisi.kilidiKaldir();

      await _storage.write(key: 'drive_aktif_mi', value: 'hayir');
      if (mounted) {
        setState(() {
          _driveSenkronizasyonAktif = false;
        });
      }

      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.gri,
        baslik: "Google Drive Pasif",
        aciklama: "Otomatik senkronizasyon kapatıldı.",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Otomatik senkronizasyon kapatıldı. Arka plan işlemleri durduruldu.'),
          backgroundColor: AppColors.inactive,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hata oluştu: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  } finally {
    if (mounted) setState(() => _yukleniyor = false);
  }
}

  InputDecoration _inputDekorasyon(String label, IconData icon, {String? suffixText, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      isDense: true,
      labelStyle: const TextStyle(color: AppColors.inactive, fontSize: 11),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 16),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  Future<void> _bulutaYedekle() async {
    setState(() => _yukleniyor = true);
    try {
      final esitlemeServisi = YedekEsitlemeServisi();
      
      await esitlemeServisi.yerelZamanDamgasiGuncelle();
      await esitlemeServisi.yerelVeriyiGarantiliYedekle();

      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.yesil,
        baslik: "Bulut Eşitlendi",
        aciklama: "Google Drive yedeği güncel ve tam senkronize.",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yedekleme başarıyla tamamlandı.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      BulutDurumServisi.guncelle(
        seviye: BulutSeviye.sari,
        baslik: "Yedekleme Hatası",
        aciklama: "Manuel yedekleme tamamlanamadı.",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedekleme hatası: $e'), 
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _sifreGuncellemeDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.95,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Yeni PIN Belirle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.inactive, size: 20),
                        onPressed: () => Navigator.pop(dialogContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDekorasyon('4 Haneli Güvenlik PIN Kodu', Icons.key_rounded),
                    validator: (val) {
                      if (val == null || val.length < 4) {
                        return 'Lütfen 4 haneli bir sayı giriniz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("İptal", style: TextStyle(color: AppColors.inactive, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            await _storage.write(key: 'uygulama_pin', value: controller.text);
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Uygulama PIN kodu başarıyla güncellendi.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text("Kaydet", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _guvenlikGuncellemeDialog() {
    String? secilenSoru;
    final cevapController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.cardBackground,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Container(
                width: MediaQuery.of(dialogContext).size.width * 0.95,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.security_rounded, color: AppColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Güvenlik Sorusu Güncelle',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.inactive, size: 20),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.cardBackground,
                        style: const TextStyle(color: AppColors.primary, fontSize: 12.5),
                        initialValue: secilenSoru,
                        isExpanded: true,
                        decoration: _inputDekorasyon('Güvenlik Sorusu Seçin', Icons.help_outline_rounded),
                        hint: const Text("Soru Seçiniz...", style: TextStyle(fontSize: 12, color: AppColors.inactive)),
                        items: _guvenlikSorulari.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => secilenSoru = val),
                        validator: (val) => val == null ? 'Lütfen bir güvenlik sorusu seçiniz.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cevapController,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        decoration: _inputDekorasyon('Güvenlik Yanıtınız', Icons.question_answer_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Lütfen yanıtınızı giriniz.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text("İptal", style: TextStyle(color: AppColors.inactive, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                await _storage.write(key: 'guvenlik_sorusu', value: secilenSoru);
                                await _storage.write(key: 'guvenlik_cevabi', value: cevapController.text.trim().toLowerCase());

                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Güvenlik sorusu ve cevabı güncellendi.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text("Kaydet", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _oturumKapatDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.95,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Oturumu Kapat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.inactive, size: 20),
                      onPressed: () => Navigator.pop(dialogContext),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    "Google Drive bağlantınız kesilecek ve uygulama oturumunuz kapatılacaktır. Yerel verileriniz cihazınızda kalmaya devam eder.",
                    style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text("Vazgeç", style: TextStyle(color: AppColors.inactive, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () async {
                        final driveServisi = GoogleDriveServisi();
                        await driveServisi.oturumuKapat();

                        await _storage.write(key: 'drive_aktif_mi', value: 'hayir');
                        await _storage.delete(key: 'drive_bagli_mi');

                        final esitlemeServisi = YedekEsitlemeServisi();
                        await esitlemeServisi.yerelZamanDamgasiGuncelle();

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Google Drive bağlantısı kesildi.',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            backgroundColor: AppColors.inactive,
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        GlobalSessionGuard.isSessionActive = false;
                        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/pin', (route) => false);
                      },
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text("Oturumu Kapat", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Deprecated 'activeColor' yerine 'activeThumbColor' kullanılarak güncellenmiş Switch widget'ı
  Widget _buildSwitchAyarKartItem({
    required IconData icon,
    required String baslik,
    required String aciklama,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = AppColors.primary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inactive.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  aciklama,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inactive,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
            inactiveThumbColor: AppColors.inactive,
            inactiveTrackColor: AppColors.background,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAyarKartItem({
    required IconData icon,
    required String baslik,
    required String aciklama,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inactive.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      aciklama,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inactive,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inactive),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Güvenlik & PIN Ayarları",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.inactive,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAyarKartItem(
                    icon: Icons.lock_outline_rounded,
                    baslik: "Uygulama PIN Kodu",
                    aciklama: "Giriş şifrenizi yenileyin",
                    onTap: _sifreGuncellemeDialog,
                  ),
                  _buildAyarKartItem(
                    icon: Icons.security_rounded,
                    baslik: "Güvenlik Sorusu",
                    aciklama: "Şifre sıfırlama sorusunu güncelleyin",
                    onTap: _guvenlikGuncellemeDialog,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Bulut Senkronizasyon & Yedekleme",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.inactive,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSwitchAyarKartItem(
                    icon: Icons.sync_rounded,
                    baslik: "Otomatik Google Drive Senkronizasyonu",
                    aciklama: _driveSenkronizasyonAktif
                        ? "Arka planda canlı çakışma ve eşitleme takibi aktif"
                        : "Arka plan işlemleri ve Google SDK kullanımı kapalı",
                    value: _driveSenkronizasyonAktif,
                    onChanged: _driveSenkronizasyonDegistir,
                  ),
                  _buildAyarKartItem(
                    icon: Icons.cloud_upload_outlined,
                    baslik: "Manuel Bulut Yedekleme",
                    aciklama: "Defterinizi hemen Google Drive'a yedekleyin",
                    onTap: _bulutaYedekle,
                  ),
                  _buildAyarKartItem(
                    icon: Icons.power_settings_new_rounded,
                    baslik: "Oturumu Kapat",
                    aciklama: "Google Drive bağlantısını keser ve giriş ekranına döner",
                    onTap: _oturumKapatDialog,
                    iconColor: AppColors.error,
                  ),
                ],
              ),
            ),
    );
  }
}
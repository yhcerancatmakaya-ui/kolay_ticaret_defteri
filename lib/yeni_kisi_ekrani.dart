/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'modeller.dart';
import 'tema_renk_paleti.dart'; 
import 'yedek_esitleme_servisi.dart';

/// Yazılan harfleri otomatik büyük harfe dönüştüren formatlayıcı
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Türkiye Telefon Numarası Formatlayıcısı: 0 XXX XXX XX XX
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    if (!digitsOnly.startsWith('0')) {
      digitsOnly = '0$digitsOnly';
    }

    if (digitsOnly.length > 11) {
      digitsOnly = digitsOnly.substring(0, 11);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 1 || i == 4 || i == 7 || i == 9) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class YeniKisiEkrani extends StatefulWidget {
  const YeniKisiEkrani({super.key});

  @override
  State<YeniKisiEkrani> createState() => _YeniKisiEkraniState();
}

class _YeniKisiEkraniState extends State<YeniKisiEkrani> {
  final _isimController = TextEditingController();
  final _telefonController = TextEditingController(text: "0 ");
  final _formKey = GlobalKey<FormState>();

  bool _isMusteri = true;
  bool _isTedarikci = false;
  bool _isOrtak = false;

  @override
  void dispose() {
    _isimController.dispose();
    _telefonController.dispose();
    super.dispose();
  }

  void _kisiKaydet() async {
    final isimYazisi = _isimController.text.trim();
    if (isimYazisi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir isim yazın!'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!_isMusteri && !_isTedarikci && !_isOrtak) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir sıfat (Müşteri, Tedarikçi veya Ortak) seçin!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String rawTelefon = _telefonController.text.trim();
    String kayitliTelefon = (rawTelefon == '0' || rawTelefon.isEmpty) ? '' : rawTelefon;

    final yeniKisi = Kisi(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isim: isimYazisi,
      telefon: kayitliTelefon,
      isMusteri: _isMusteri,
      isTedarikci: _isTedarikci,
      isOrtak: _isOrtak,
      islemler: [],
    );

    final kutu = Hive.box('defterKutusu');
    await kutu.put(yeniKisi.id, yeniKisi.toMap()); 

    final YedekEsitlemeServisi esitlemeServisi = YedekEsitlemeServisi();
    await esitlemeServisi.yerelZamanDamgasiGuncelle();

    if (!mounted) return;
    Navigator.pop(context);

    esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) {
      debugPrint("Bulut senkronizasyonu başarısız (Sistem yerelde çalışıyor): $hata");
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.primary,
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Yeni Kişi', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary, letterSpacing: 0.5),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'KİŞİ VEYA FİRMA ADI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withValues(alpha: 0.6),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _isimController,
                maxLength: 35,
                style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(35),
                  UpperCaseTextFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'ÖRN: AHMET YILMAZ',
                  counterStyle: TextStyle(color: AppColors.primary.withValues(alpha: 0.4)),
                  hintStyle: TextStyle(color: AppColors.inactive.withValues(alpha: 0.6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.inactive.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TELEFON NUMARASI (OPSİYONEL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefonController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                inputFormatters: [
                  PhoneInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '0 5XX XXX XX XX',
                  hintStyle: TextStyle(color: AppColors.inactive.withValues(alpha: 0.6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.inactive.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'KİŞİ SIFATI / ROLÜ (BİRDEN FAZLA SEÇİLEBİLİR)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inactive.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _sifatSwitchTile(
                      baslik: 'MÜŞTERİ',
                      aciklama: 'Mal veya hizmet satışı yapılan kişi/firma',
                      icon: Icons.person_outline_rounded,
                      degisken: _isMusteri,
                      onChanged: (v) => setState(() => _isMusteri = v),
                    ),
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _sifatSwitchTile(
                      baslik: 'TEDARİKÇİ (TOPTANCI)',
                      aciklama: 'Mal veya hizmet satın alınan kişi/firma',
                      icon: Icons.local_shipping_outlined,
                      degisken: _isTedarikci,
                      onChanged: (v) => setState(() => _isTedarikci = v),
                    ),
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _sifatSwitchTile(
                      baslik: 'ORTAK',
                      aciklama: 'İşletme sermayesine veya kârına ortak olan kişi',
                      icon: Icons.handshake_outlined,
                      degisken: _isOrtak,
                      onChanged: (v) => setState(() => _isOrtak = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _kisiKaydet,
                child: const Text(
                  'Deftere Kaydet', 
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sifatSwitchTile({
    required String baslik,
    required String aciklama,
    required IconData icon,
    required bool degisken,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: degisken,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      secondary: Icon(icon, color: degisken ? AppColors.primary : AppColors.inactive),
      title: Text(
        baslik,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: degisken ? AppColors.primary : AppColors.inactive,
        ),
      ),
      subtitle: Text(
        aciklama,
        style: TextStyle(
          fontSize: 10.5,
          color: AppColors.inactive.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
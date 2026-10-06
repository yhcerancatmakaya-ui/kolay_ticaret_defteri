/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'tema_renk_paleti.dart';
import 'yedek_esitleme_servisi.dart';
import 'modeller.dart';

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

class KisiDuzenleSheet {
  static void goster(BuildContext context, Kisi kisi, {VoidCallback? onGuncellendi}) {
    final isimController = TextEditingController(text: kisi.isim);
    final initialPhone = kisi.telefon.isNotEmpty ? kisi.telefon : '0 ';
    final telefonController = TextEditingController(text: initialPhone);
    final esitlemeServisi = YedekEsitlemeServisi();

    bool isMusteri = kisi.isMusteri;
    bool isTedarikci = kisi.isTedarikci;
    bool isOrtak = kisi.isOrtak;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kişi Bilgilerini Düzenle',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.inactive),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: isimController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 14, color: AppColors.primary),
                    decoration: InputDecoration(
                      labelText: 'Kişi / Firma Adı',
                      labelStyle: const TextStyle(color: AppColors.inactive, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: telefonController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14, color: AppColors.primary),
                    inputFormatters: [
                      PhoneInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Telefon Numarası (Opsiyonel)',
                      labelStyle: const TextStyle(color: AppColors.inactive, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(height: 12),
                  const Text(
                    'Ticari Sıfatlar / Rolleri:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.inactive),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Müşteri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    value: isMusteri,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setModalState(() => isMusteri = val ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Tedarikçi (Toptancı)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                    value: isTedarikci,
                    activeColor: Colors.orange.shade800,
                    onChanged: (val) => setModalState(() => isTedarikci = val ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Ortak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                    value: isOrtak,
                    activeColor: Colors.teal.shade700,
                    onChanged: (val) => setModalState(() => isOrtak = val ?? false),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final yeniIsim = isimController.text.trim();
                      if (yeniIsim.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kişi adı boş bırakılamaz!'), backgroundColor: AppColors.borc),
                        );
                        return;
                      }
                      if (!isMusteri && !isTedarikci && !isOrtak) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('En az bir sıfat seçilmelidir!'), backgroundColor: AppColors.borc),
                        );
                        return;
                      }

                      String rawTelefon = telefonController.text.trim();
                      String guncelTelefon = (rawTelefon == '0' || rawTelefon.isEmpty) ? '' : rawTelefon;

                      final guncelKisi = Kisi(
                        id: kisi.id,
                        isim: yeniIsim,
                        telefon: guncelTelefon,
                        isMusteri: isMusteri,
                        isTedarikci: isTedarikci,
                        isOrtak: isOrtak,
                        islemler: kisi.islemler,
                      );

                      final box = Hive.box('defterKutusu');
                      await box.put(guncelKisi.id, guncelKisi.toMap());

                      await esitlemeServisi.yerelZamanDamgasiGuncelle();

                      if (context.mounted) {
                        Navigator.pop(modalContext);
                        if (onGuncellendi != null) {
                          onGuncellendi();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kişi bilgileri güncellendi.'), backgroundColor: AppColors.alacak),
                        );
                      }

                      esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) {
                        debugPrint("Bulut senkronizasyonu başarısız (Sistem yerelde çalışıyor): $hata");
                        return false;
                      });
                    },
                    child: const Text('GÜNCELLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
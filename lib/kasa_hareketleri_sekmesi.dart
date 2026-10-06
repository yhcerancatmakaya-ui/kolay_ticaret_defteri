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
import 'yardimcilar.dart';
import 'yedek_esitleme_servisi.dart';

class BinlikAyiriciFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String temiz = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (temiz.isEmpty) {
      return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    }
    final double? deger = double.tryParse(temiz);
    if (deger == null) return oldValue;
    final String formatli = formatPara(deger);
    return TextEditingValue(
      text: formatli,
      selection: TextSelection.collapsed(offset: formatli.length),
    );
  }
}

class KasaHareketleriSekmesi extends StatefulWidget {
  final Kisi kisi;

  const KasaHareketleriSekmesi({super.key, required this.kisi});

  @override
  State<KasaHareketleriSekmesi> createState() => _KasaHareketleriSekmesiState();
}

typedef HesapHareketleriSekmesi = KasaHareketleriSekmesi;

class _KasaHareketleriSekmesiState extends State<KasaHareketleriSekmesi> {
  String? _seciliHareketId;
  bool _isHareketlerAcik = true;
  bool _isPlanAcik = true;

  static final Color _sermayeliBtnColor = AppColors.primaryRed.withValues(alpha: 0.85); 
  static final Color _sermayesizBtnColor = AppColors.secondaryRed.withValues(alpha: 0.65);
  static const double _azamiTutar = 1000000000.0;

  String _tarihFormatla(DateTime tarih) {
    return "${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}";
  }

  void _hatirlaticiPlanla(DateTime planTarihi, String aciklama, double tutar) {
    debugPrint("Bildirim planlandı: $planTarihi tarihinde ₺$tutar ödeme planı hatırlatılacak. Detay: $aciklama");
  }

  void _planDurumGuncelle(Box box, Kisi guncelKisi, TicariIslem islem, String yeniDurum) async {
    // Aynı duruma tıklandıysa işlem yapma
    if (islem.planDurumu == yeniDurum) return;

    String? yeniGerceklesenId = islem.gerceklesenIslemId;

    // 1. Durum GERÇEKLEŞTİ yapıldığında Kasa Hareketi Oluştur
    if (yeniDurum == 'gerceklesti') {
      if (yeniGerceklesenId == null || yeniGerceklesenId.isEmpty) {
        final bool isGiris = islem.tur == IslemTuru.paraAlindi || 
                             islem.tur == IslemTuru.odemeAldik || 
                             islem.tur == IslemTuru.borcVerildi;

        final String temizAciklama = islem.aciklama.replaceFirst("[PLAN] ", "");
        final String kasaIslemId = "${DateTime.now().millisecondsSinceEpoch}_kasa";

        final yeniKasaHareketi = TicariIslem(
          id: kasaIslemId,
          kategori: IslemKategorisi.gunluk,
          tur: isGiris ? IslemTuru.paraAlindi : IslemTuru.paraVerildi,
          aciklama: "[ÖDEME PLANINDAN] $temizAciklama",
          kayitTarihi: DateTime.now(), // Gerçekleştiği anın tarihi
          tutar: islem.tutar,
          isPlan: false,
          planDurumu: '',
        );

        guncelKisi.islemler.add(yeniKasaHareketi);
        yeniGerceklesenId = kasaIslemId;
      }
    } 
    // 2. Durum GERÇEKLEŞMEDİ veya BEKLİYOR yapıldığında varsa bağlı Kasa Hareketini Sil
    else {
      if (yeniGerceklesenId != null && yeniGerceklesenId.isNotEmpty) {
        guncelKisi.islemler.removeWhere((el) => el.id == yeniGerceklesenId);
        yeniGerceklesenId = null;
      }
    }

    // 3. Plan Kaydını Güncelle
    final index = guncelKisi.islemler.indexWhere((el) => el.id == islem.id);
    if (index != -1) {
      guncelKisi.islemler[index] = TicariIslem(
        id: islem.id,
        kategori: islem.kategori,
        tur: islem.tur,
        aciklama: islem.aciklama,
        kayitTarihi: islem.kayitTarihi,
        tutar: islem.tutar,
        miktar: islem.miktar,
        vadeSayisi: islem.vadeSayisi,
        taksitler: islem.taksitler,
        bagliOdemeler: islem.bagliOdemeler,
        kapandiMi: islem.kapandiMi,
        isPlan: islem.isPlan,
        planDurumu: yeniDurum,
        gerceklesenIslemId: yeniGerceklesenId,
      );
    }

    // Hive Kayıt ve Yedekleme İşlemleri
    await box.put(guncelKisi.id, guncelKisi.toMap());
    final esitlemeServisi = YedekEsitlemeServisi();
    await esitlemeServisi.yerelZamanDamgasiGuncelle();
    if (mounted) {
      setState(() {});
    }
    esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) => false);
  }
  
  void _kasaPlanMesajGonder(Kisi kisi, TicariIslem islem) {
    final bool isGiris = islem.tur == IslemTuru.paraAlindi || 
                         islem.tur == IslemTuru.odemeAldik || 
                         islem.tur == IslemTuru.borcVerildi;

    final String tarihStr = _tarihFormatla(islem.kayitTarihi);
    final String tutarStr = formatPara(islem.tutar);
    final String kisiAdi = kisi.isim;

    String mesaj = "";
    if (isGiris) {
      mesaj = "Sayın $kisiAdi, $tarihStr tarihli ₺$tutarStr tutarındaki ödeme planı transferi henüz kasamıza ulaşmamıştır. Lütfen ödemenizi kontrol ederek en kısa sürede tamamlayınız.";
    } else {
      mesaj = "Sayın $kisiAdi, $tarihStr tarihli ₺$tutarStr tutarındaki ödeme planı transferinde gecikme yaşanmıştır. İşleminiz en kısa sürede gerçekleştirilecektir.";
    }

    Clipboard.setData(ClipboardData(text: mesaj));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bilgilendirme metni panoya kopyalandı:\n"$mesaj"'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildPlanSatiri(TicariIslem islem, Kisi guncelKisi) {
    final bool isGiris = islem.tur == IslemTuru.paraAlindi || 
                         islem.tur == IslemTuru.odemeAldik || 
                         islem.tur == IslemTuru.borcVerildi;

    Color durumRengi;
    String durumEtiketi;
    IconData durumIkonu;

    if (islem.planDurumu == 'gerceklesti') {
      durumRengi = AppColors.success;
      durumEtiketi = "GERÇEKLEŞTİ";
      durumIkonu = Icons.thumb_up_alt_rounded;
    } else if (islem.planDurumu == 'gerceklesmedi') {
      durumRengi = AppColors.error;
      durumEtiketi = "GERÇEKLEŞMEMİŞTİR";
      durumIkonu = Icons.thumb_down_alt_rounded;
    } else {
      durumRengi = Colors.orange;
      durumEtiketi = "BEKLİYOR";
      durumIkonu = Icons.hourglass_empty_rounded;
    }

    return Container(
      color: islem.planDurumu == 'gerceklesti'
          ? AppColors.success.withValues(alpha: 0.04)
          : (islem.planDurumu == 'gerceklesmedi' ? AppColors.error.withValues(alpha: 0.04) : Colors.transparent),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(durumIkonu, color: durumRengi, size: 18),
        title: Text(
          islem.aciklama.replaceFirst("[PLAN] ", ""),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            decoration: islem.planDurumu == 'gerceklesmedi' ? TextDecoration.lineThrough : null,
            color: islem.planDurumu == 'gerceklesmedi' ? AppColors.inactive : AppColors.primary,
          ),
        ),
        subtitle: Row(
          children: [
            Text(_tarihFormatla(islem.kayitTarihi), style: const TextStyle(fontSize: 10, color: AppColors.inactive)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: durumRengi.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                durumEtiketi,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: durumRengi),
              ),
            ),
            if (islem.planDurumu == 'gerceklesmedi') ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _kasaPlanMesajGonder(guncelKisi, islem),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.turkuaz.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, size: 10, color: AppColors.turkuaz),
                      SizedBox(width: 2),
                      Text("Mesaj", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.turkuaz)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          "₺${formatPara(islem.tutar)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: islem.planDurumu == 'gerceklesmedi' ? AppColors.inactive : (isGiris ? AppColors.alacak : AppColors.borc),
          ),
        ),
      ),
    );
  }

  Future<void> _kasaIslemiKaydet({
    required Box box,
    required Kisi guncelKisi,
    required double tutar,
    required DateTime tarih,
    required String aciklama,
    required IslemTuru tur,
    bool isPlan = false,
  }) async {
    final yeniIslem = TicariIslem(
      id: "${DateTime.now().millisecondsSinceEpoch}${isPlan ? "_plan" : "_kasa"}",
      kategori: IslemKategorisi.gunluk,
      tur: tur,
      aciklama: isPlan ? "[PLAN] $aciklama" : aciklama,
      kayitTarihi: tarih,
      tutar: tutar,
      isPlan: isPlan,
      planDurumu: isPlan ? 'bekliyor' : '',
    );

    guncelKisi.islemler.add(yeniIslem);
    await box.put(guncelKisi.id, guncelKisi.toMap());

    final esitlemeServisi = YedekEsitlemeServisi();
    await esitlemeServisi.yerelZamanDamgasiGuncelle();
    esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) {
      return false;
    });
  }

  void _hesapBaslatDiyalogu(BuildContext context, Box box, Kisi guncelKisi, {required bool sermayeliMi}) async {
    if (!sermayeliMi) {
      await _kasaIslemiKaydet(
        box: box,
        guncelKisi: guncelKisi,
        tutar: 0.0,
        tarih: DateTime.now(),
        tur: IslemTuru.paraAlindi,
        aciklama: "Hesap Açılışı (Sermayesiz)",
      );
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final TextEditingController tutarController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          title: const Text(
            "Sermaye Ekle ve Hesabı Aç",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tutarController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [BinlikAyiriciFormatter()],
                  autofocus: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: "Başlangıç Sermayesi (₺)",
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    labelStyle: TextStyle(fontSize: 12, color: AppColors.inactive),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Lütfen tutar girin';
                    final temiz = value.replaceAll('.', '');
                    final d = double.tryParse(temiz);
                    if (d == null || d <= 0) return 'Geçersiz tutar girdiniz';
                    if (d > _azamiTutar) return 'Tutar azami 1 Milyar ₺ olabilir';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("İPTAL", style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _sermayeliBtnColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final temizTutar = tutarController.text.replaceAll('.', '');
                  final dVal = double.parse(temizTutar);

                  await _kasaIslemiKaydet(
                    box: box,
                    guncelKisi: guncelKisi,
                    tutar: dVal,
                    tarih: DateTime.now(),
                    aciklama: "Açılış Sermayesi",
                    tur: IslemTuru.paraAlindi,
                    isPlan: false,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  setState(() {});
                }
              },
              child: const Text("BAŞLAT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _hareketSil(Box box, Kisi guncelKisi, String hareketId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 6),
            Text('KAYDI SİL', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Bu hareket kaydını defterden tamamen silmek istediğinize emin misiniz?",
          style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VAZGEÇ", style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () async {
              Navigator.pop(context);
              guncelKisi.islemler.removeWhere((el) => el.id == hareketId);
              await box.put(guncelKisi.id, guncelKisi.toMap());

              final esitlemeServisi = YedekEsitlemeServisi();
              await esitlemeServisi.yerelZamanDamgasiGuncelle();
              esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((_) => false);

              setState(() {
                _seciliHareketId = null;
              });
            },
            child: const Text("EVET, SİL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _hareketDuzenle(Box box, Kisi guncelKisi, TicariIslem islem) {
    final bool isPlan = islem.aciklama.startsWith("[PLAN] ");
    final String temizAciklama = isPlan ? islem.aciklama.replaceFirst("[PLAN] ", "") : islem.aciklama;
    
    final TextEditingController tutarController = TextEditingController(text: formatPara(islem.tutar));
    final TextEditingController aciklamaController = TextEditingController(text: temizAciklama);
    DateTime secilenTarih = islem.kayitTarihi;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              title: Text(
                isPlan ? "Ödeme Planını Düzenle" : "Kasa Hareketini Düzenle",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tutarController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [BinlikAyiriciFormatter()],
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: "Tutar (₺)",
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        labelStyle: TextStyle(fontSize: 12, color: AppColors.inactive),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Lütfen tutar girin';
                        final temiz = value.replaceAll('.', '');
                        final d = double.tryParse(temiz);
                        if (d == null || d <= 0) return 'Geçersiz tutar girdiniz';
                        if (d > _azamiTutar) return 'Tutar azami 1 Milyar ₺ olabilir';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: aciklamaController,
                      maxLength: 50,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: "Açıklama",
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        labelStyle: TextStyle(fontSize: 12, color: AppColors.inactive),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().length > 50) return 'Açıklama 50 karakteri geçemez';
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: secilenTarih,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            secilenTarih = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.inactive.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Tarih: ${_tarihFormatla(secilenTarih)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("İPTAL", style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final temizTutar = tutarController.text.replaceAll('.', '');
                      final dVal = double.parse(temizTutar);
                      final index = guncelKisi.islemler.indexWhere((el) => el.id == islem.id);
                      if (index != -1) {
                        guncelKisi.islemler[index] = TicariIslem(
                          id: islem.id,
                          kategori: islem.kategori,
                          tur: islem.tur,
                          aciklama: isPlan ? "[PLAN] ${aciklamaController.text.trim()}" : aciklamaController.text.trim(),
                          kayitTarihi: secilenTarih,
                          tutar: dVal,
                          miktar: islem.miktar,
                          vadeSayisi: islem.vadeSayisi,
                          taksitler: islem.taksitler,
                          bagliOdemeler: islem.bagliOdemeler,
                          kapandiMi: islem.kapandiMi,
                          isPlan: islem.isPlan,
                          planDurumu: islem.planDurumu,
                          gerceklesenIslemId: islem.gerceklesenIslemId,
                        );
                      }

                      await box.put(guncelKisi.id, guncelKisi.toMap());
                      
                      final esitlemeServisi = YedekEsitlemeServisi();
                      await esitlemeServisi.yerelZamanDamgasiGuncelle();
                      esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((_) => false);
                      
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      setState(() {
                        _seciliHareketId = null;
                      });
                    }
                  },
                  child: const Text("GÜNCELLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _kasaIslemDiyalogu(BuildContext context, Box box, Kisi guncelKisi, {required bool girisMi, bool isPlan = false}) {
    final TextEditingController tutarController = TextEditingController();
    final TextEditingController aciklamaController = TextEditingController(
      text: isPlan 
          ? "YENİ ÖDEME PLANI"
          : (girisMi ? "KASAYA PARA GİRİŞİ" : "KASADAN PARA ÇIKIŞI")
    );
    
    DateTime secilenTarih = DateTime.now();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool localGirisMi = girisMi;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.cardBackground,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPlan 
                                ? "Ödeme Planı Ekle"
                                : (localGirisMi ? "Kasaya Para Ekle" : "Kasadan Para Çıkar"),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 14, 
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.inactive, size: 18),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      if (isPlan) ...[
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    localGirisMi = true;
                                    aciklamaController.text = "ÖDEME PLANI PARA GİRİŞİ";
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: localGirisMi ? AppColors.alacak.withValues(alpha: 0.12) : AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: localGirisMi ? AppColors.alacak : AppColors.inactive.withValues(alpha: 0.2),
                                      width: localGirisMi ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward, size: 14, color: localGirisMi ? AppColors.alacak : AppColors.inactive),
                                      const SizedBox(width: 4),
                                      Text(
                                        "PARA GİRİŞİ",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: localGirisMi ? FontWeight.bold : FontWeight.normal,
                                          color: localGirisMi ? AppColors.alacak : AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    localGirisMi = false;
                                    aciklamaController.text = "ÖDEME PLANI PARA ÇIKIŞI";
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: !localGirisMi ? AppColors.borc.withValues(alpha: 0.12) : AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !localGirisMi ? AppColors.borc : AppColors.inactive.withValues(alpha: 0.2),
                                      width: !localGirisMi ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_upward, size: 14, color: !localGirisMi ? AppColors.borc : AppColors.inactive),
                                      const SizedBox(width: 4),
                                      Text(
                                        "PARA ÇIKIŞI",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: !localGirisMi ? FontWeight.bold : FontWeight.normal,
                                          color: !localGirisMi ? AppColors.borc : AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextFormField(
                        controller: tutarController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [BinlikAyiriciFormatter()],
                        autofocus: true,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: "Tutar (₺)",
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          labelStyle: TextStyle(color: AppColors.inactive, fontSize: 12),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Lütfen tutar girin';
                          final temiz = value.replaceAll('.', '');
                          final d = double.tryParse(temiz);
                          if (d == null || d <= 0) return 'Geçersiz tutar girdiniz';
                          if (d > _azamiTutar) return 'Tutar azami 1 Milyar ₺ olabilir';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: aciklamaController,
                        maxLength: 50,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: "Açıklama",
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          labelStyle: TextStyle(color: AppColors.inactive, fontSize: 12),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().length > 50) return 'Açıklama 50 karakteri geçemez';
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: secilenTarih,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              secilenTarih = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.inactive.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Tarih: ${_tarihFormatla(secilenTarih)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.inactive),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text("İPTAL", style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPlan 
                                    ? AppColors.primary 
                                    : (localGirisMi ? AppColors.alacak : AppColors.borc),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  final temizTutar = tutarController.text.replaceAll('.', '');
                                  final dVal = double.parse(temizTutar);

                                  await _kasaIslemiKaydet(
                                    box: box,
                                    guncelKisi: guncelKisi,
                                    tutar: dVal,
                                    tarih: secilenTarih,
                                    aciklama: aciklamaController.text.trim(),
                                    tur: localGirisMi ? IslemTuru.paraAlindi : IslemTuru.paraVerildi,
                                    isPlan: isPlan,
                                  );

                                  if (isPlan) {
                                    _hatirlaticiPlanla(secilenTarih, aciklamaController.text.trim(), dVal);
                                  }

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  setState(() {});
                                }
                              },
                              child: const Text("KAYDET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('defterKutusu').listenable(),
      builder: (context, Box box, _) {
        final hamKisi = box.get(widget.kisi.id);
        final Kisi guncelKisi = hamKisi != null 
            ? (hamKisi is Kisi ? hamKisi : Kisi.fromMap(Map<String, dynamic>.from(hamKisi)))
            : widget.kisi;

        final bool hesapAcikMi = guncelKisi.islemler.any((islem) {
          final bool isManuelKasaIslemi = islem.id.contains('_kasa') || 
          islem.aciklama == "Hesap Açılışı (Sermayesiz)" || 
          islem.aciklama == "Açılış Sermayesi";

          final bool isOrtakPesinKasaIslemi = islem.id.contains('_ortak_kasa') || 
          (islem.bagliIslemId != null && islem.bagliIslemId!.isNotEmpty);

          return isManuelKasaIslemi || isOrtakPesinKasaIslemi;
        });

        double toplamGiris = 0.0;
        double toplamCikis = 0.0;

        final List<TicariIslem> gerceklesmisIslemler = [];
        final List<TicariIslem> planlananIslemler = [];

        for (var islem in guncelKisi.islemler) {
          if (islem.isPlan) {
            planlananIslemler.add(islem);
          } else {
            final bool isManuelKasaIslemi = islem.id.contains('_kasa') || 
                islem.aciklama == "Hesap Açılışı (Sermayesiz)" || 
                islem.aciklama == "Açılış Sermayesi";

            final bool isOrtakPesinKasaIslemi = islem.id.contains('_ortak_kasa') || 
                (islem.bagliIslemId != null && islem.bagliIslemId!.isNotEmpty);

            if (!isManuelKasaIslemi && !isOrtakPesinKasaIslemi) {
              continue;
            }

            gerceklesmisIslemler.add(islem);

            final bool isGiris = islem.tur == IslemTuru.paraAlindi || 
                     islem.tur == IslemTuru.odemeAldik;

            if (isGiris) {
              toplamGiris += islem.tutar;
            } else {
              toplamCikis += islem.tutar;
            }
          }
        }

        gerceklesmisIslemler.sort((a, b) => b.kayitTarihi.compareTo(a.kayitTarihi));
        planlananIslemler.sort((a, b) => b.kayitTarihi.compareTo(a.kayitTarihi));

        final double netBakiye = toplamGiris - toplamCikis;

        if (!hesapAcikMi) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppColors.inactive.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      "Kasa Hesabı Bulunmamaktadır",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Lütfen hesap açılış şeklini seçerek kasayı aktifleştirin.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.inactive),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _sermayesizBtnColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: () => _hesapBaslatDiyalogu(context, box, guncelKisi, sermayeliMi: false),
                            icon: const Icon(Icons.check, color: Colors.white, size: 16),
                            label: const Text("Sermayesiz Başlat", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _sermayeliBtnColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: () => _hesapBaslatDiyalogu(context, box, guncelKisi, sermayeliMi: true),
                            icon: const Icon(Icons.add, color: Colors.white, size: 16),
                            label: const Text("Sermaye Ekle", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inactive.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      const Text("MEVCUT KASA BAKİYESİ", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.inactive, letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(
                        "₺${formatPara(netBakiye)}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: netBakiye >= 0 ? AppColors.alacak : AppColors.borc,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Text("Giren", style: TextStyle(fontSize: 9, color: AppColors.inactive)),
                              Text("₺${formatPara(toplamGiris)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.alacak)),
                            ],
                          ),
                          Container(height: 16, width: 1, color: AppColors.inactive.withValues(alpha: 0.3)),
                          Column(
                            children: [
                              const Text("Çıkan", style: TextStyle(fontSize: 9, color: AppColors.inactive)),
                              Text("₺${formatPara(toplamCikis)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.borc)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.alacak,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 0,
                              ),
                              onPressed: () => _kasaIslemDiyalogu(context, box, guncelKisi, girisMi: true),
                              icon: const Icon(Icons.add, size: 15, color: Colors.white),
                              label: const Text("Para Ekle", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.borc,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 0,
                              ),
                              onPressed: () => _kasaIslemDiyalogu(context, box, guncelKisi, girisMi: false),
                              icon: const Icon(Icons.remove, size: 15, color: Colors.white),
                              label: const Text("Para Çıkar", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                              onPressed: () => _kasaIslemDiyalogu(context, box, guncelKisi, girisMi: true, isPlan: true),
                              icon: const Icon(Icons.event_note_rounded, size: 15),
                              label: const Text("Plan Ekle", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  color: AppColors.cardBackground,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.inactive.withValues(alpha: 0.2)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _isHareketlerAcik,
                      dense: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      childrenPadding: EdgeInsets.zero,
                      onExpansionChanged: (val) => setState(() => _isHareketlerAcik = val),
                      title: const Text("Kasa Hareketleri", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      subtitle: Text("${gerceklesmisIslemler.length} Kayıtlı Hareket", style: const TextStyle(fontSize: 9.5, color: AppColors.inactive)),
                      children: [
                        if (gerceklesmisIslemler.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text("Henüz kaydedilmiş kasa hareketi bulunmuyor.", style: TextStyle(fontSize: 11, color: AppColors.inactive)),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: gerceklesmisIslemler.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                            itemBuilder: (context, index) {
                              final islem = gerceklesmisIslemler[index];
                              final bool seciliMi = _seciliHareketId == islem.id;
                              final bool isGiris = islem.tur == IslemTuru.paraAlindi || 
                                                   islem.tur == IslemTuru.odemeAldik || 
                                                   islem.tur == IslemTuru.borcVerildi;

                              return Column(
                                children: [
                                  ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    onTap: () {
                                      setState(() {
                                        _seciliHareketId = seciliMi ? null : islem.id;
                                      });
                                    },
                                    leading: Icon(
                                      isGiris ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: isGiris ? AppColors.alacak : AppColors.borc,
                                      size: 16,
                                    ),
                                    title: Text(islem.aciklama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primary)),
                                    subtitle: Text(_tarihFormatla(islem.kayitTarihi), style: const TextStyle(fontSize: 9.5, color: AppColors.inactive)),
                                    trailing: Text(
                                      "₺${formatPara(islem.tutar)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                        color: isGiris ? AppColors.alacak : AppColors.borc,
                                      ),
                                    ),
                                  ),
                                  if (seciliMi)
                                    Container(
                                      color: AppColors.background,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primary,
                                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            onPressed: () => _hareketDuzenle(box, guncelKisi, islem),
                                            icon: const Icon(Icons.edit_outlined, size: 13),
                                            label: const Text("DÜZENLE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 6),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              side: const BorderSide(color: AppColors.error),
                                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            onPressed: () => _hareketSil(box, guncelKisi, islem.id),
                                            icon: const Icon(Icons.delete_outline, size: 13),
                                            label: const Text("SİL", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                Card(
                  color: AppColors.cardBackground,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.inactive.withValues(alpha: 0.2)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _isPlanAcik,
                      dense: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      childrenPadding: EdgeInsets.zero,
                      onExpansionChanged: (val) => setState(() => _isPlanAcik = val),
                      title: const Text("Ödeme Planları & Hatırlatıcılar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      subtitle: Text("${planlananIslemler.length} Kayıtlı Plan", style: const TextStyle(fontSize: 9.5, color: AppColors.inactive)),
                      children: [
                        if (planlananIslemler.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text("Henüz kayıtlı ödeme planı bulunmamaktadır.", style: TextStyle(fontSize: 11, color: AppColors.inactive)),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: planlananIslemler.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                            itemBuilder: (context, index) {
                              final islem = planlananIslemler[index];
                              final bool seciliMi = _seciliHareketId == islem.id;
                              final String mevcutDurum = islem.planDurumu;

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _seciliHareketId = seciliMi ? null : islem.id;
                                      });
                                    },
                                    child: _buildPlanSatiri(islem, guncelKisi),
                                  ),
                                  if (seciliMi)
                                    Container(
                                      color: AppColors.background,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (mevcutDurum != 'gerceklesti')
                                            IconButton(
                                              tooltip: "Gerçekleşti",
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppColors.success, width: 1),
                                                ),
                                                child: const Icon(Icons.thumb_up_alt_rounded, size: 15, color: AppColors.success),
                                              ),
                                              onPressed: () => _planDurumGuncelle(box, guncelKisi, islem, 'gerceklesti'),
                                            ),
                                          if (mevcutDurum != 'gerceklesti') const SizedBox(width: 8),

                                          if (mevcutDurum != 'gerceklesmedi')
                                            IconButton(
                                              tooltip: "Gerçekleşmedi",
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppColors.error, width: 1),
                                                ),
                                                child: const Icon(Icons.thumb_down_alt_rounded, size: 15, color: AppColors.error),
                                              ),
                                              onPressed: () => _planDurumGuncelle(box, guncelKisi, islem, 'gerceklesmedi'),
                                            ),
                                          if (mevcutDurum != 'gerceklesmedi') const SizedBox(width: 8),

                                          if (mevcutDurum != 'bekliyor')
                                            IconButton(
                                              tooltip: "Bekliyor",
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.orange, width: 1),
                                                ),
                                                child: const Icon(Icons.hourglass_empty_rounded, size: 15, color: Colors.orange),
                                              ),
                                              onPressed: () => _planDurumGuncelle(box, guncelKisi, islem, 'bekliyor'),
                                            ),
                                          if (mevcutDurum != 'bekliyor') const SizedBox(width: 8),

                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primary,
                                              side: BorderSide(color: AppColors.inactive.withValues(alpha: 0.4), width: 1),
                                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            onPressed: () => _hareketDuzenle(box, guncelKisi, islem),
                                            icon: const Icon(Icons.edit_outlined, size: 13),
                                            label: const Text("DÜZENLE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 6),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              side: BorderSide(color: AppColors.error.withValues(alpha: 0.4), width: 1),
                                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            onPressed: () => _hareketSil(box, guncelKisi, islem.id),
                                            icon: const Icon(Icons.delete_outline, size: 13),
                                            label: const Text("SİL", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
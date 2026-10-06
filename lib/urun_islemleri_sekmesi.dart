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
import 'ticari_islem_wizard_dialog.dart';

enum UrunIslemModu { musteri, tedarikci, hepsi }

class UrunIslemleriSekmesi extends StatefulWidget {
  final Kisi kisi;
  final UrunIslemModu mod;

  const UrunIslemleriSekmesi({
    super.key, 
    required this.kisi, 
    this.mod = UrunIslemModu.hepsi
  });

  @override
  State<UrunIslemleriSekmesi> createState() => _UrunIslemleriSekmesiState();
}

class _UrunIslemleriSekmesiState extends State<UrunIslemleriSekmesi> {
  
  String _tarihFormatla(DateTime tarih) {
    return "${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}";
  }

  List<bool> _hesaplaTaksitKapanmaDurumlari(TicariIslem islem) {
    if (islem.taksitler == null) return [];
    
    if (islem.kapandiMi || islem.kalanTutar <= 0) {
      return List.generate(islem.taksitler!.length, (index) => true);
    }

    int kalanKurusHavuzu = 0;
    for (var odeme in islem.bagliOdemeler) {
      kalanKurusHavuzu += (odeme.tutar * 100).round();
    }

    List<bool> durumlar = [];
    for (var taksit in islem.taksitler!) {
      int taksitKurus = (taksit.vadeTutari * 100).round();
      if (kalanKurusHavuzu >= taksitKurus) {
        durumlar.add(true);
        kalanKurusHavuzu -= taksitKurus;
      } else {
        durumlar.add(false);
        kalanKurusHavuzu = 0;
      }
    }
    return durumlar;
  }

  void _taksitDurumGuncelle(Box box, Kisi guncelKisi, TicariIslem islem, int taksitIndex, String yeniDurum, bool taksitKapandi) async {
    // 🔒 Ödenmiş/Kapanmış taksitlerde durum değiştirilmesini engelle
    if (taksitKapandi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu taksitin ödemesi gerçekleşmiştir. Durumu değiştirilemez.'),
          backgroundColor: AppColors.inactive,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (islem.taksitler != null && taksitIndex < islem.taksitler!.length) {
      islem.taksitler![taksitIndex].durum = yeniDurum;
      if (yeniDurum == 'gerceklesti') {
        islem.taksitler![taksitIndex].odendiMi = true;
        islem.taksitler![taksitIndex].odemeTarihi = DateTime.now();
      } else {
        islem.taksitler![taksitIndex].odendiMi = false;
        islem.taksitler![taksitIndex].odemeTarihi = null;
      }

      await box.put(guncelKisi.id, guncelKisi.toMap());
      final esitlemeServisi = YedekEsitlemeServisi();
      await esitlemeServisi.yerelZamanDamgasiGuncelle();
      if (mounted) {
        setState(() {});
      }
      esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) => false);
    }
  }

  void _taksitMesajGonder(Kisi kisi, Taksit taksit, bool alacakMi) {
    final String tarihStr = _tarihFormatla(taksit.vadeTarihi);
    final String tutarStr = formatPara(taksit.vadeTutari);
    final String kisiAdi = kisi.isim;

    String mesaj = "";
    if (alacakMi) {
      mesaj = "Sayın $kisiAdi, $tarihStr vadeli ₺$tutarStr tutarındaki ödemeniz gerçekleşmemiştir. Mağduriyet yaşanmaması ve yasal süreçlerin başlatılmaması adına ödemenizi en kısa sürede yapmanızı rica ederiz.";
    } else {
      mesaj = "Sayın $kisiAdi, $tarihStr vadeli ₺$tutarStr tutarındaki ödemenize ilişkin transfer gecikmeye uğramıştır. Tarafımızca işleme alınmış olup en kısa sürede hesabınıza aktarılacaktır. Bilgilerinize sunarız.";
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

  void _islemKaliciSil(BuildContext context, Box box, Kisi guncelKisi, TicariIslem islem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text('İŞLEMİ SİL', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
            ],
          ),
          content: Text(
            '"${islem.aciklama.toUpperCase()}" açıklamalı ürün işlemini silmek istediğinize emin misiniz?\n\nBu işlem stok verilerini de otomatik tersine çevirecektir.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.primary, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('VAZGEÇ', style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                // --- STOK GÜNCELLEME İŞLEMİ ---
                if (islem.stokUrunId != null && islem.stokUrunId!.isNotEmpty) {
                  final stokKutusu = Hive.box('stokKutusu');
                  final hamStok = stokKutusu.get(islem.stokUrunId);
                  
                  if (hamStok != null) {
                    StokUrun urun = hamStok is StokUrun 
                        ? hamStok 
                        : StokUrun.fromMap(Map<String, dynamic>.from(hamStok));

                    final double islemMiktari = islem.miktar ?? 0.0;

                    bool satisMi = islem.tur == IslemTuru.alacagimiz || islem.tur == IslemTuru.odemeAldik;
                    final double yeniStok = satisMi 
                        ? urun.mevcutStok + islemMiktari 
                        : urun.mevcutStok - islemMiktari;

                    final guncelUrun = urun.copyWith(mevcutStok: yeniStok);

                    await stokKutusu.put(guncelUrun.id, guncelUrun.toMap());
                  }
                }

                // --- İŞLEMİ KİŞİDEN SİLME ---
                guncelKisi.islemler.removeWhere((el) => el.id == islem.id);
                await box.put(guncelKisi.id, guncelKisi.toMap());
                
                final esitlemeServisi = YedekEsitlemeServisi();
                await esitlemeServisi.yerelZamanDamgasiGuncelle();

                if (!context.mounted) return;
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('İşlem silindi ve stok miktarı güncellendi.'),
                    backgroundColor: AppColors.success,
                  ),
                );

                esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) => false);
              },
              child: const Text('EVET, SİL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _ticariIslemWizardAc(BuildContext context, Box box, Kisi guncelKisi) async {
    final String varsayilanTur = widget.mod == UrunIslemModu.tedarikci ? 'alis' : 'satis';

    final sonuc = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TicariIslemWizardDialog(
        seciliKisi: guncelKisi,
        kisiKilitli: true,
        varsayilanIslemTuru: varsayilanTur,
      ),
    );

    if (sonuc != null) {
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  void _odemeEkleDiyalogu(BuildContext context, Box box, Kisi guncelKisi, TicariIslem anaIslem) {
    final TextEditingController tutarController = TextEditingController();
    final TextEditingController aciklamaController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final double kalan = anaIslem.kalanTutar;
    final bool alacakMi = anaIslem.tur == IslemTuru.alacagimiz || anaIslem.tur == IslemTuru.borcVerildi;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Text(
            alacakMi ? "Tahsilat Al (Para Girişi)" : "Tediye Yap (Para Çıkışı)",
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Toplam Tutar: ₺${formatPara(anaIslem.tutar)}\nKalan Tutar: ₺${formatPara(kalan)}",
                    style: const TextStyle(fontSize: 12, color: AppColors.inactive, height: 1.35, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: tutarController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Ödeme Tutarı (TL)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.primary, size: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Lütfen tutar girin';
                      final temiz = value.replaceAll('.', '');
                      final girilen = double.tryParse(temiz);
                      if (girilen == null || girilen <= 0) return 'Geçersiz tutar girdiniz';
                      if (girilen > kalan) return 'Kalan tutardan fazla ödeme girilemez!';
                      if (girilen >= 1000000000) return 'Tutar 1 Milyar TL altında olmalıdır!';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: aciklamaController,
                    maxLength: 100,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Açıklama (İsteğe Bağlı)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined, color: AppColors.inactive, size: 18),
                    ),
                    validator: (value) {
                      if (value != null && value.length > 100) return 'Açıklama 100 karakteri geçemez';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('VAZGEÇ', style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: alacakMi ? AppColors.alacak : AppColors.borc,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final temizTutar = tutarController.text.replaceAll('.', '');
                  final double girilenTutar = double.parse(temizTutar);
                  
                  final yeniOdeme = TicariIslem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    kategori: IslemKategorisi.gunluk,
                    tur: alacakMi ? IslemTuru.odemeAldik : IslemTuru.odemeYaptik,
                    aciklama: aciklamaController.text.trim().isNotEmpty 
                        ? aciklamaController.text.trim() 
                        : "Ürün işlemi ara ödemesi",
                    kayitTarihi: DateTime.now(),
                    tutar: girilenTutar,
                  );

                  anaIslem.bagliOdemeler.add(yeniOdeme);

                  if (anaIslem.kalanTutar <= 0) {
                    anaIslem.kapandiMi = true;
                  }

                  // 🔄 Tahsilat sonrası kapatılan taksitlerin durumlarını otomatik 'gerceklesti' yap
                  if (anaIslem.taksitler != null) {
                    final taksitKapanmaListesi = _hesaplaTaksitKapanmaDurumlari(anaIslem);
                    for (int i = 0; i < anaIslem.taksitler!.length; i++) {
                      if (taksitKapanmaListesi.length > i && taksitKapanmaListesi[i]) {
                        anaIslem.taksitler![i].durum = 'gerceklesti';
                        anaIslem.taksitler![i].odendiMi = true;
                        anaIslem.taksitler![i].odemeTarihi ??= DateTime.now();
                      }
                    }
                  }

                  await box.put(guncelKisi.id, guncelKisi.toMap());

                  final esitlemeServisi = YedekEsitlemeServisi();
                  await esitlemeServisi.yerelZamanDamgasiGuncelle();

                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ödeme kaydedildi. Bulut eşitlemesi başlatıldı...'),
                      backgroundColor: AppColors.success,
                    ),
                  );

                  esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) { return false; });
                }
              },
              child: const Text('ÖDEMEYİ KAYDET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Box defterKutusu = Hive.box('defterKutusu');

    return ValueListenableBuilder(
      valueListenable: defterKutusu.listenable(),
      builder: (context, Box box, _) {
        var hamVeri = box.get(widget.kisi.id);
        
        if (hamVeri == null) {
          return const Center(
            child: Text("Cari kaydı bulunamadı.", style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold)),
          );
        }

        final guncelKisi = Kisi.fromMap(Map<dynamic, dynamic>.from(hamVeri));

        final urunIslemleri = guncelKisi.islemler.where((islem) {
          bool urunIslemiMi = islem.kategori == IslemKategorisi.vadeli || 
                             (islem.stokUrunId != null && islem.stokUrunId!.isNotEmpty);
          if (!urunIslemiMi) return false;
          
          if (widget.mod == UrunIslemModu.musteri) {
            return islem.tur == IslemTuru.alacagimiz || 
                   islem.tur == IslemTuru.borcVerildi || 
                   islem.tur == IslemTuru.odemeAldik;
          } else if (widget.mod == UrunIslemModu.tedarikci) {
            return islem.tur == IslemTuru.borcumuz || 
                   islem.tur == IslemTuru.borcAlindi || 
                   islem.tur == IslemTuru.odemeYaptik;
          }
          return true;
        }).toList();

        urunIslemleri.sort((a, b) {
          final bool aKapandi = a.kapandiMi || a.kalanTutar <= 0;
          final bool bKapandi = b.kapandiMi || b.kalanTutar <= 0;
          
          if (aKapandi != bKapandi) {
            return aKapandi ? 1 : -1;
          }
          return b.kayitTarihi.compareTo(a.kayitTarihi);
        });

        return Column(
          children: [
            // ➕ TURKUAZ RENKTE ZARİF VE SIKIŞTIRILMIŞ İŞLEM BUTONU
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.turkuaz,
                  side: BorderSide(color: AppColors.turkuaz.withValues(alpha: 0.4), width: 1.2),
                  backgroundColor: AppColors.turkuaz.withValues(alpha: 0.05),
                  minimumSize: const Size(double.infinity, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _ticariIslemWizardAc(context, box, guncelKisi),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: Text(
                  widget.mod == UrunIslemModu.tedarikci 
                      ? "Tedarikçiden Ürün Alımı Yap" 
                      : (widget.mod == UrunIslemModu.musteri ? "Müşteriye Ürün Satışı Yap" : "Yeni Ürün İşlemi Yap"), 
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, letterSpacing: 0.3)
                ),
              ),
            ),
            
            Expanded(
              child: urunIslemleri.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 44, color: AppColors.inactive.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(
                              widget.mod == UrunIslemModu.tedarikci 
                                  ? "Kayıtlı Ürün Alımı Yok" 
                                  : (widget.mod == UrunIslemModu.musteri ? "Kayıtlı Ürün Satışı Yok" : "Kayıtlı Ürün İşlemi Yok"),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 80),
                      itemCount: urunIslemleri.length,
                      itemBuilder: (context, index) {
                        final islem = urunIslemleri[index];
                        final bool alacakMi = islem.tur == IslemTuru.alacagimiz || islem.tur == IslemTuru.borcVerildi;
                        final bool kapandiMi = islem.kapandiMi || islem.kalanTutar <= 0;

                        final Color islemRengi = alacakMi ? AppColors.alacak : AppColors.borc;
                        final double odenenTutar = islem.tutar - islem.kalanTutar;
                        final double ilerlemeYuzdesi = islem.tutar > 0 ? (odenenTutar / islem.tutar) : 0.0;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: kapandiMi ? Colors.grey.shade200 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: kapandiMi 
                                  ? Colors.grey.shade400 
                                  : AppColors.inactive.withValues(alpha: 0.15)
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: islemRengi.withValues(alpha: 0.08),
                                  child: Icon(
                                    kapandiMi ? Icons.check_circle_rounded : (alacakMi ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                                    color: islemRengi,
                                    size: 15,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        islem.aciklama.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: kapandiMi ? Colors.grey.shade600 : AppColors.primary,
                                          decoration: kapandiMi ? TextDecoration.lineThrough : null,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      "₺${formatPara(islem.tutar)}",
                                      style: TextStyle(
                                        fontSize: 12.5, 
                                        fontWeight: FontWeight.bold, 
                                        color: kapandiMi ? Colors.grey.shade600 : islemRengi,
                                        decoration: kapandiMi ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      "Kalan: ₺${formatPara(islem.kalanTutar)}  |  Son Vade: ${_tarihFormatla(islem.vadeTarihi)}",
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.inactive, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: ilerlemeYuzdesi,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(islemRengi),
                                        minHeight: 2.5,
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  if (islem.taksitler != null && islem.taksitler!.isNotEmpty) ...[
                                    ...islem.taksitler!.asMap().entries.map((entry) {
                                      final taksitIdx = entry.key;
                                      final idx = taksitIdx + 1;
                                      final taksit = entry.value;

                                      final taksitKapanmaListesi = _hesaplaTaksitKapanmaDurumlari(islem);
                                      final bool taksitKapandi = taksitKapanmaListesi.length > entry.key ? taksitKapanmaListesi[entry.key] : false;
                                      final String taksitDurumu = taksitKapandi ? 'gerceklesti' : (taksit.durum ?? 'bekliyor');

                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: taksitKapandi ? Colors.grey.shade100 : Colors.white.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: taksitKapandi ? Colors.grey.shade300 : AppColors.inactive.withValues(alpha: 0.08),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              "$idx. Vade:", 
                                              style: TextStyle(
                                                fontSize: 10, 
                                                color: taksitKapandi ? Colors.grey.shade500 : AppColors.inactive,
                                                decoration: taksitKapandi ? TextDecoration.lineThrough : null,
                                              )
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${_tarihFormatla(taksit.vadeTarihi)}  |  ₺${formatPara(taksit.vadeTutari)}",
                                              style: TextStyle(
                                                fontSize: 10, 
                                                fontWeight: FontWeight.bold, 
                                                color: taksitKapandi ? Colors.grey.shade500 : AppColors.primary,
                                                decoration: taksitKapandi ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            const Spacer(),
                                            // 🌟 Simgesel Mikro Butonlar (👍, 👎, ⏳) & Kilit Göstergesi
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: taksitKapandi 
                                                      ? null 
                                                      : () => _taksitDurumGuncelle(box, guncelKisi, islem, taksitIdx, 'gerceklesti', taksitKapandi),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: taksitDurumu == 'gerceklesti' ? AppColors.success.withValues(alpha: 0.2) : Colors.transparent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.thumb_up_alt_rounded,
                                                      size: 13,
                                                      color: taksitDurumu == 'gerceklesti' ? AppColors.success : AppColors.inactive.withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6), // 🟢 Butonlar arası boşluk
                                                InkWell(
                                                  onTap: taksitKapandi 
                                                      ? null 
                                                      : () => _taksitDurumGuncelle(box, guncelKisi, islem, taksitIdx, 'gerceklesmedi', taksitKapandi),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: taksitDurumu == 'gerceklesmedi' ? AppColors.error.withValues(alpha: 0.2) : Colors.transparent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.thumb_down_alt_rounded,
                                                      size: 13,
                                                      color: taksitDurumu == 'gerceklesmedi' ? AppColors.error : AppColors.inactive.withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6), // 🟢 Butonlar arası boşluk
                                                InkWell(
                                                  onTap: taksitKapandi 
                                                      ? null 
                                                      : () => _taksitDurumGuncelle(box, guncelKisi, islem, taksitIdx, 'bekliyor', taksitKapandi),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: taksitDurumu == 'bekliyor' ? Colors.orange.withValues(alpha: 0.2) : Colors.transparent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.hourglass_empty_rounded,
                                                      size: 13,
                                                      color: taksitDurumu == 'bekliyor' ? Colors.orange : AppColors.inactive.withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                                ),

                                                // 🟢 Butonlar grubu ile yanındaki mesaj/kilit ikonu arasında geniş boşluk
                                                const SizedBox(width: 12),

                                                if (taksitKapandi) ...[
                                                  const Icon(
                                                    Icons.lock_outline_rounded,
                                                    size: 13,
                                                    color: AppColors.inactive,
                                                  ),
                                                ] else if (taksitDurumu == 'gerceklesmedi') ...[
                                                  InkWell(
                                                    onTap: () => _taksitMesajGonder(guncelKisi, taksit, alacakMi),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(3),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.turkuaz.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Icon(
                                                        Icons.send_rounded,
                                                        size: 11,
                                                        color: AppColors.turkuaz,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(indent: 12, endIndent: 12, height: 12, thickness: 0.5),
                                  ],
                                  
                                  if (islem.bagliOdemeler.isNotEmpty)
                                    ...islem.bagliOdemeler.map((odeme) {
                                      return ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                        leading: const Icon(Icons.subdirectory_arrow_right_rounded, size: 13, color: AppColors.inactive),
                                        title: Text(odeme.aciklama, style: const TextStyle(fontSize: 10.5, color: AppColors.primary)),
                                        subtitle: Text(_tarihFormatla(odeme.kayitTarihi), style: const TextStyle(fontSize: 8.5, color: AppColors.inactive)),
                                        trailing: Text("₺${formatPara(odeme.tutar)}", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: islemRengi)),
                                      );
                                    }),

                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 18),
                                          onPressed: () => _islemKaliciSil(context, box, guncelKisi, islem),
                                        ),
                                        const Spacer(),
                                        if (!kapandiMi) ...[
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: islemRengi,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            ),
                                            onPressed: () => _odemeEkleDiyalogu(context, box, guncelKisi, islem),
                                            child: Text(alacakMi ? "TAHSİLAT EKLE" : "ÖDEME EKLE", style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ] else ...[
                                          Text(
                                            alacakMi ? "TAMAMLANAN SATIŞ" : "TAMAMLANAN ALIM", 
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.inactive),
                                          ),
                                        ]
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
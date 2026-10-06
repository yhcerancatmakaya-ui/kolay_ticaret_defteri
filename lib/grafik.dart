/* 
  📊 İSTATİSTİK VE RAPORLAR MODÜLÜ (GÖRSEL VE ZARİF TASARIM)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'tema_renk_paleti.dart';
import 'modeller.dart';

enum KisiFiltreTuru { tumu, musteriler, tedarikciler, ortaklar, tekKisi }

enum IslemFiltreTuru {
  vadeliTumu,
  vadeliSatis,
  vadeliAlis,
  pesinTumu,
  pesinSatis,
  pesinAlis,
  kasaNet,
  kasaGiris,
  kasaCikis,
}

enum ZamanAraligi {
  son6Ay,
  son1Yil,
  son2Yil,
  tumGecmis,
  sonraki6Ay,
  sonraki1Yil,
  sonraki2Yil,
  gelecekTumu,
}

enum GrafikTuru { sutun, cizgi }

class IstatistikVeRaporEkrani extends StatefulWidget {
  const IstatistikVeRaporEkrani({super.key});

  @override
  State<IstatistikVeRaporEkrani> createState() => _IstatistikVeRaporEkraniState();
}

class _IstatistikVeRaporEkraniState extends State<IstatistikVeRaporEkrani> {
  KisiFiltreTuru seciliKisiFiltreTuru = KisiFiltreTuru.tumu;
  String? seciliTekKisiId;
  IslemFiltreTuru seciliIslemFiltreTuru = IslemFiltreTuru.vadeliTumu;
  ZamanAraligi seciliZamanAraligi = ZamanAraligi.son6Ay;
  GrafikTuru seciliGrafikTuru = GrafikTuru.sutun;

  List<Kisi> tumKisiler = [];
  bool yukleniyor = true;

  Map<String, Map<String, double>> grafikVerileri = {};
  List<String> siraliAylar = [];

  @override
  void initState() {
    super.initState();
    _verileriYukleVeHesapla();
  }

  void _verileriYukleVeHesapla() {
    final Box kisilerKutusu = Hive.box('defterKutusu');
    List<Kisi> yuklenenKisiler = [];

    for (var rawKisi in kisilerKutusu.values) {
      if (rawKisi != null) {
        yuklenenKisiler.add(Kisi.fromMap(Map<dynamic, dynamic>.from(rawKisi)));
      }
    }

    tumKisiler = yuklenenKisiler;
    _grafikVerileriniOlustur();
  }

  void _grafikVerileriniOlustur() {
    Map<String, Map<String, double>> hesaplananData = {};

    List<Kisi> hedefKisiler = [];
    if (seciliKisiFiltreTuru == KisiFiltreTuru.tumu) {
      hedefKisiler = tumKisiler;
    } else if (seciliKisiFiltreTuru == KisiFiltreTuru.musteriler) {
      hedefKisiler = tumKisiler.where((k) => k.isMusteri).toList();
    } else if (seciliKisiFiltreTuru == KisiFiltreTuru.tedarikciler) {
      hedefKisiler = tumKisiler.where((k) => k.isTedarikci).toList();
    } else if (seciliKisiFiltreTuru == KisiFiltreTuru.ortaklar) {
      hedefKisiler = tumKisiler.where((k) => k.isOrtak).toList();
    } else if (seciliKisiFiltreTuru == KisiFiltreTuru.tekKisi && seciliTekKisiId != null) {
      hedefKisiler = tumKisiler.where((k) => k.id == seciliTekKisiId).toList();
    }

    DateTime simdi = DateTime.now();

    for (var kisi in hedefKisiler) {
      for (var islem in kisi.islemler) {
        if (islem.kategori == IslemKategorisi.vadeli) {
          if (islem.taksitler != null && islem.taksitler!.isNotEmpty) {
            for (var taksit in islem.taksitler!) {
              _taksitVeyaIslemEkle(
                hesaplananData: hesaplananData,
                tarih: taksit.vadeTarihi,
                tutar: taksit.vadeTutari,
                kapandiMi: taksit.odendiMi || islem.kapandiMi,
                tur: islem.tur,
                simdi: simdi,
                odenmediMi: islem.odenmediMi,
              );
            }
          } else {
            _taksitVeyaIslemEkle(
              hesaplananData: hesaplananData,
              tarih: islem.vadeTarihi,
              tutar: islem.tutar,
              kapandiMi: islem.kapandiMi,
              tur: islem.tur,
              simdi: simdi,
              odenmediMi: islem.odenmediMi,
            );
          }
        } else {
          _taksitVeyaIslemEkle(
            hesaplananData: hesaplananData,
            tarih: islem.kayitTarihi,
            tutar: islem.tutar,
            kapandiMi: islem.kapandiMi,
            tur: islem.tur,
            simdi: simdi,
            odenmediMi: islem.odenmediMi,
          );
        }
      }
    }

    List<String> aylar = hesaplananData.keys.toList()..sort();

    setState(() {
      grafikVerileri = hesaplananData;
      siraliAylar = aylar;
      yukleniyor = false;
    });
  }

  void _taksitVeyaIslemEkle({
    required Map<String, Map<String, double>> hesaplananData,
    required DateTime tarih,
    required double tutar,
    required bool kapandiMi,
    required IslemTuru tur,
    required DateTime simdi,
    required bool odenmediMi,
  }) {
    bool gelecekZamanMi = _zamanGelecekMi(seciliZamanAraligi);
    if (gelecekZamanMi && kapandiMi) {
      return;
    }

    if (!_tarihAraliktaMi(tarih, seciliZamanAraligi, simdi)) {
      return;
    }

    String ayKey = "${tarih.year}-${tarih.month.toString().padLeft(2, '0')}";
    hesaplananData.putIfAbsent(ayKey, () => {"seri1": 0.0, "seri2": 0.0, "gecikmis": 0.0});

    bool gecikmisMi = (tarih.isBefore(simdi) && !kapandiMi) || odenmediMi;

    bool vadeliIslemFiltresi = seciliIslemFiltreTuru == IslemFiltreTuru.vadeliTumu ||
        seciliIslemFiltreTuru == IslemFiltreTuru.vadeliSatis ||
        seciliIslemFiltreTuru == IslemFiltreTuru.vadeliAlis;

    if (vadeliIslemFiltresi && gecikmisMi) {
      hesaplananData[ayKey]!["gecikmis"] = (hesaplananData[ayKey]!["gecikmis"] ?? 0) + tutar;
    }

    switch (seciliIslemFiltreTuru) {
      case IslemFiltreTuru.vadeliTumu:
        if (tur == IslemTuru.alacagimiz) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) + tutar;
        } else if (tur == IslemTuru.borcumuz) {
          hesaplananData[ayKey]!["seri2"] = (hesaplananData[ayKey]!["seri2"] ?? 0) + tutar;
        }
        break;
      case IslemFiltreTuru.vadeliSatis:
        if (tur == IslemTuru.alacagimiz) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) + tutar;
        }
        break;
      case IslemFiltreTuru.vadeliAlis:
        if (tur == IslemTuru.borcumuz) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) + tutar;
        }
        break;
      case IslemFiltreTuru.pesinTumu:
        if (tur == IslemTuru.odemeAldik || tur == IslemTuru.paraAlindi) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) + tutar;
        } else if (tur == IslemTuru.odemeYaptik || tur == IslemTuru.paraVerildi) {
          hesaplananData[ayKey]!["seri2"] = (hesaplananData[ayKey]!["seri2"] ?? 0) + tutar;
        }
        break;
      case IslemFiltreTuru.pesinSatis:
      case IslemFiltreTuru.kasaGiris:
        if (tur == IslemTuru.odemeAldik || tur == IslemTuru.paraAlindi) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) + tutar;
        }
        break;
      case IslemFiltreTuru.pesinAlis:
      case IslemFiltreTuru.kasaCikis:
        if (tur == IslemTuru.odemeYaptik || tur == IslemTuru.paraVerildi) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) + tutar;
        }
        break;
      case IslemFiltreTuru.kasaNet:
        if (tur == IslemTuru.odemeAldik || tur == IslemTuru.paraAlindi) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) + tutar;
        } else if (tur == IslemTuru.odemeYaptik || tur == IslemTuru.paraVerildi) {
          hesaplananData[ayKey]!["seri1"] = (hesaplananData[ayKey]!["seri1"] ?? 0) - tutar;
        }
        break;
    }
  }

  bool _zamanGelecekMi(ZamanAraligi aralik) {
    return aralik == ZamanAraligi.sonraki6Ay ||
        aralik == ZamanAraligi.sonraki1Yil ||
        aralik == ZamanAraligi.sonraki2Yil ||
        aralik == ZamanAraligi.gelecekTumu;
  }

  bool _tarihAraliktaMi(DateTime tarih, ZamanAraligi aralik, DateTime simdi) {
    switch (aralik) {
      case ZamanAraligi.son6Ay:
        return tarih.isAfter(simdi.subtract(const Duration(days: 180))) && tarih.isBefore(simdi.add(const Duration(days: 1)));
      case ZamanAraligi.son1Yil:
        return tarih.isAfter(simdi.subtract(const Duration(days: 365))) && tarih.isBefore(simdi.add(const Duration(days: 1)));
      case ZamanAraligi.son2Yil:
        return tarih.isAfter(simdi.subtract(const Duration(days: 730))) && tarih.isBefore(simdi.add(const Duration(days: 1)));
      case ZamanAraligi.tumGecmis:
        return tarih.isBefore(simdi.add(const Duration(days: 1)));
      case ZamanAraligi.sonraki6Ay:
        return tarih.isAfter(simdi) && tarih.isBefore(simdi.add(const Duration(days: 180)));
      case ZamanAraligi.sonraki1Yil:
        return tarih.isAfter(simdi) && tarih.isBefore(simdi.add(const Duration(days: 365)));
      case ZamanAraligi.sonraki2Yil:
        return tarih.isAfter(simdi) && tarih.isBefore(simdi.add(const Duration(days: 730)));
      case ZamanAraligi.gelecekTumu:
        return tarih.isAfter(simdi);
    }
  }

  void _tamEkranGoster() {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            "Detaylı Grafik İnceleme",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.primary),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _LejantPaneli(islemFiltreTuru: seciliIslemFiltreTuru),
                const SizedBox(height: 20),
                Expanded(
                  child: _GrafikGosterici(
                    grafikVerileri: grafikVerileri,
                    siraliAylar: siraliAylar,
                    grafikTuru: seciliGrafikTuru,
                    islemFiltreTuru: seciliIslemFiltreTuru,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownSadeTasarim(String etiket) {
    return InputDecoration(
      labelText: etiket,
      labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: AppColors.backgroundDarker.withValues(alpha: 0.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.alacak.withValues(alpha: 0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (yukleniyor) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.alacak, strokeWidth: 2.5),
      );
    }

    bool gelecekZamanSecili = _zamanGelecekMi(seciliZamanAraligi);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎨 FİLTRE PANELİ KARTI
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    // 1. Kişi Kapsamı
                    DropdownButtonFormField<KisiFiltreTuru>(
                      initialValue: seciliKisiFiltreTuru,
                      style: const TextStyle(fontSize: 13, color: AppColors.textOnBackground, fontWeight: FontWeight.w500),
                      decoration: _dropdownSadeTasarim("Kişi Kapsamı"),
                      items: const [
                        DropdownMenuItem(value: KisiFiltreTuru.tumu, child: Text("Tüm Kayıtlı Kişiler")),
                        DropdownMenuItem(value: KisiFiltreTuru.musteriler, child: Text("Müşteriler")),
                        DropdownMenuItem(value: KisiFiltreTuru.tedarikciler, child: Text("Tedarikçiler")),
                        DropdownMenuItem(value: KisiFiltreTuru.ortaklar, child: Text("Ortaklar")),
                        DropdownMenuItem(value: KisiFiltreTuru.tekKisi, child: Text("Tek Kişi Seç")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            seciliKisiFiltreTuru = val;
                            if (val != KisiFiltreTuru.tekKisi) seciliTekKisiId = null;
                          });
                          _grafikVerileriniOlustur();
                        }
                      },
                    ),

                    if (seciliKisiFiltreTuru == KisiFiltreTuru.tekKisi) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: seciliTekKisiId,
                        style: const TextStyle(fontSize: 13, color: AppColors.textOnBackground, fontWeight: FontWeight.w500),
                        hint: const Text("Kişi Rehberinden Seçiniz", style: TextStyle(fontSize: 12)),
                        decoration: _dropdownSadeTasarim("Seçilen Kişi"),
                        items: tumKisiler
                            .map((k) => DropdownMenuItem(value: k.id, child: Text(k.isim)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            seciliTekKisiId = val;
                          });
                          _grafikVerileriniOlustur();
                        },
                      ),
                    ],
                    const SizedBox(height: 10),

                    // 2. İşlem Odak Seçimi
                    DropdownButtonFormField<IslemFiltreTuru>(
                      initialValue: seciliIslemFiltreTuru,
                      style: const TextStyle(fontSize: 13, color: AppColors.textOnBackground, fontWeight: FontWeight.w500),
                      decoration: _dropdownSadeTasarim("İşlem Odak Türü"),
                      items: const [
                        DropdownMenuItem(value: IslemFiltreTuru.vadeliTumu, child: Text("Vadeli İşlemler (Alışlar & Satışlar)")),
                        DropdownMenuItem(value: IslemFiltreTuru.vadeliSatis, child: Text("Vadeli Satışlar")),
                        DropdownMenuItem(value: IslemFiltreTuru.vadeliAlis, child: Text("Vadeli Alışlar")),
                        DropdownMenuItem(value: IslemFiltreTuru.pesinTumu, child: Text("Peşin İşlemler (Alışlar & Satışlar)")),
                        DropdownMenuItem(value: IslemFiltreTuru.pesinSatis, child: Text("Peşin Satışlar")),
                        DropdownMenuItem(value: IslemFiltreTuru.pesinAlis, child: Text("Peşin Alışlar")),
                        DropdownMenuItem(value: IslemFiltreTuru.kasaNet, child: Text("Kasalar Net Bakiyeleri")),
                        DropdownMenuItem(value: IslemFiltreTuru.kasaGiris, child: Text("Kasalara Para Girişleri")),
                        DropdownMenuItem(value: IslemFiltreTuru.kasaCikis, child: Text("Kasalardan Para Çıkışları")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            seciliIslemFiltreTuru = val;
                          });
                          _grafikVerileriniOlustur();
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // 3. Zaman Aralığı ve Butonlar
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ZamanAraligi>(
                            initialValue: seciliZamanAraligi,
                            style: const TextStyle(fontSize: 12, color: AppColors.textOnBackground, fontWeight: FontWeight.w500),
                            decoration: _dropdownSadeTasarim("Zaman Aralığı"),
                            items: const [
                              DropdownMenuItem(value: ZamanAraligi.son6Ay, child: Text("Son 6 Ay")),
                              DropdownMenuItem(value: ZamanAraligi.son1Yil, child: Text("Son 1 Yıl")),
                              DropdownMenuItem(value: ZamanAraligi.son2Yil, child: Text("Son 2 Yıl")),
                              DropdownMenuItem(value: ZamanAraligi.tumGecmis, child: Text("Tüm Geçmiş")),
                              DropdownMenuItem(value: ZamanAraligi.sonraki6Ay, child: Text("Sonraki 6 Ay")),
                              DropdownMenuItem(value: ZamanAraligi.sonraki1Yil, child: Text("Sonraki 1 Yıl")),
                              DropdownMenuItem(value: ZamanAraligi.sonraki2Yil, child: Text("Sonraki 2 Yıl")),
                              DropdownMenuItem(value: ZamanAraligi.gelecekTumu, child: Text("Tüm Gelecek")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  seciliZamanAraligi = val;
                                });
                                _grafikVerileriniOlustur();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundDarker.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
                          ),
                          child: ToggleButtons(
                            isSelected: [
                              seciliGrafikTuru == GrafikTuru.sutun,
                              seciliGrafikTuru == GrafikTuru.cizgi,
                            ],
                            fillColor: AppColors.primary,
                            selectedColor: Colors.white,
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            renderBorder: false,
                            constraints: const BoxConstraints(minHeight: 38, minWidth: 38),
                            onPressed: (index) {
                              setState(() {
                                seciliGrafikTuru = index == 0 ? GrafikTuru.sutun : GrafikTuru.cizgi;
                              });
                            },
                            children: const [
                              Icon(Icons.bar_chart_rounded, size: 18),
                              Icon(Icons.show_chart_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (gelecekZamanSecili)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.alacak.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.alacak.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 15, color: AppColors.alacak),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Gelecek projeksiyonunda erken ödenip kapanmış işlemler hariç tutulmuştur.",
                        style: TextStyle(fontSize: 11, color: AppColors.alacak, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // 📊 GRAFİK BAŞLIĞI VE LEJANT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "AYLIK ANALİZ VE AKIŞ GRAFİĞİ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                InkWell(
                  onTap: _tamEkranGoster,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: const [
                        Text("Büyüt", style: TextStyle(fontSize: 11, color: AppColors.alacak, fontWeight: FontWeight.bold)),
                        SizedBox(width: 2),
                        Icon(Icons.open_in_full_rounded, size: 14, color: AppColors.alacak),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _LejantPaneli(islemFiltreTuru: seciliIslemFiltreTuru),

            const SizedBox(height: 16),

            // 🎨 GRAFİK ÇERÇEVESİ
            Container(
              height: 290,
              padding: const EdgeInsets.only(right: 14, left: 4, top: 16, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.05)),
              ),
              child: _GrafikGosterici(
                grafikVerileri: grafikVerileri,
                siraliAylar: siraliAylar,
                grafikTuru: seciliGrafikTuru,
                islemFiltreTuru: seciliIslemFiltreTuru,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🏷️ RENK LEJANDI (AÇIKLAMA PANELİ)
class _LejantPaneli extends StatelessWidget {
  final IslemFiltreTuru islemFiltreTuru;

  const _LejantPaneli({required this.islemFiltreTuru});

  @override
  Widget build(BuildContext context) {
    bool ciftSeri = islemFiltreTuru == IslemFiltreTuru.vadeliTumu || islemFiltreTuru == IslemFiltreTuru.pesinTumu;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LejantElemani(
          renk: AppColors.alacak,
          metin: ciftSeri
              ? (islemFiltreTuru == IslemFiltreTuru.vadeliTumu ? "Satış / Alacak" : "Giriş / Tahsilat")
              : "İşlem Tutarı",
        ),
        if (ciftSeri)
          _LejantElemani(
            renk: AppColors.borc,
            metin: islemFiltreTuru == IslemFiltreTuru.vadeliTumu ? "Alış / Borç" : "Çıkış / Ödeme",
          ),
        if (islemFiltreTuru == IslemFiltreTuru.vadeliTumu ||
            islemFiltreTuru == IslemFiltreTuru.vadeliSatis ||
            islemFiltreTuru == IslemFiltreTuru.vadeliAlis)
          const _LejantElemani(
            renk: AppColors.riskli,
            metin: "Vadesi Geçmiş / Riskli",
          ),
      ],
    );
  }
}

class _LejantElemani extends StatelessWidget {
  final Color renk;
  final String metin;

  const _LejantElemani({required this.renk, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          metin,
          style: const TextStyle(fontSize: 11, color: AppColors.textOnBackground, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// 📈 FL_CHART RENDERER (SÜTUN / ÇİZGİ)
class _GrafikGosterici extends StatelessWidget {
  final Map<String, Map<String, double>> grafikVerileri;
  final List<String> siraliAylar;
  final GrafikTuru grafikTuru;
  final IslemFiltreTuru islemFiltreTuru;

  const _GrafikGosterici({
    required this.grafikVerileri,
    required this.siraliAylar,
    required this.grafikTuru,
    required this.islemFiltreTuru,
  });

  @override
  Widget build(BuildContext context) {
    if (siraliAylar.isEmpty) {
      return const Center(
        child: Text(
          "Seçilen kriterlere uygun grafik verisi bulunamadı.",
          style: TextStyle(color: AppColors.inactive, fontSize: 12),
        ),
      );
    }

    if (grafikTuru == GrafikTuru.sutun) {
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppColors.primary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "₺${rod.toY.toStringAsFixed(2)}",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.primary.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < siraliAylar.length) {
                    List<String> parcalar = siraliAylar[index].split('-');
                    String etiket = "${parcalar[1]}/${parcalar[0].substring(2)}";
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        etiket,
                        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(siraliAylar.length, (index) {
            String ay = siraliAylar[index];
            double s1 = grafikVerileri[ay]?["seri1"] ?? 0.0;
            double s2 = grafikVerileri[ay]?["seri2"] ?? 0.0;
            double gecikmis = grafikVerileri[ay]?["gecikmis"] ?? 0.0;

            List<BarChartRodData> rods = [
              BarChartRodData(
                toY: s1,
                color: AppColors.alacak,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ];

            if (s2 > 0) {
              rods.add(
                BarChartRodData(
                  toY: s2,
                  color: AppColors.borc,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              );
            }

            if (gecikmis > 0) {
              rods.add(
                BarChartRodData(
                  toY: gecikmis,
                  color: AppColors.riskli,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              );
            }

            return BarChartGroupData(x: index, barRods: rods);
          }),
        ),
      );
    } else {
      List<FlSpot> spotSeri1 = [];
      List<FlSpot> spotSeri2 = [];

      for (int i = 0; i < siraliAylar.length; i++) {
        String ay = siraliAylar[i];
        spotSeri1.add(FlSpot(i.toDouble(), grafikVerileri[ay]?["seri1"] ?? 0.0));
        spotSeri2.add(FlSpot(i.toDouble(), grafikVerileri[ay]?["seri2"] ?? 0.0));
      }

      bool ciftSeri = islemFiltreTuru == IslemFiltreTuru.vadeliTumu || islemFiltreTuru == IslemFiltreTuru.pesinTumu;

      return LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => AppColors.primary,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    "₺${spot.y.toStringAsFixed(2)}",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.primary.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < siraliAylar.length) {
                    List<String> parcalar = siraliAylar[index].split('-');
                    String etiket = "${parcalar[1]}/${parcalar[0].substring(2)}";
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        etiket,
                        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spotSeri1,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.alacak,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppColors.alacak,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.alacak.withValues(alpha: 0.08),
              ),
            ),
            if (ciftSeri)
              LineChartBarData(
                spots: spotSeri2,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.borc,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppColors.borc,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.borc.withValues(alpha: 0.08),
                ),
              ),
          ],
        ),
      );
    }
  }
}
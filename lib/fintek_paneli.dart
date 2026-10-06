/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'modeller.dart';
import 'tema_renk_paleti.dart';
import 'yardimcilar.dart';

class FintekGecisPaneli extends StatefulWidget {
  const FintekGecisPaneli({super.key});

  @override
  State<FintekGecisPaneli> createState() => _FintekGecisPaneliState();
}

class _FintekGecisPaneliState extends State<FintekGecisPaneli> {
  late final Box defterKutusu;
  final PageController _pageController = PageController();
  int _aktifSayfaIndex = 0;

  @override
  void initState() {
    super.initState();
    defterKutusu = Hive.box('defterKutusu');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Karışık işlem türlerini normalize eden yardımcı fonksiyon
  IslemTuru _normallesmisTur(IslemTuru gelenTur) {
    switch (gelenTur) {
      case IslemTuru.paraAlindi: return IslemTuru.odemeAldik;
      case IslemTuru.paraVerildi: return IslemTuru.odemeYaptik;
      case IslemTuru.borcVerildi: return IslemTuru.alacagimiz;
      case IslemTuru.borcAlindi: return IslemTuru.borcumuz;
      default: return gelenTur;
    }
  }

  /// Tarih karşılaştırmalarında saat ve milisaniye kaymalarını engelleyen hassas metotlar
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isBeforeDay(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return aDate.isBefore(bDate);
  }

  bool _isAfterDay(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return aDate.isAfter(bDate);
  }

  /// Taksitlerin kronolojik olarak kapatılma durumunu hesaplayan metot
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

  /// Tüm kişilerin kayıtlı ticari işlemlerini kronolojik tersten süzen metot
  List<Map<String, dynamic>> _toplaSonHareketler() {
    final List<Map<String, dynamic>> hareketler = [];

    for (var key in defterKutusu.keys) {
      final hamVeri = defterKutusu.get(key);
      if (hamVeri != null) {
        try {
          final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(hamVeri));
          for (var islem in kisi.islemler) {
            hareketler.add({
              'kisi': kisi,
              'islem': islem,
              'tarih': islem.kayitTarihi,
              'tutar': islem.tutar,
              'aciklama': islem.aciklama,
              'tur': islem.tur,
            });
          }
        } catch (e) {
          debugPrint("Son hareketler süzme hatası: $e");
        }
      }
    }

    hareketler.sort((a, b) => (b['tarih'] as DateTime).compareTo(a['tarih'] as DateTime));
    return hareketler;
  }

  /// Kasaların fiili para hareketlerini toplayan güncellenmiş metot
  Map<String, double> _hesaplaGunlukKasaRaporu() {
    double ortakKasaGiris = 0.0;
    double ortakKasaCikis = 0.0;
    
    double tumGirisler = 0.0;
    double tumCikislar = 0.0;

    for (var key in defterKutusu.keys) {
      final hamVeri = defterKutusu.get(key);
      if (hamVeri != null) {
        try {
          final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(hamVeri));
          final bool isOrtak = kisi.isOrtak;

          for (var islem in kisi.islemler) {
            final IslemTuru nTur = _normallesmisTur(islem.tur);

            if (islem.kategori == IslemKategorisi.gunluk) {
              final bool isPlan = islem.aciklama.startsWith("[PLAN] ");
              if (!isPlan) {
                // Tüm kişilerin giriş/çıkışları (Net Kasa hesabı için)
                if (nTur == IslemTuru.odemeAldik) {
                  tumGirisler += islem.tutar;
                } else if (nTur == IslemTuru.odemeYaptik) {
                  tumCikislar += islem.tutar;
                }

                // Ortak sıfatı olan kişilerin fiili kasa hareketleri
                if (isOrtak) {
                  if (nTur == IslemTuru.odemeAldik) {
                    ortakKasaGiris += islem.tutar;
                  } else if (nTur == IslemTuru.odemeYaptik) {
                    ortakKasaCikis += islem.tutar;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint("Kasa süzme hatası: $e");
        }
      }
    }

    final double netKasaNakit = tumGirisler - tumCikislar;

    return {
      'ortakKasaGiris': ortakKasaGiris,
      'ortakKasaCikis': ortakKasaCikis,
      'netKasaNakit': netKasaNakit,
    };
  }

  /// Vadeli hesapların para durumunu hesaplayan metot
  Map<String, double> _hesaplaVadeliParaDurumu() {
    double musteriPesinSatis = 0.0;
    double musteriVadeliSatis = 0.0;
    double tedarikciPesinAlis = 0.0;
    double tedarikciVadeliAlis = 0.0;

    for (var key in defterKutusu.keys) {
      final hamVeri = defterKutusu.get(key);
      if (hamVeri != null) {
        try {
          final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(hamVeri));

          for (var islem in kisi.islemler) {
            final IslemTuru nTur = _normallesmisTur(islem.tur);
            final bool isPlan = islem.aciklama.startsWith("[PLAN] ");
            if (isPlan) continue;

            // MÜŞTERİ HESAPLAMALARI
            if (kisi.isMusteri) {
              if (nTur == IslemTuru.odemeAldik || nTur == IslemTuru.alacagimiz) {
                if (islem.kategori == IslemKategorisi.gunluk) {
                  musteriPesinSatis += islem.tutar;
                } else if (islem.kategori == IslemKategorisi.vadeli) {
                  musteriVadeliSatis += islem.tutar;
                }
              }
            }

            // TEDARİKÇİ HESAPLAMALARI
            if (kisi.isTedarikci) {
              if (nTur == IslemTuru.odemeYaptik || nTur == IslemTuru.borcumuz) {
                if (islem.kategori == IslemKategorisi.gunluk) {
                  tedarikciPesinAlis += islem.tutar;
                } else if (islem.kategori == IslemKategorisi.vadeli) {
                  tedarikciVadeliAlis += islem.tutar;
                }
              }
            }
          }
        } catch (e) {
          debugPrint("Vadeli bakiye süzme hatası: $e");
        }
      }
    }

    return {
      'musteriPesinSatis': musteriPesinSatis,
      'musteriVadeliSatis': musteriVadeliSatis,
      'tedarikciPesinAlis': tedarikciPesinAlis,
      'tedarikciVadeliAlis': tedarikciVadeliAlis,
    };
  }

  /// Sadece planlı olan ve bekleyen tahmini nakit girdilerini süzen metot
  List<Map<String, dynamic>> _toplaOdemePlanlari() {
    final List<Map<String, dynamic>> planlar = [];
    
    for (var key in defterKutusu.keys) {
      final hamVeri = defterKutusu.get(key);
      if (hamVeri != null) {
        try {
          final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(hamVeri));
          for (var islem in kisi.islemler) {
            if (islem.kategori == IslemKategorisi.gunluk && 
                islem.aciklama.startsWith("[PLAN] ") &&
                islem.planDurumu == 'bekliyor') {
              planlar.add({
                'kisi': kisi,
                'islem': islem,
                'vadeTarihi': islem.kayitTarihi,
                'tutar': islem.tutar,
                'aciklama': islem.aciklama.replaceFirst("[PLAN] ", ""),
                'tur': islem.tur,
              });
            }
          }
        } catch (_) {}
      }
    }
    
    planlar.sort((a, b) => (a['vadeTarihi'] as DateTime).compareTo(b['vadeTarihi'] as DateTime));
    return planlar;
  }

  /// Vadeli işlemlere ait ödenmemiş aktif taksitleri süzüp sıralayan metot
  List<Map<String, dynamic>> _toplaVadeliTaksitler() {
    final List<Map<String, dynamic>> taksitler = [];
    
    for (var key in defterKutusu.keys) {
      final hamVeri = defterKutusu.get(key);
      if (hamVeri != null) {
        try {
          final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(hamVeri));
          for (var islem in kisi.islemler) {
            if (islem.kategori == IslemKategorisi.vadeli && !islem.kapandiMi) {
              if (islem.taksitler != null) {
                final taksitKapanmaListesi = _hesaplaTaksitKapanmaDurumlari(islem);
                for (int i = 0; i < islem.taksitler!.length; i++) {
                  final bool taksitKapandi = taksitKapanmaListesi.length > i ? taksitKapanmaListesi[i] : false;
                  
                  if (taksitKapandi) continue;

                  final taksit = islem.taksitler![i];
                  taksitler.add({
                    'kisi': kisi,
                    'islem': islem,
                    'vadeTarihi': taksit.vadeTarihi,
                    'tutar': taksit.vadeTutari,
                    'aciklama': "${islem.aciklama.toUpperCase()} (${i + 1}. Taksit)",
                    'tur': islem.tur,
                  });
                }
              }
            }
          }
        } catch (_) {}
      }
    }
    
    taksitler.sort((a, b) => (a['vadeTarihi'] as DateTime).compareTo(b['vadeTarihi'] as DateTime));
    return taksitler;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: defterKutusu.listenable(),
      builder: (context, Box box, _) {
        final Map<String, double> kasaRapor = _hesaplaGunlukKasaRaporu();
        final Map<String, double> vadeliRapor = _hesaplaVadeliParaDurumu();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                ),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _aktifSayfaIndex = index;
                    });
                  },
                  children: [
                    _FloatingPageContainer(child: _sonHareketlerSekmesi()),
                    _FloatingPageContainer(child: _odemePlanlariTakvimiSekmesi()),
                    _FloatingPageContainer(child: _vadeliTaksitlerTakvimiSekmesi()),
                    _FloatingPageContainer(child: _kasalarinDurumuSekmesi(kasaRapor)),
                    _FloatingPageContainer(child: _vadeliHesaplarParaDurumuSekmesi(vadeliRapor)),
                  ],
                ),
              ),
            ),

            SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => _buildIndicatorNode(index)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIndicatorNode(int index) {
    final bool aktif = _aktifSayfaIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: aktif ? 18 : 6,
      decoration: BoxDecoration(
        color: aktif ? AppColors.primary : AppColors.inactive.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  /// 1. SEKME: SON HAREKETLER
  Widget _sonHareketlerSekmesi() {
    final hareketler = _toplaSonHareketler();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        const Center(
          child: Text(
            'SON HAREKETLER', 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Divider(height: 16, thickness: 0.8),

        if (hareketler.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                "Henüz kayıtlı bir ticari hareket bulunmamaktadır.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.inactive, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: hareketler.length,
            itemBuilder: (context, idx) {
              final h = hareketler[idx];
              final Kisi kisi = h['kisi'] as Kisi;
              final DateTime tarih = h['tarih'] as DateTime;
              final IslemTuru tur = _normallesmisTur(h['tur'] as IslemTuru);
              final bool isGiris = tur == IslemTuru.odemeAldik || tur == IslemTuru.alacagimiz;

              final Color renk = isGiris ? AppColors.alacak : AppColors.borc;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.inactive.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isGiris ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: renk,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kisi.isim.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              h['aciklama'] as String,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inactive.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${isGiris ? '+' : '-'}₺${formatPara(h['tutar'] as double)}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: renk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inactive.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// 2. SEKME: PLAN TAKVİMİ
  Widget _odemePlanlariTakvimiSekmesi() {
    final planlar = _toplaOdemePlanlari();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        const Center(
          child: Text(
            'ÖDEME PLANLARI TAKVİMİ', 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Divider(height: 16, thickness: 0.8),

        if (planlar.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                "Kayıtlı bekleyen herhangi bir tahmini ödeme planı bulunmamaktadır.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.inactive, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else ...[
          _buildPlanlarIcerik(planlar),
        ],
      ],
    );
  }

  Widget _buildPlanlarIcerik(List<Map<String, dynamic>> planlar) {
    final DateTime simdi = DateTime.now();
    final DateTime bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final DateTime yaklasikLimit = bugun.add(const Duration(days: 3));

    final List<Map<String, dynamic>> gecikmis = [];
    final List<Map<String, dynamic>> bugunGrubu = [];
    final List<Map<String, dynamic>> yaklasan = [];
    final List<Map<String, dynamic>> uzakta = [];

    for (var p in planlar) {
      final DateTime tDate = p['vadeTarihi'] as DateTime;

      if (_isBeforeDay(tDate, bugun)) {
        gecikmis.add(p);
      } else if (_isSameDay(tDate, bugun)) {
        bugunGrubu.add(p);
      } else if (_isAfterDay(tDate, bugun) && (_isBeforeDay(tDate, yaklasikLimit) || _isSameDay(tDate, yaklasikLimit))) {
        yaklasan.add(p);
      } else {
        uzakta.add(p);
      }
    }

    return Column(
      children: [
        if (gecikmis.isNotEmpty) ...[
          _takvimListesiOlustur("Gecikmiş Ödeme Planları", gecikmis, bugun, yaklasikLimit, const Color(0xFFC2410C), false),
          _zarifCizgi(),
        ],
        if (bugunGrubu.isNotEmpty) ...[
          _takvimListesiOlustur("Bugüne Ait Ödeme Planları", bugunGrubu, bugun, yaklasikLimit, AppColors.alacak, false),
          _zarifCizgi(),
        ],
        if (yaklasan.isNotEmpty) ...[
          _takvimListesiOlustur("Yaklaşan Ödeme Planları", yaklasan, bugun, yaklasikLimit, Colors.indigo, false),
          _zarifCizgi(),
        ],
        if (uzakta.isNotEmpty) ...[
          _takvimListesiOlustur("Daha Uzak Ödeme Planları", uzakta, bugun, yaklasikLimit, AppColors.inactive, false),
        ],
      ],
    );
  }

  /// 3. SEKME: TAKSİT TAKVİMİ
  Widget _vadeliTaksitlerTakvimiSekmesi() {
    final taksitler = _toplaVadeliTaksitler();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        const Center(
          child: Text(
            'VADELİ TAKSİT TAKVİMİ', 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Divider(height: 16, thickness: 0.8),

        if (taksitler.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                "Aktif vadeli sözleşmelerde bekleyen taksit bulunmamaktadır.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.inactive, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else ...[
          _buildTaksitlerIcerik(taksitler),
        ],
      ],
    );
  }

  Widget _buildTaksitlerIcerik(List<Map<String, dynamic>> taksitler) {
    final DateTime simdi = DateTime.now();
    final DateTime bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final DateTime yaklasikLimit = bugun.add(const Duration(days: 3));

    final List<Map<String, dynamic>> gecikmis = [];
    final List<Map<String, dynamic>> bugunGrubu = [];
    final List<Map<String, dynamic>> yaklasan = [];
    final List<Map<String, dynamic>> uzakta = [];

    for (var t in taksitler) {
      final DateTime tDate = t['vadeTarihi'] as DateTime;

      if (_isBeforeDay(tDate, bugun)) {
        gecikmis.add(t);
      } else if (_isSameDay(tDate, bugun)) {
        bugunGrubu.add(t);
      } else if (_isAfterDay(tDate, bugun) && (_isBeforeDay(tDate, yaklasikLimit) || _isSameDay(tDate, yaklasikLimit))) {
        yaklasan.add(t);
      } else {
        uzakta.add(t);
      }
    }

    return Column(
      children: [
        if (gecikmis.isNotEmpty) ...[
          _takvimListesiOlustur("Gecikmiş Taksitler", gecikmis, bugun, yaklasikLimit, const Color(0xFFC2410C), true),
          _zarifCizgi(),
        ],
        if (bugunGrubu.isNotEmpty) ...[
          _takvimListesiOlustur("Bugüne Ait Vadeli Taksitler", bugunGrubu, bugun, yaklasikLimit, AppColors.alacak, true),
          _zarifCizgi(),
        ],
        if (yaklasan.isNotEmpty) ...[
          _takvimListesiOlustur("Yakın Zamana Ait Taksitler", yaklasan, bugun, yaklasikLimit, Colors.indigo, true),
          _zarifCizgi(),
        ],
        if (uzakta.isNotEmpty) ...[
          _takvimListesiOlustur("Daha Uzak Taksitler", uzakta, bugun, yaklasikLimit, AppColors.inactive, true),
        ],
      ],
    );
  }

  Widget _zarifCizgi() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 80,
          height: 1.2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.01),
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Color _hesaplaVurguRengi(Map<String, dynamic> item, DateTime bugun, DateTime yaklasikLimit) {
    final DateTime tDate = item['vadeTarihi'] as DateTime;
    final IslemTuru tur = _normallesmisTur(item['tur'] as IslemTuru);
    final bool isGiris = tur == IslemTuru.paraAlindi || tur == IslemTuru.odemeAldik || tur == IslemTuru.alacagimiz;

    final Color baseColor = isGiris ? AppColors.alacak : Colors.orange;

    if (_isBeforeDay(tDate, bugun)) {
      return isGiris ? const Color(0xFF0F766E) : const Color(0xFFC2410C);
    } else if (_isSameDay(tDate, bugun)) {
      return baseColor;
    } else if (_isAfterDay(tDate, bugun) && (_isBeforeDay(tDate, yaklasikLimit) || _isSameDay(tDate, yaklasikLimit))) {
      return baseColor.withValues(alpha: 0.80);
    } else {
      return baseColor.withValues(alpha: 0.50);
    }
  }

  Widget _takvimListesiOlustur(
    String grupBasligi, 
    List<Map<String, dynamic>> list, 
    DateTime bugun, 
    DateTime yaklasikLimit, 
    Color grupVurguRengi,
    bool isVadeliTaksit,
  ) {
    final bool isBugunGrubu = grupBasligi.toLowerCase().contains("bugün");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10, top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: grupVurguRengi, width: 3)),
            color: grupVurguRengi.withValues(alpha: 0.05),
          ),
          child: Text(
            grupBasligi.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: grupVurguRengi,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, idx) {
            final item = list[idx];
            final DateTime tDate = item['vadeTarihi'] as DateTime;
            final IslemTuru tur = _normallesmisTur(item['tur'] as IslemTuru);
            final bool isGiris = tur == IslemTuru.paraAlindi || tur == IslemTuru.odemeAldik || tur == IslemTuru.alacagimiz;
            
            final Color dinamikRenk = _hesaplaVurguRengi(item, bugun, yaklasikLimit);
            final String aciklama = item['aciklama'] as String;
            final Kisi kisi = item['kisi'] as Kisi;

            final Color kartZemini = isBugunGrubu 
                ? AppColors.alacak.withValues(alpha: 0.03) 
                : Colors.white;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: kartZemini,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isBugunGrubu 
                      ? AppColors.alacak.withValues(alpha: 0.25) 
                      : AppColors.inactive.withValues(alpha: 0.15),
                  width: isBugunGrubu ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: dinamikRenk.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isGiris ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: dinamikRenk,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  kisi.isim.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isBugunGrubu ? FontWeight.w900 : FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVadeliTaksit)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "VADELİ",
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.indigo),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            aciklama,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inactive.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₺${formatPara(item['tutar'] as double)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: dinamikRenk,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${tDate.day.toString().padLeft(2, '0')}.${tDate.month.toString().padLeft(2, '0')}.${tDate.year}",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.inactive.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 4. SEKME: KASALARIN DURUMU
  Widget _kasalarinDurumuSekmesi(Map<String, double> rapor) {
    final double ortakGiris = rapor['ortakKasaGiris'] ?? 0.0;
    final double ortakCikis = rapor['ortakKasaCikis'] ?? 0.0;
    final double netKasaNakit = rapor['netKasaNakit'] ?? 0.0;
    final bool kasaArtidaMi = netKasaNakit >= 0;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        const Center(
          child: Text(
            'KASALARIN DURUMU', 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              color: AppColors.primary,
              letterSpacing: 1.2
            )
          ),
        ),
        const Divider(height: 16, thickness: 0.8),

        // Ortak Kişilerin Hareketleri Kalemleri
        _bakiyeSatiri(
          baslik: 'Ortaklar Kasaya Para Girişleri:', 
          deger: ortakGiris, 
          renk: AppColors.alacak,
          altBilgi: 'Ortak sıfatı olan kişilerden alınan nakit girişleri',
        ),
        const SizedBox(height: 12),
        _bakiyeSatiri(
          baslik: 'Ortaklar Kasadan Para Çıkışları:', 
          deger: ortakCikis, 
          renk: AppColors.borc,
          altBilgi: 'Ortak sıfatı olan kişilere verilen nakit çıkışları',
        ),

        const Divider(height: 24, thickness: 0.8),

        // Net Bakiye Kartı
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kasaArtidaMi 
                ? AppColors.success.withValues(alpha: 0.05)
                : AppColors.borc.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kasaArtidaMi 
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.borc.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              Text(
                kasaArtidaMi ? 'TÜM KİŞİLER NET KASA BAKİYESİ (ARTI)' : 'TÜM KİŞİLER NET KASA BAKİYESİ (EKSİ)',
                style: TextStyle(
                  fontSize: 9, 
                  fontWeight: FontWeight.w900, 
                  color: kasaArtidaMi ? AppColors.success : AppColors.borc,
                  letterSpacing: 1.1
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₺${formatPara(netKasaNakit.abs())}',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w900,
                  color: kasaArtidaMi ? AppColors.success : AppColors.borc,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 5. SEKME: VADELİ HESAPLARIN PARA DURUMU
  Widget _vadeliHesaplarParaDurumuSekmesi(Map<String, double> rapor) {
    final double musteriPesinSatis = rapor['musteriPesinSatis'] ?? 0.0;
    final double musteriVadeliSatis = rapor['musteriVadeliSatis'] ?? 0.0;
    final double tedarikciPesinAlis = rapor['tedarikciPesinAlis'] ?? 0.0;
    final double tedarikciVadeliAlis = rapor['tedarikciVadeliAlis'] ?? 0.0;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        const Center(
          child: Text(
            'ÜRÜN ALIŞ VE SATIŞLARININ PARA DURUMU', 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              color: AppColors.primary,
              letterSpacing: 1.2
            )
          ),
        ),
        const Divider(height: 16, thickness: 0.8),
        
        _bakiyeSatiri(
          baslik: 'Müşterilere Peşin Ürün Satış Tutarları Toplamı:', 
          deger: musteriPesinSatis, 
          renk: AppColors.alacak,
          altBilgi: 'Müşteri sıfatlı kişilerin peşin gerçekleşen ürün satışları',
        ),
        const SizedBox(height: 12),
        _bakiyeSatiri(
          baslik: 'Müşterilere Vadeli Ürün Satış Tutarları Toplamı:', 
          deger: musteriVadeliSatis, 
          renk: AppColors.primary,
          altBilgi: 'Müşteri sıfatlı kişilerin vadeli gerçekleşen ürün satışları',
        ),
        const SizedBox(height: 12),
        _bakiyeSatiri(
          baslik: 'Tedarikçi Peşin Ürün Alış Tutarları Toplamı:', 
          deger: tedarikciPesinAlis, 
          renk: Colors.deepOrange,
          altBilgi: 'Tedarikçi sıfatlı kişilerden peşin yapılan ürün alışları',
        ),
        const SizedBox(height: 12),
        _bakiyeSatiri(
          baslik: 'Tedarikçi Vadeli Ürün Alış Tutarları Toplamı:', 
          deger: tedarikciVadeliAlis, 
          renk: AppColors.borc,
          altBilgi: 'Tedarikçi sıfatlı kişilerden vadeli yapılan ürün alışları',
        ),
      ],
    );
  }

  Widget _bakiyeSatiri({
    required String baslik,
    required double deger,
    required Color renk,
    required String altBilgi,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                baslik, 
                style: const TextStyle(
                  fontSize: 10.5, 
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₺${formatPara(deger)}', 
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: renk)
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          altBilgi,
          style: TextStyle(fontSize: 8.5, color: AppColors.inactive.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}

class _FloatingPageContainer extends StatelessWidget {
  final Widget child;
  const _FloatingPageContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: child,
    );
  }
}
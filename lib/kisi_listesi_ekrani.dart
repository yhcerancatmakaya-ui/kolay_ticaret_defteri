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
import 'kisi_detay_ekrani.dart';
import 'yeni_kisi_ekrani.dart';
import 'modeller.dart';
import 'kisi_duzenle.dart';

class KisiListesiEkrani extends StatefulWidget {
  const KisiListesiEkrani({super.key});

  @override
  State<KisiListesiEkrani> createState() => _KisiListesiEkraniState();
}

class _KisiListesiEkraniState extends State<KisiListesiEkrani> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final YedekEsitlemeServisi _esitlemeServisi = YedekEsitlemeServisi();

  // Seçili kişi (Seçildiğinde sayfa yerine ekran içinde detay render edilecek)
  Kisi? _seciliKisi;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 🇹🇷 Türkçe karakterlere duyarlı alfabetik sıralama algoritması
  int _turkishCompare(String a, String b) {
    const turkishChars = "abcçdefgğhıijklmnoöprsştuüvyez";
    String cleanA = a.toLowerCase();
    String cleanB = b.toLowerCase();
    
    int minLen = cleanA.length < cleanB.length ? cleanA.length : cleanB.length;
    for (int i = 0; i < minLen; i++) {
      int indexA = turkishChars.indexOf(cleanA[i]);
      int indexB = turkishChars.indexOf(cleanB[i]);
      
      if (indexA != -1 && indexB != -1) {
        if (indexA != indexB) return indexA.compareTo(indexB);
      } else {
        if (cleanA[i] != cleanB[i]) return cleanA[i].compareTo(cleanB[i]);
      }
    }
    return cleanA.length.compareTo(cleanB.length);
  }

  /// Belirli bir harfe dokunulduğunda listeyi o harfin başladığı pozisyona kaydırır
  void _scrollToLetter(String letter, List<Kisi> filteredList) {
    int targetIndex = filteredList.indexWhere(
      (kisi) => kisi.isim.isNotEmpty && kisi.isim[0].toUpperCase() == letter
    );
    if (targetIndex != -1) {
      double cardHeight = 90.0; // İki sütunlu yerleşim için optimize edilmiş kart yüksekliği
      double targetOffset = targetIndex * cardHeight;
      
      if (_scrollController.hasClients) {
        if (targetOffset > _scrollController.position.maxScrollExtent) {
          targetOffset = _scrollController.position.maxScrollExtent;
        }
        _scrollController.animateTo(
          targetOffset, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOutCubic
        );
      }
      
      HapticFeedback.lightImpact();
    }
  }

  /// Kullanıcıyı ve tüm geçmişini kalıcı olarak silmeden önce gösterilen onay diyaloğu
  Future<bool?> _kisiSilmeOnayi(BuildContext context, String kisiIsmi) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'DİKKAT! KALICI SİLME', 
                style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          '${kisiIsmi.toUpperCase()} isimli kişiyi ve ona ait TÜM işlem geçmişini, vadeli borçlarını defterden tamamen silmek üzeresiniz.\n\nBu işlem geri alınamaz! Silmek istediğinize emin misiniz?',
          style: const TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('VAZGEÇ', style: TextStyle(color: AppColors.inactive, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('EVET, SİL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _kisiSil(String kisiId, String kisiIsmi) async {
    final onay = await _kisiSilmeOnayi(context, kisiIsmi);
    if (onay == true) {
      final box = Hive.box('defterKutusu');
      await box.delete(kisiId);

      await _esitlemeServisi.yerelZamanDamgasiGuncelle();
      await _esitlemeServisi.yerelVeriyiSessizceYedekle();

      if (_seciliKisi?.id == kisiId) {
        setState(() {
          _seciliKisi = null;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$kisiIsmi başarıyla silindi.'),
            backgroundColor: AppColors.borc,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kişi seçildiyse ekran içinde detay render edilecek
    if (_seciliKisi != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            setState(() {
              _seciliKisi = null;
            });
          }
        },
        child: KisiDetayEkrani(kisi: _seciliKisi),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder(
        valueListenable: Hive.box('defterKutusu').listenable(),
        builder: (context, Box box, _) {
          List<Kisi> tumKisiler = [];

          for (var key in box.keys) {
            final val = box.get(key);
            if (val != null && val is Map) {
              tumKisiler.add(Kisi.fromMap(Map<dynamic, dynamic>.from(val)));
            }
          }

          // Türkçe alfabetik sıralama
          tumKisiler.sort((a, b) => _turkishCompare(a.isim, b.isim));

          // Arama filtreleme
          final query = _searchController.text.trim().toLowerCase();
          List<Kisi> filtrelenmisKisiler = tumKisiler.where((k) {
            final isimMatch = k.isim.toLowerCase().contains(query);
            final telMatch = k.telefon.toLowerCase().contains(query);
            return isimMatch || telMatch;
          }).toList();

          // Sadece listede mevcut kişilerin baş harflerinden oluşan alfabetik küme
          List<String> mevcutHarfler = [];
          for (var kisi in filtrelenmisKisiler) {
            if (kisi.isim.isNotEmpty) {
              String ilkharf = kisi.isim[0].toUpperCase();
              if (!mevcutHarfler.contains(ilkharf)) {
                mevcutHarfler.add(ilkharf);
              }
            }
          }

          return Column(
            children: [
              // ➕ SABİT TAM GENİŞLİKLİ YENİ KİŞİ EKLE BUTONU
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 4.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 38, // 38px sabit yükseklik
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.85),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const YeniKisiEkrani()),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Yeni Kişi Ekle',
                      style: TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w600, 
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),

              // 🔍 ARAMA ÇUBUĞU (Yüksekliği Yeni Kişi Ekle Butonu ile 38px olarak eşitlendi)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: SizedBox(
                  height: 38, // 38px sabit yükseklik
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, color: AppColors.primary),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Kişi adı veya telefon ara...',
                      hintStyle: const TextStyle(color: AppColors.inactive, fontSize: 12.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.inactive),
                              onPressed: () => _searchController.clear(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.inactive.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Expanded(
                child: filtrelenmisKisiler.isEmpty
                    ? _bosListeGoster(query.isNotEmpty)
                    : Row(
                        children: [
                          // Ana Kişi Listesi
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 20, top: 4),
                              itemCount: filtrelenmisKisiler.length,
                              itemBuilder: (context, index) {
                                final kisi = filtrelenmisKisiler[index];
                                return _kisiKartiGoster(kisi);
                              },
                            ),
                          ),

                          // Sağ Taraf Dinamik Harf İndeksi (Sadece Mevcut Kişilerin Baş Harfleri)
                          if (mevcutHarfler.isNotEmpty)
                            Container(
                              width: 24,
                              margin: const EdgeInsets.only(right: 6, bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: mevcutHarfler.map((harf) {
                                    return InkWell(
                                      onTap: () => _scrollToLetter(harf, filtrelenmisKisiler),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Text(
                                          harf,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kisiKartiGoster(Kisi kisi) {
    final String basHarf = kisi.isim.isNotEmpty ? kisi.isim[0].toUpperCase() : '?';

    // Aktif sıfatların etiket listesi
    List<Widget> sifatRozetleri = [];
    if (kisi.isMusteri) {
      sifatRozetleri.add(_sifatEtiketi('Müşteri', AppColors.primary));
    }
    if (kisi.isTedarikci) {
      sifatRozetleri.add(_sifatEtiketi('Tedarikçi', Colors.orange.shade800));
    }
    if (kisi.isOrtak) {
      sifatRozetleri.add(_sifatEtiketi('Ortak', Colors.teal.shade700));
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.inactive.withValues(alpha: 0.15)),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _seciliKisi = kisi;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Butonları ve sol bloğu dikeyde ortalar
            children: [
              // SOL SÜTUN: İsim, Sıfat Rozetleri ve Telefon Numarası
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. SATIR: Avatar + Kişi İsmi
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            basHarf,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kisi.isim,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),

                    // 2. SATIR: Sıfat Rozetleri (Varsa)
                    if (sifatRozetleri.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: sifatRozetleri,
                      ),
                    ],

                    // 3. SATIR: Telefon Numarası (Varsa)
                    if (kisi.telefon.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        kisi.telefon,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.inactive, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // SAĞ SÜTUN: Düzenle & Sil Butonları
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => KisiDuzenleSheet.goster(context, kisi),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _kisiSil(kisi.id, kisi.isim),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(Icons.delete_outline_rounded, color: AppColors.borc, size: 18),
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

  Widget _sifatEtiketi(String metin, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: renk.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        metin,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: renk),
      ),
    );
  }

  Widget _bosListeGoster(bool aramaYapildiMi) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            aramaYapildiMi ? Icons.search_off_rounded : Icons.people_outline_rounded,
            size: 56,
            color: AppColors.inactive.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            aramaYapildiMi ? 'Aranan kriterlere uygun kişi bulunamadı.' : 'Defterinizde henüz kayıtlı kişi yok.',
            style: const TextStyle(color: AppColors.inactive, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
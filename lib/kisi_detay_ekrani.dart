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
import 'urun_islemleri_sekmesi.dart';
import 'kasa_hareketleri_sekmesi.dart';

class KisiDetayEkrani extends StatefulWidget {
  final String? kisiId;
  final Kisi? kisi;

  const KisiDetayEkrani({
    super.key, 
    this.kisiId,
    this.kisi,
  });

  @override
  State<KisiDetayEkrani> createState() => _KisiDetayEkraniState();
}

class _KisiDetayEkraniState extends State<KisiDetayEkrani> with TickerProviderStateMixin {
  TabController? _tabController;
  int _mevcutSekmeSayisi = 0;

  String get _aktifKisiId => widget.kisiId ?? widget.kisi?.id ?? '';

  void _tabControllerGuncelle(int yeniSayi) {
    if (_tabController == null || _mevcutSekmeSayisi != yeniSayi) {
      _mevcutSekmeSayisi = yeniSayi;
      
      final eskiController = _tabController;
      _tabController = TabController(length: yeniSayi, vsync: this);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        eskiController?.dispose();
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _sayfadanCik(BuildContext context) {
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('defterKutusu').listenable(),
      builder: (context, Box box, _) {
        final hamVeri = box.get(_aktifKisiId);
        
        if (hamVeri == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
                onPressed: () => _sayfadanCik(context),
              ),
            ),
            body: const Center(child: Text("Kişi kaydı bulunamadı veya silinmiş.")),
          );
        }

        final Kisi kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(hamVeri));

        final List<Widget> sekmeler = [];
        final List<Widget> sekmeIcerikleri = [];

        // Sekmeler sıkılaştırılmış yatay Row düzeninde oluşturuluyor
        if (kisi.isMusteri) {
          sekmeler.add(const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 16),
                SizedBox(width: 6),
                Text("Müşteri"),
              ],
            ),
          ));
          sekmeIcerikleri.add(UrunIslemleriSekmesi(kisi: kisi, mod: UrunIslemModu.musteri));
        }

        if (kisi.isTedarikci) {
          sekmeler.add(const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 16),
                SizedBox(width: 6),
                Text("Tedarikçi"),
              ],
            ),
          ));
          sekmeIcerikleri.add(UrunIslemleriSekmesi(kisi: kisi, mod: UrunIslemModu.tedarikci));
        }

        if (kisi.isOrtak) {
          sekmeler.add(const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_rounded, size: 16),
                SizedBox(width: 6),
                Text("Ortak"),
              ],
            ),
          ));
          sekmeIcerikleri.add(KasaHareketleriSekmesi(kisi: kisi));
        }

        if (sekmeler.isEmpty) {
          sekmeler.add(const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 16),
                SizedBox(width: 6),
                Text("Cari İşlemleri"),
              ],
            ),
          ));
          sekmeIcerikleri.add(UrunIslemleriSekmesi(kisi: kisi, mod: UrunIslemModu.hepsi));
        }

        _tabControllerGuncelle(sekmeler.length);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
              onPressed: () => _sayfadanCik(context),
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                kisi.isim, 
                style: const TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 14, 
                  color: AppColors.primary, 
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          body: Column(
            children: [
              // Sıkılaştırılmış sekme yüksekliği (38px) ve daraltılmış iç boşluklar
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.inactive.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: AppColors.inactive.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.inactive,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  tabs: sekmeler,
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: sekmeIcerikleri,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
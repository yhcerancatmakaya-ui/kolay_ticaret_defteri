/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'yedek_esitleme_servisi.dart';

enum IslemKategorisi { gunluk, vadeli }

enum IslemTuru {
  borcumuz,      
  alacagimiz,    
  odemeAldik,    
  odemeYaptik,   
  
  paraAlindi,    
  paraVerildi,   
  borcVerildi,   
  borcAlindi     
}

class Taksit {
  final double vadeTutari;
  final DateTime vadeTarihi;
  bool odendiMi;          // 🌟 EKLENDİ: Taksit ödendi mi?
  String? durum;           // 🌟 EKLENDİ: 'bekliyor', 'odendi', 'odenmedi'
  DateTime? odemeTarihi;   // 🌟 EKLENDİ: Ödendiği tarih

  Taksit({
    required this.vadeTutari, 
    required this.vadeTarihi,
    this.odendiMi = false,
    this.durum = 'bekliyor',
    this.odemeTarihi,
    });

  Map<String, dynamic> toMap() => {
    'vadeTutari': vadeTutari,
    'vadeTarihi': vadeTarihi.toIso8601String(),
    'odendiMi': odendiMi,
    'durum': durum,
    'odemeTarihi': odemeTarihi?.toIso8601String(),
  };

  factory Taksit.fromMap(Map<dynamic, dynamic> map) => Taksit(
    vadeTutari: (map['vadeTutari'] as num).toDouble(),
    vadeTarihi: DateTime.parse(map['vadeTarihi'].toString()),
    odendiMi: map['odendiMi'] ?? false,
    durum: map['durum']?.toString() ?? 'bekliyor',
    odemeTarihi: map['odemeTarihi'] != null ? DateTime.parse(map['odemeTarihi'].toString()) : null,
  );
}

class TicariIslem {
  final String id;
  final double tutar;            
  final String aciklama;
  final DateTime kayitTarihi;     
  final DateTime vadeTarihi;      
  final IslemTuru tur;            
  final bool isUzunVadeli;        
  bool kapandiMi;
  
  List<TicariIslem> bagliOdemeler; 

  final IslemKategorisi kategori;
  final double? miktar;
  final int? vadeSayisi;
  final List<Taksit>? taksitler;

  // 📦 STOK VE ÜRÜN DETAY ALANLARI
  final String? stokUrunId;
  final String? urunAdi;
  final double? birimFiyat;
  final bool stoktanDussunMu;

  // Plan ve İlişki yönetimi için alanlar:
  final bool isPlan;
  final String planDurumu; // 'bekliyor', 'gerceklesti', 'gerceklesmedi'
  final String? gerceklesenIslemId;
  final String? bagliIslemId; // Ana işleme veya bağlı işleme referans ID
  
  // ⚖️ ÖDENMEDİ VE HUKUKİ İŞLEM ALANLARI
  bool odenmediMi;
  bool hukukiSurecBaslatildi;
  
  TicariIslem({
    required this.id,
    required this.kategori,
    required this.tur,
    required this.aciklama,
    required this.kayitTarihi,
    this.miktar,
    this.vadeSayisi,
    this.taksitler,
    this.stokUrunId,
    this.urunAdi,
    this.birimFiyat,
    this.stoktanDussunMu = false,
    double? tutar,
    DateTime? vadeTarihi,
    bool? isUzunVadeli,
    this.kapandiMi = false,
    List<TicariIslem>? bagliOdemeler,
    this.isPlan = false,
    this.planDurumu = 'bekliyor',
    this.gerceklesenIslemId,
    this.bagliIslemId,
    this.odenmediMi = false,
    this.hukukiSurecBaslatildi = false,
  })  : tutar = tutar ?? miktar ?? (taksitler != null ? taksitler.fold(0.0, (sum, t) => sum + t.vadeTutari) : 0.0),
        vadeTarihi = vadeTarihi ?? (taksitler != null && taksitler.isNotEmpty ? taksitler.last.vadeTarihi : kayitTarihi),
        isUzunVadeli = isUzunVadeli ?? (kategori == IslemKategorisi.vadeli),
        bagliOdemeler = bagliOdemeler ?? [];

  static IslemTuru _normallesmisTur(IslemTuru gelenTur) {
    switch (gelenTur) {
      case IslemTuru.paraAlindi: return IslemTuru.odemeAldik;
      case IslemTuru.paraVerildi: return IslemTuru.odemeYaptik;
      case IslemTuru.borcVerildi: return IslemTuru.alacagimiz;
      case IslemTuru.borcAlindi: return IslemTuru.borcumuz;
      default: return gelenTur;
    }
  }

  double get kalanTutar {
    double toplamOdenen = bagliOdemeler.fold(0, (sum, item) => sum + item.tutar);
    return tutar - toplamOdenen;
  }

  Map<String, dynamic> toMap() {
    final normalTur = _normallesmisTur(tur);
    return {
      'id': id,
      'tutar': tutar,
      'aciklama': aciklama,
      'kayitTarihi': kayitTarihi.toIso8601String(),
      'vadeTarihi': vadeTarihi.toIso8601String(),
      'tur': normalTur == IslemTuru.alacagimiz ? 'alacak' : 
             normalTur == IslemTuru.odemeAldik ? 'odemeAldik' : 
             normalTur == IslemTuru.odemeYaptik ? 'odemeYaptik' : 'borc',
      'isUzunVadeli': isUzunVadeli,
      'kapandiMi': kapandiMi,
      'bagliOdemeler': bagliOdemeler.map((o) => o.toMap()).toList(),
      'kategori': kategori.index,
      'miktar': miktar,
      'vadeSayisi': vadeSayisi,
      'taksitler': taksitler?.map((t) => t.toMap()).toList(),
      'stokUrunId': stokUrunId,
      'urunAdi': urunAdi,
      'birimFiyat': birimFiyat,
      'stoktanDussunMu': stoktanDussunMu,
      'isPlan': isPlan,
      'planDurumu': planDurumu,
      'gerceklesenIslemId': gerceklesenIslemId,
      'bagliIslemId': bagliIslemId,
      'odenmediMi': odenmediMi,
      'hukukiSurecBaslatildi': hukukiSurecBaslatildi,
    };
  }

  factory TicariIslem.fromMap(Map<dynamic, dynamic> map) {
    IslemTuru urunTuru = IslemTuru.borcumuz;
    if (map['tur'] == 'alacak') urunTuru = IslemTuru.alacagimiz;
    if (map['tur'] == 'odemeAldik') urunTuru = IslemTuru.odemeAldik;
    if (map['tur'] == 'odemeYaptik') urunTuru = IslemTuru.odemeYaptik;

    final DateTime kesinKayitTarihi = map['kayitTarihi'] != null 
        ? DateTime.parse(map['kayitTarihi'].toString()) 
        : DateTime.now();

    final DateTime kesinVadeTarihi = map['vadeTarihi'] != null 
        ? DateTime.parse(map['vadeTarihi'].toString()) 
        : kesinKayitTarihi;

    final IslemKategorisi kesinKategori = map['kategori'] != null
        ? IslemKategorisi.values[map['kategori']]
        : (map['isUzunVadeli'] == true ? IslemKategorisi.vadeli : IslemKategorisi.gunluk);

    final List<Taksit>? yuklenenTaksitler = map['taksitler'] != null 
        ? (map['taksitler'] as List).map((t) => Taksit.fromMap(t as Map)).toList() 
        : null;

    final String aciklamaMetni = map['aciklama']?.toString() ?? '';

    return TicariIslem(
      id: map['id']?.toString() ?? '',
      kategori: kesinKategori,
      tur: urunTuru,
      aciklama: aciklamaMetni,
      kayitTarihi: kesinKayitTarihi,
      vadeTarihi: kesinVadeTarihi,
      miktar: map['miktar']?.toDouble() ?? (kesinKategori == IslemKategorisi.gunluk ? (map['tutar'] as num?)?.toDouble() : null),
      vadeSayisi: map['vadeSayisi'] ?? yuklenenTaksitler?.length,
      taksitler: yuklenenTaksitler,
      tutar: (map['tutar'] as num?)?.toDouble(),
      isUzunVadeli: map['isUzunVadeli'] ?? false,
      kapandiMi: map['kapandiMi'] ?? false,
      stokUrunId: map['stokUrunId']?.toString(),
      urunAdi: map['urunAdi']?.toString(),
      birimFiyat: map['birimFiyat']?.toDouble(),
      stoktanDussunMu: map['stoktanDussunMu'] ?? false,
      isPlan: map['isPlan'] ?? aciklamaMetni.startsWith("[PLAN] "),
      planDurumu: map['planDurumu'] ?? 'bekliyor',
      gerceklesenIslemId: map['gerceklesenIslemId']?.toString(),
      bagliIslemId: map['bagliIslemId']?.toString(),
      odenmediMi: map['odenmediMi'] ?? false,
      hukukiSurecBaslatildi: map['hukukiSurecBaslatildi'] ?? false,
      bagliOdemeler: (map['bagliOdemeler'] as List<dynamic>?)?.map((o) {
        return TicariIslem.fromMap(o as Map<dynamic, dynamic>);
      }).toList(),
    );
  }
}

class Kisi {
  final String id;
  final String isim;
  final String telephone; 
  final String telefon; 
  final bool isMusteri;
  final bool isTedarikci;
  final bool isOrtak;
  List<TicariIslem> islemler; 

  Kisi({
    required this.id,
    required this.isim,
    required this.telefon,
    this.isMusteri = true,
    this.isTedarikci = false,
    this.isOrtak = false,
    List<TicariIslem>? islemler,
  })  : islemler = islemler ?? [],
        telephone = telefon; 

  Map<String, dynamic> toMap() {
    return { 
      'id': id, 
      'isim': isim, 
      'telefon': telefon, 
      'isMusteri': isMusteri,
      'isTedarikci': isTedarikci,
      'isOrtak': isOrtak,
      'islemler': islemler.map((i) => i.toMap()).toList(),
    };
  }

  factory Kisi.fromMap(Map<dynamic, dynamic> map) {
    return Kisi(
      id: map['id']?.toString() ?? '',
      isim: map['isim']?.toString() ?? '',
      telefon: map['telefon']?.toString() ?? '',
      isMusteri: map['isMusteri'] ?? true,
      isTedarikci: map['isTedarikci'] ?? false,
      isOrtak: map['isOrtak'] ?? false,
      islemler: (map['islemler'] as List<dynamic>?)?.map((i) {
        return TicariIslem.fromMap(i as Map<dynamic, dynamic>);
      }).toList() ?? <TicariIslem>[],
    );
  }
}

// ==========================================
// 📦 STOK ÜRÜN MODELİ
// ==========================================
class StokUrun {
  final String id;
  final String urunAdi;
  final String birim;
  final double mevcutStok;
  final double birimFiyat;
  final double? birimAlisFiyati;
  final String? stokGrubu;
  final double kritikStokSeviyesi;
  final DateTime kayitTarihi;
  final DateTime? sonIslemTarihi;

  StokUrun({
    required this.id,
    required this.urunAdi,
    this.birim = "Adet",
    this.mevcutStok = 0.0,
    this.birimFiyat = 0.0,
    this.birimAlisFiyati,
    this.stokGrubu,
    this.kritikStokSeviyesi = 5.0,
    DateTime? kayitTarihi,
    this.sonIslemTarihi,
  }) : kayitTarihi = kayitTarihi ?? DateTime.now();

  bool get kritikSeviyedeMi => mevcutStok <= kritikStokSeviyesi;

  StokUrun copyWith({
    String? id,
    String? urunAdi,
    String? birim,
    double? mevcutStok,
    double? birimFiyat,
    double? birimAlisFiyati,
    String? stokGrubu,
    double? kritikStokSeviyesi,
    DateTime? kayitTarihi,
    DateTime? sonIslemTarihi,
  }) {
    return StokUrun(
      id: id ?? this.id,
      urunAdi: urunAdi ?? this.urunAdi,
      birim: birim ?? this.birim,
      mevcutStok: mevcutStok ?? this.mevcutStok,
      birimFiyat: birimFiyat ?? this.birimFiyat,
      birimAlisFiyati: birimAlisFiyati ?? this.birimAlisFiyati,
      stokGrubu: stokGrubu ?? this.stokGrubu,
      kritikStokSeviyesi: kritikStokSeviyesi ?? this.kritikStokSeviyesi,
      kayitTarihi: kayitTarihi ?? this.kayitTarihi,
      sonIslemTarihi: sonIslemTarihi ?? this.sonIslemTarihi,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'urunAdi': urunAdi,
      'birim': birim,
      'mevcutStok': mevcutStok,
      'birimFiyat': birimFiyat,
      'birimAlisFiyati': birimAlisFiyati,
      'stokGrubu': stokGrubu,
      'kritikStokSeviyesi': kritikStokSeviyesi,
      'kayitTarihi': kayitTarihi.toIso8601String(),
      'sonIslemTarihi': sonIslemTarihi?.toIso8601String(),
    };
  }

  factory StokUrun.fromMap(Map<dynamic, dynamic> map) {
    return StokUrun(
      id: map['id']?.toString() ?? '',
      urunAdi: map['urunAdi']?.toString() ?? '',
      birim: map['birim']?.toString() ?? 'Adet',
      mevcutStok: (map['mevcutStok'] as num?)?.toDouble() ?? 0.0,
      birimFiyat: (map['birimFiyat'] as num?)?.toDouble() ?? 0.0,
      birimAlisFiyati: (map['birimAlisFiyati'] as num?)?.toDouble(),
      stokGrubu: map['stokGrubu']?.toString(),
      kritikStokSeviyesi: (map['kritikStokSeviyesi'] as num?)?.toDouble() ?? 5.0,
      kayitTarihi: map['kayitTarihi'] != null 
          ? DateTime.parse(map['kayitTarihi'].toString()) 
          : DateTime.now(),
      sonIslemTarihi: map['sonIslemTarihi'] != null 
          ? DateTime.parse(map['sonIslemTarihi'].toString()) 
          : null,
    );
  }
}

// ==========================================
// 🔄 STOK VE CARİ ALIM/SATIM KİŞİSEL İŞ MANTIĞI METODU
// ==========================================
Future<bool> urunIslemiKaydet({
  required String kisiId,
  required String stokUrunId,
  required double miktar,
  required double birimFiyat,
  required IslemTuru islemTuru,
  required bool vadeliMi,
  DateTime? islemTarihi,
  DateTime? vadeTarihi,
  List<Taksit>? taksitler,
  String? aciklama,
  String? customIslemId,
  String? bagliIslemId,
}) async {
  try {
    final Box stokKutusu = Hive.box('stokKutusu');
    final Box kisilerKutusu = Hive.box('defterKutusu');

    String urunAdi = 'Ürün';

    // 1. Stok Miktarını Güncelle
    final rawUrunMap = stokKutusu.get(stokUrunId);
    if (rawUrunMap != null) {
      final urun = StokUrun.fromMap(Map<dynamic, dynamic>.from(rawUrunMap));
      urunAdi = urun.urunAdi;

      double yeniMiktar = urun.mevcutStok;
      if (islemTuru == IslemTuru.alacagimiz || islemTuru == IslemTuru.odemeAldik) {
        yeniMiktar -= miktar; // Satış yapıldı, stok eksilt
      } else {
        yeniMiktar += miktar; // Alış yapıldı, stok artır
      }

      final guncelUrun = urun.copyWith(
        mevcutStok: yeniMiktar,
        sonIslemTarihi: DateTime.now(),
      );

      await stokKutusu.put(stokUrunId, guncelUrun.toMap());
    }

    // 2. Cari Kişi Hesabına Ticari İşlemi Ekle
    final rawKisiMap = kisilerKutusu.get(kisiId);
    if (rawKisiMap != null) {
      final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(rawKisiMap));

      final islemId = customIslemId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final toplamTutar = miktar * birimFiyat;

      final yeniIslem = TicariIslem(
        id: islemId,
        kategori: vadeliMi ? IslemKategorisi.vadeli : IslemKategorisi.gunluk,
        tur: islemTuru,
        aciklama: aciklama ?? "$urunAdi ($miktar Adet)",
        kayitTarihi: islemTarihi ?? DateTime.now(),
        vadeTarihi: vadeTarihi ?? islemTarihi ?? DateTime.now(),
        tutar: toplamTutar,
        miktar: miktar,
        birimFiyat: birimFiyat,
        stokUrunId: stokUrunId,
        urunAdi: urunAdi,
        stoktanDussunMu: true,
        taksitler: taksitler,
        vadeSayisi: taksitler?.length,
        bagliIslemId: bagliIslemId,
      );

      kisi.islemler.add(yeniIslem);
      await kisilerKutusu.put(kisiId, kisi.toMap());
      await YedekEsitlemeServisi().yerelZamanDamgasiGuncelle();
      return true;
    }
    return false;
  } catch (e) {
    debugPrint("urunIslemiKaydet Hatası: $e");
    return false;
  }
}
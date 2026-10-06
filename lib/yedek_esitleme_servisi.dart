/* 
  🛡 TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'google_drive_servisi.dart';
import 'google_drive_oturum_servisi.dart';

enum ReconciliationResult {
  guncel,                      // Yerel ve bulut eşit veya yerel yeni olup sessizce yedeklendi
  yerelYeniSessizceYedekle,    // Otomatik senkronizasyon için geçici durum
  bulutYeniOnayIste,           // Buluttaki veri daha yeni, kullanıcı onayı gerekli
  hata,                        // İnternet yok veya Drive erişilemiyor
}

class YedekEsitlemeServisi {
  final GoogleDriveServisi _driveServisi;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Duration _zamanToleransi = const Duration(seconds: 5);

  static final ValueNotifier<String?> syncStatusNotifier = ValueNotifier<String?>(null);

  YedekEsitlemeServisi({GoogleDriveServisi? driveServisi})
      : _driveServisi = driveServisi ?? GoogleDriveServisi();

  /// Senkronizasyon/Yedekleme şalterinin açık olup olmadığını kontrol eder.
  Future<bool> isSenkronizasyonAcik() async {
    final String? driveAktif = await _storage.read(key: 'drive_aktif_mi');
    return driveAktif == 'evet';
  }

  Future<void> yerelZamanDamgasiGuncelle() async {
    try {
      final tazeZaman = DateTime.now().toIso8601String();
      await _storage.write(key: 'yerel_son_guncelleme_tarihi', value: tazeZaman);
      await _storage.write(key: 'yerel_son_guncelleme', value: tazeZaman);
      debugPrint("Yedek Eşitleme: Yerel zaman damgası güncellendi -> $tazeZaman");
    } catch (e) {
      debugPrint("Yerel Zaman Yazma Hatası: $e");
    }
  }

  Future<DateTime> yerelZamanDamgasiGetir() async {
    try {
      String? zamStr = await _storage.read(key: 'yerel_son_guncelleme_tarihi');
      zamStr ??= await _storage.read(key: 'yerel_son_guncelleme');
      if (zamStr != null) {
        return DateTime.parse(zamStr);
      }
    } catch (e) {
      debugPrint("Yerel Zaman Okuma Hatası: $e");
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<DateTime> bulutZamanDamgasiGetir(String dosyaId) async {
    try {
      final String? yedekMetni = await _driveServisi.yedekDosyasiniOku(dosyaId, forceInteractive: false);
      if (yedekMetni != null) {
        final Map<String, dynamic> yedekData = jsonDecode(yedekMetni);
        if (yedekData.containsKey('tarih') && yedekData['tarih'] != null) {
          return DateTime.parse(yedekData['tarih'].toString());
        } else if (yedekData.containsKey('son_guncelleme') && yedekData['son_guncelleme'] != null) {
          return DateTime.parse(yedekData['son_guncelleme'].toString());
        }
      }
    } catch (e) {
      debugPrint("Bulut Zaman Damgası Okuma Hatası: $e");
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> otomatikSenkronizasyonuBaslat() async {
    try {
      if (!await isSenkronizasyonAcik()) return;
      await yoklamaVeEsitlemeKarariAl();
    } catch (e) {
      debugPrint("Otomatik senkronizasyon hatası: $e");
    }
  }

  Future<ReconciliationResult> yoklamaVeEsitlemeKarariAl() async {
    try {
      if (!await isSenkronizasyonAcik()) return ReconciliationResult.hata;

      final oturumServisi = GoogleDriveOturumServisi(driveServisi: _driveServisi);
      final kilitDurumu = await oturumServisi.kilitDurumunuSorgula(forceInteractive: false);
      
      if (kilitDurumu == OturumKilitDurumu.baskaCihazAktif) {
        syncStatusNotifier.value = "baska_cihaz_aktif";
        return ReconciliationResult.hata;
      }

      if (kilitDurumu == OturumKilitDurumu.hata) {
        return ReconciliationResult.hata;
      }

      final String? bulutDosyaId = await _driveServisi.eskiYedegiBulVeGetir(forceInteractive: false);
      if (bulutDosyaId == null) {
        final DateTime yerelTarih = await yerelZamanDamgasiGetir();
        if (yerelTarih.millisecondsSinceEpoch > 0) {
          await yerelVeriyiSessizceYedekle();
        }
        return ReconciliationResult.guncel;
      }

      final DateTime yerelZaman = await yerelZamanDamgasiGetir();
      final DateTime bulutZaman = await bulutZamanDamgasiGetir(bulutDosyaId);

      final difference = yerelZaman.difference(bulutZaman);

      if (difference.inSeconds.abs() <= _zamanToleransi.inSeconds) {
        return ReconciliationResult.guncel;
      } else if (yerelZaman.isAfter(bulutZaman)) {
        await yerelVeriyiSessizceYedekle();
        return ReconciliationResult.guncel;
      } else {
        return ReconciliationResult.bulutYeniOnayIste;
      }
    } catch (e) {
      debugPrint("Yoklama ve Eşitleme Kararı Hatası: $e");
      return ReconciliationResult.hata;
    }
  }

  Future<bool> yerelVeriyiSessizceYedekle({bool forceInteractive = false}) async {
    // 🛡️ 1. KONTROL: Şalter kapalıysa direkt işlemi sonlandır
    if (!await isSenkronizasyonAcik()) {
      return false;
    }

    try {
      final Map<String, dynamic> paket = await _yerelKutulariPaketle();
      final bool basarili = await _driveServisi.yedekle(paket, forceInteractive: forceInteractive);
      if (basarili) {
        final oturumServisi = GoogleDriveOturumServisi(driveServisi: _driveServisi);
        await oturumServisi.kilidiUzat();
      }
      return basarili;
    } catch (e) {
      debugPrint("Sessiz yedekleme hatası: $e");
      return false;
    }
  }

  Future<bool> yerelVeriyiGarantiliYedekle() async {
    // 🛡️ 1. KONTROL: Şalter kapalıysa direkt işlemi sonlandır
    if (!await isSenkronizasyonAcik()) {
      debugPrint("Otomatik senkronizasyon şalteri kapalı, yedekleme yapılmadı.");
      return false;
    }

    await yerelZamanDamgasiGuncelle();
    return await yerelVeriyiSessizceYedekle(forceInteractive: true);
  }

  Future<bool> bulutVerisiniYereleUygula() async {
    try {
      final String? dosyaId = await _driveServisi.eskiYedegiBulVeGetir(forceInteractive: true);
      if (dosyaId == null) return false;

      final String? icerik = await _driveServisi.yedekDosyasiniOku(dosyaId, forceInteractive: true);
      if (icerik == null || icerik.isEmpty) return false;

      final Map<String, dynamic> yedekData = jsonDecode(icerik);
      await _yerelKutularaYaz(yedekData);

      if (yedekData.containsKey('tarih')) {
        await _storage.write(key: 'yerel_son_guncelleme_tarihi', value: yedekData['tarih'].toString());
        await _storage.write(key: 'yerel_son_guncelleme', value: yedekData['tarih'].toString());
      }

      final oturumServisi = GoogleDriveOturumServisi(driveServisi: _driveServisi);
      await oturumServisi.oturumuKilitle(kilitKir: true, forceInteractive: true);

      return true;
    } catch (e) {
      debugPrint("Bulut verisini yerele uygulama hatası: $e");
      return false;
    }
  }

  /// Bulut yedeğini indirir, Hive veritabanına uygular ve içerisindeki PIN/Kullanıcı
  /// bilgilerini de ayrıştırarak FlutterSecureStorage üzerine yazar.
  Future<bool> bulutVerisiniYereleVeDepoyaUygula() async {
    try {
      final String? dosyaId = await _driveServisi.eskiYedegiBulVeGetir(forceInteractive: true);
      if (dosyaId == null) return false;

      final String? icerik = await _driveServisi.yedekDosyasiniOku(dosyaId, forceInteractive: true);
      if (icerik == null || icerik.isEmpty) return false;

      final Map<String, dynamic> yedekData = jsonDecode(icerik);
      
      // 1. Hive kutularına verileri yaz
      await _yerelKutularaYaz(yedekData);

      // 2. Güvenli depo (FlutterSecureStorage) bilgilerini ayrıştırıp güncelle
      if (yedekData.containsKey('uygulama_pin') && yedekData['uygulama_pin'] != null) {
        await _storage.write(key: 'uygulama_pin', value: yedekData['uygulama_pin'].toString());
      } else if (yedekData.containsKey('pin') && yedekData['pin'] != null) {
        await _storage.write(key: 'uygulama_pin', value: yedekData['pin'].toString());
      }

      if (yedekData.containsKey('kullanici_adi') && yedekData['kullanici_adi'] != null) {
        await _storage.write(key: 'kullanici_adi', value: yedekData['kullanici_adi'].toString());
      }

      if (yedekData.containsKey('guvenlik_sorusu') && yedekData['guvenlik_sorusu'] != null) {
        await _storage.write(key: 'guvenlik_sorusu', value: yedekData['guvenlik_sorusu'].toString());
      }

      if (yedekData.containsKey('guvenlik_cevabi') && yedekData['guvenlik_cevabi'] != null) {
        await _storage.write(key: 'guvenlik_cevabi', value: yedekData['guvenlik_cevabi'].toString());
      }

      if (yedekData.containsKey('tarih')) {
        await _storage.write(key: 'yerel_son_guncelleme_tarihi', value: yedekData['tarih'].toString());
        await _storage.write(key: 'yerel_son_guncelleme', value: yedekData['tarih'].toString());
      }

      final oturumServisi = GoogleDriveOturumServisi(driveServisi: _driveServisi);
      await oturumServisi.oturumuKilitle(kilitKir: true, forceInteractive: true);

      return true;
    } catch (e) {
      debugPrint("Bulut verisini yerele ve güvenli depoya uygulama hatası: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> _yerelKutulariPaketle() async {
    final Box defterKutusu = Hive.box('defterKutusu');
    final Box stokKutusu = Hive.box('stokKutusu');
    final Box stokGruplariKutusu = Hive.box('stokGruplariKutusu');
    final Box kisiKutusu = Hive.box('kisiKutusu');
    final Box ayarlarKutusu = Hive.box('ayarlarKutusu');

    final DateTime yerelZaman = await yerelZamanDamgasiGetir();

    final String? pin = await _storage.read(key: 'uygulama_pin');
    final String? kullanici = await _storage.read(key: 'kullanici_adi');
    final String? soru = await _storage.read(key: 'guvenlik_sorusu');
    final String? cevap = await _storage.read(key: 'guvenlik_cevabi');

    return {
      'tarih': yerelZaman.toIso8601String(),
      'son_guncelleme': yerelZaman.toIso8601String(),
      'uygulama_pin': pin,
      'kullanici_adi': kullanici,
      'guvenlik_sorusu': soru,
      'guvenlik_cevabi': cevap,
      'defterKutusu': defterKutusu.toMap().map((k, v) => MapEntry(k.toString(), v)),
      'stokKutusu': stokKutusu.toMap().map((k, v) => MapEntry(k.toString(), v)),
      'stokGruplariKutusu': stokGruplariKutusu.toMap().map((k, v) => MapEntry(k.toString(), v)),
      'kisiKutusu': kisiKutusu.toMap().map((k, v) => MapEntry(k.toString(), v)),
      'ayarlarKutusu': ayarlarKutusu.toMap().map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  Future<void> _yerelKutularaYaz(Map<String, dynamic> data) async {
    if (data.containsKey('defterKutusu')) {
      final box = Hive.box('defterKutusu');
      await box.clear();
      await box.putAll(Map<String, dynamic>.from(data['defterKutusu']));
    }
    if (data.containsKey('stokKutusu')) {
      final box = Hive.box('stokKutusu');
      await box.clear();
      await box.putAll(Map<String, dynamic>.from(data['stokKutusu']));
    }
    if (data.containsKey('stokGruplariKutusu')) {
      final box = Hive.box('stokGruplariKutusu');
      await box.clear();
      await box.putAll(Map<String, dynamic>.from(data['stokGruplariKutusu']));
    }
    if (data.containsKey('kisiKutusu')) {
      final box = Hive.box('kisiKutusu');
      await box.clear();
      await box.putAll(Map<String, dynamic>.from(data['kisiKutusu']));
    }
    if (data.containsKey('ayarlarKutusu')) {
      final box = Hive.box('ayarlarKutusu');
      await box.clear();
      await box.putAll(Map<String, dynamic>.from(data['ayarlarKutusu']));
    }
  }
}
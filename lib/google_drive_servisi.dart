/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveException implements Exception {
  final String message;
  final dynamic originalError;

  GoogleDriveException(this.message, [this.originalError]);

  @override
  String toString() => 'GoogleDriveException: $message${originalError != null ? " ($originalError)" : ""}';
}

class GoogleAuthException implements Exception {
  final String mesaj;
  GoogleAuthException(this.mesaj);
  @override
  String toString() => mesaj;
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveServisi {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Bellekte aktif oturum istemcisini ve durumları paylaşılacak şekilde saklıyoruz
  static drive.DriveApi? _sharedDriveApi;
  static bool _initialized = false;
  static bool _isAuthenticating = false;

  /// Soğuma Süresi Kontrolü: Son 1 saat içinde hata alındıysa arka plan çağrısını engeller
  Future<bool> sogumaSuresiDolduMu() async {
    try {
      final String? sonHataStr = await _storage.read(key: 'drive_son_hata_zamani');
      if (sonHataStr == null) return true;
      final DateTime sonHata = DateTime.parse(sonHataStr);
      final difference = DateTime.now().difference(sonHata);
      return difference.inHours >= 1;
    } catch (_) {
      return true;
    }
  }

  /// Hata zaman damgasını kaydeder
  Future<void> hataZamaniniKaydet() async {
    try {
      await _storage.write(
        key: 'drive_son_hata_zamani',
        value: DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  /// Cihazın gerçek internet bağlantısına sahip olup olmadığını hızlıca kontrol eder (Google sunucusuna ping)
  Future<bool> internetVarMi() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// GoogleSignIn servisini v7+ standartlarında başlatır
  Future<void> _initIfNeeded() async {
    if (!_initialized) {
      try {
        await _googleSignIn.initialize(
          serverClientId: '635139870431-hcg6f2iafbl127m9ionopbja8niu5i1l.apps.googleusercontent.com',
        );
      } catch (e) {
        debugPrint("GoogleSignIn initialize hatası: $e");
      }
      _initialized = true;
    }
  }

  /// Oturum ve Drive API bağlantısının aktifliğini garantiler (Maksimum 4 saniye timeout)
  Future<bool> _baglantiyiGarantile({bool forceInteractive = false}) async {
    try {
      // 🛡️ AKTİF HESAP/İSTEMCİ KONTROLÜ:
      // Eğer halihazırda oluşturulmuş DriveApi istemcisi zaten bellekte hazırsa
      // tekrar yetkilendirme ekranı veya çağrısı yapmadan süreci tamamlıyoruz.
      if (_sharedDriveApi != null) {
        return true;
      }

      // Koruma 1: drive_aktif_mi kontrolü (Interaktif dışındaki çağrılarda)
      if (!forceInteractive) {
        final String? driveAktifMi = await _storage.read(key: 'drive_aktif_mi');
        if (driveAktifMi != 'evet') return false;

        // Koruma 2: Soğuma Süresi
        if (!await sogumaSuresiDolduMu()) return false;
      }

      // Koruma 3: Gerçek İnternet
      final bool online = await internetVarMi();
      if (!online) return false;

      if (_isAuthenticating) return false;
      _isAuthenticating = true;

      await _initIfNeeded();

      // Aktif hesabı sessiz veya interaktif yöntemle al
      GoogleSignInAccount? googleKullanici;

      if (forceInteractive) {
        googleKullanici = await _googleSignIn.authenticate();
      } else {
        try {
          // Koruma 4 & 5: Maksimum 4 Saniye Timeout ile Sessiz Giriş
          googleKullanici = await _googleSignIn
              .attemptLightweightAuthentication()
              ?.timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint("Sessiz oturum açma veya zaman aşımı hatası: $e");
          await hataZamaniniKaydet();
          return false;
        }
      }

      final guvenliKullanici = googleKullanici;
      if (guvenliKullanici != null) {
        var authorization = await guvenliKullanici.authorizationClient.authorizationForScopes([
          drive.DriveApi.driveAppdataScope,
        ]);

        if (authorization == null && forceInteractive) {
          authorization = await guvenliKullanici.authorizationClient.authorizeScopes([
            drive.DriveApi.driveAppdataScope,
          ]);
        }

        if (authorization != null && authorization.accessToken.isNotEmpty) {
          final Map<String, String> kuryeHeaders = {
            'Authorization': 'Bearer ${authorization.accessToken}',
          };
          final GoogleAuthClient temizKurye = GoogleAuthClient(kuryeHeaders);
          _sharedDriveApi = drive.DriveApi(temizKurye);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Google Drive bağlantı garantileme hatası: $e");
      await hataZamaniniKaydet();
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Aktif Google Hesabını getirir veya kullanıcı butonla tetiklediyse interaktif oturum açar
  Future<GoogleSignInAccount?> kullaniciOturumAc({bool forceInteractive = true}) async {
    try {
      final bool online = await internetVarMi();
      if (!online) throw GoogleAuthException("İnternet bağlantısı yok.");

      await _initIfNeeded();
      GoogleSignInAccount? user;

      if (forceInteractive) {
        user = await _googleSignIn.authenticate();
      } else {
        user = await _googleSignIn.attemptLightweightAuthentication();
      }

      await _baglantiyiGarantile(forceInteractive: forceInteractive);
      return user;
    } catch (e) {
      debugPrint("Kullanıcı oturum açma hatası: $e");
      return null;
    }
  }

  /// Oturum Servisinin güvenle erişebileceği Drive API istemcisi
  Future<drive.DriveApi?> getDriveApi({bool forceInteractive = false}) async {
    final baglandi = await _baglantiyiGarantile(forceInteractive: forceInteractive);
    if (!baglandi) return null;
    return _sharedDriveApi;
  }

  /// Kullanıcının Google Drive hesabını manuel bağlama fonksiyonu (Buton tıklamalarında)
  Future<bool> googleHesabiniBagla() async {
    try {
      final bool baglandi = await _baglantiyiGarantile(forceInteractive: true);
      if (baglandi) {
        await _storage.write(key: 'drive_aktif_mi', value: 'evet');
        await _storage.write(key: 'drive_bagli_mi', value: 'evet');
      }
      return baglandi;
    } catch (hata) {
      throw GoogleAuthException("Google hesabınız bağlanamadı. İnternetinizi veya izin kutucuğunu kontrol edin.");
    }
  }

  /// Google Drive AppData klasöründe belirtilen dosyayı arar ve ID döndürür
  Future<String?> dosyaIdBul(String dosyaAdi, {bool forceInteractive = false}) async {
    final baglandi = await _baglantiyiGarantile(forceInteractive: forceInteractive);
    if (!baglandi || _sharedDriveApi == null) return null;

    try {
      final fileList = await _sharedDriveApi!.files.list(
        q: "name = '$dosyaAdi' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }
      return null;
    } catch (e) {
      debugPrint("Dosya arama hatası: $e");
      return null;
    }
  }

  /// Eski yedek dosyasını (esnaf_defter_yedek.json) arar
  Future<String?> eskiYedegiBulVeGetir({bool forceInteractive = false}) async {
    return await dosyaIdBul('esnaf_defter_yedek.json', forceInteractive: forceInteractive);
  }

  /// Metin içeriğini Google Drive AppData alanına kaydeder
  Future<String?> metinKaydet(String dosyaAdi, String icerik, {bool forceInteractive = false}) async {
    final baglandi = await _baglantiyiGarantile(forceInteractive: forceInteractive);
    if (!baglandi || _sharedDriveApi == null) {
      throw GoogleDriveException("Google Drive bağlantısı kurulamadı.");
    }

    try {
      final varolanId = await dosyaIdBul(dosyaAdi, forceInteractive: forceInteractive);
      final bytes = utf8.encode(icerik);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (varolanId != null) {
        final updatedFile = await _sharedDriveApi!.files.update(
          drive.File(),
          varolanId,
          uploadMedia: media,
        );
        return updatedFile.id;
      } else {
        final newFile = drive.File()
          ..name = dosyaAdi
          ..parents = ['appDataFolder'];

        final createdFile = await _sharedDriveApi!.files.create(
          newFile,
          uploadMedia: media,
        );
        return createdFile.id;
      }
    } catch (e) {
      throw GoogleDriveException("Metin kaydetme başarısız", e);
    }
  }

  /// Yedek dosyasını ID ile indirip metin olarak okur
  Future<String?> yedekDosyasiniOku(String dosyaId, {bool forceInteractive = false}) async {
    final baglandi = await _baglantiyiGarantile(forceInteractive: forceInteractive);
    if (!baglandi || _sharedDriveApi == null) throw GoogleAuthException("Google Drive bağlantısı koptu.");

    try {
      final media = await _sharedDriveApi!.files.get(
        dosyaId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (media is drive.Media) {
        final List<int> dataBytes = [];
        await for (final data in media.stream) {
          dataBytes.addAll(data);
        }
        return utf8.decode(dataBytes);
      }
      return null;
    } catch (e) {
      throw GoogleDriveException("Yedek dosyası buluttan okunamadı", e);
    }
  }

  /// Metin dosyasını isme göre doğrudan okur
  Future<String?> metinOku(String dosyaAdi, {bool forceInteractive = false}) async {
    final dosyaId = await dosyaIdBul(dosyaAdi, forceInteractive: forceInteractive);
    if (dosyaId == null) return null;
    return await yedekDosyasiniOku(dosyaId, forceInteractive: forceInteractive);
  }

  /// Harita nesnesini JSON'a dönüştürüp Drive'a yedekler
  Future<bool> yedekle(Map<String, dynamic> yedekData, {bool forceInteractive = false}) async {
    try {
      final String jsonMetni = jsonEncode(yedekData);
      final res = await metinKaydet('esnaf_defter_yedek.json', jsonMetni, forceInteractive: forceInteractive);
      return res != null;
    } catch (e) {
      if (forceInteractive) {
        throw GoogleDriveException("Yedekleme hatası: $e");
      }
      return false;
    }
  }

  /// Yerel bir dosyayı Google Drive AppData alanına kaydeder
  Future<String?> dosyaYukle(File yerelDosya, String driveDosyaAdi, {bool forceInteractive = false}) async {
    final baglandi = await _baglantiyiGarantile(forceInteractive: forceInteractive);
    if (!baglandi || _sharedDriveApi == null) {
      throw GoogleDriveException("Google Drive bağlantısı kurulamadı.");
    }

    try {
      final varolanId = await dosyaIdBul(driveDosyaAdi, forceInteractive: forceInteractive);
      final length = await yerelDosya.length();
      final media = drive.Media(yerelDosya.openRead(), length);

      if (varolanId != null) {
        final updated = await _sharedDriveApi!.files.update(
          drive.File(),
          varolanId,
          uploadMedia: media,
        );
        return updated.id;
      } else {
        final driveFile = drive.File()
          ..name = driveDosyaAdi
          ..parents = ['appDataFolder'];

        final created = await _sharedDriveApi!.files.create(
          driveFile,
          uploadMedia: media,
        );
        return created.id;
      }
    } catch (e) {
      throw GoogleDriveException("Dosya yükleme başarısız", e);
    }
  }

  /// Drive üzerindeki dosyayı belirtilen yerel adrese indirir
  Future<bool> dosyaIndir(String driveDosyaAdi, File hedefDosya, {bool forceInteractive = false}) async {
    final baglandi = await _baglantiyiGarantile(forceInteractive: forceInteractive);
    if (!baglandi || _sharedDriveApi == null) return false;

    try {
      final dosyaId = await dosyaIdBul(driveDosyaAdi, forceInteractive: forceInteractive);
      if (dosyaId == null) return false;

      final media = await _sharedDriveApi!.files.get(
        dosyaId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (media is drive.Media) {
        final parentDir = hedefDosya.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        final sink = hedefDosya.openWrite();
        await media.stream.pipe(sink);
        await sink.close();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Dosya indirme hatası: $e");
      return false;
    }
  }

  /// Dosyanın buluttaki son güncellenme tarihini döndürür
  Future<DateTime?> dosyaTarihiAl(String dosyaAdi, {bool forceInteractive = false}) async {
    final baglandi = await _baglantiyiGarantile(forceInteractive: forceInteractive);
    if (!baglandi || _sharedDriveApi == null) return null;

    try {
      final fileList = await _sharedDriveApi!.files.list(
        q: "name = '$dosyaAdi' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        return files.first.modifiedTime;
      }
      return null;
    } catch (e) {
      debugPrint("Dosya tarihi alma hatası: $e");
      return null;
    }
  }

  /// Google Oturumunu kapatır
  Future<void> oturumuKapat() async {
    _sharedDriveApi = null;
    try {
      await _googleSignIn.signOut();
      await _storage.write(key: 'drive_aktif_mi', value: 'hayir');
      await _storage.write(key: 'drive_bagli_mi', value: 'hayir');
    } catch (e) {
      debugPrint("Google SignOut hatası: $e");
    }
  }

  Future<void> googleOturumunuKapat() async {
    await oturumuKapat();
  }
}
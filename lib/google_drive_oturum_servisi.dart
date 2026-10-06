/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'google_drive_servisi.dart';

enum OturumKilitDurumu {
  kilitBizde,
  kilitYok,
  baskaCihazAktif,
  hata,
  kilitliDegil,
  kilitAlindi,
  baskaCihazdaAcik,
}

class GoogleDriveOturumServisi {
  final GoogleDriveServisi _driveServisi;

  GoogleDriveOturumServisi({GoogleDriveServisi? driveServisi})
      : _driveServisi = driveServisi ?? GoogleDriveServisi();

  /// Cihaza özel benzersiz bir kimlik (ID) okur veya ilk defa oluşturup kaydeder.
  Future<String> _cihazIdGetirOrOlustur() async {
    const storage = FlutterSecureStorage();
    String? id = await storage.read(key: 'cihaz_benzersiz_id');
    if (id == null) {
      final int ms = DateTime.now().millisecondsSinceEpoch;
      final int randomOffset = 1000 + (DateTime.now().microsecond % 9000);
      id = "${ms}_$randomOffset";
      await storage.write(key: 'cihaz_benzersiz_id', value: id);
    }
    return id;
  }

  /// Drive API istemcisine erişimi garantiler
  Future<drive.DriveApi?> _getDriveApi({bool forceInteractive = false}) async {
    return await _driveServisi.getDriveApi(forceInteractive: forceInteractive);
  }

  /// Google Drive AppData klasöründe oturum kilit dosyasını (oturum.lock) arar.
  Future<drive.File?> _findLockFile(drive.DriveApi api) async {
    try {
      final fileList = await api.files.list(
        q: "name = 'oturum.lock' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime)',
      );
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first;
      }
    } catch (e) {
      debugPrint("Oturum Servisi: Kilit dosyası aranamadı: $e");
    }
    return null;
  }

  /// Kilit dosyasının içeriğindeki JSON verisini okur.
  Future<Map<String, dynamic>?> _readLockFileContents(drive.DriveApi api, String fileId) async {
    try {
      final Object response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is drive.Media) {
        final List<int> bytes = [];
        await for (var chunk in response.stream) {
          bytes.addAll(chunk);
        }
        final String jsonStr = utf8.decode(bytes);
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Oturum Servisi: Kilit dosyası okunamadı: $e");
    }
    return null;
  }

  /// Cihaz eşleşmelerini ve 5 dakikalık kiralama (lease) süre aşımını kontrol eder.
  Future<OturumKilitDurumu> kilitDurumunuSorgula({bool forceInteractive = false}) async {
    try {
      final api = await _getDriveApi(forceInteractive: forceInteractive);
      if (api == null) return OturumKilitDurumu.hata;

      final lockFile = await _findLockFile(api);
      if (lockFile == null) {
        return OturumKilitDurumu.kilitYok;
      }

      final data = await _readLockFileContents(api, lockFile.id!);
      if (data == null) {
        return OturumKilitDurumu.kilitYok;
      }

      final String? lockCihazId = data['cihazId']?.toString();
      final String? sonGuncellemeStr = data['sonGuncelleme']?.toString();
      final String localCihazId = await _cihazIdGetirOrOlustur();

      if (sonGuncellemeStr != null) {
        try {
          final DateTime lastUpdate = DateTime.parse(sonGuncellemeStr);
          final difference = DateTime.now().difference(lastUpdate);
          
          if (difference.inMinutes > 5) {
            return OturumKilitDurumu.kilitYok;
          }
        } catch (_) {
          return OturumKilitDurumu.kilitYok;
        }
      }

      if (lockCihazId == localCihazId) {
        return OturumKilitDurumu.kilitBizde;
      } else {
        return OturumKilitDurumu.baskaCihazAktif;
      }
    } catch (e) {
      debugPrint("Oturum Servisi: Kilit sorgulama hatası: $e");
      return OturumKilitDurumu.hata;
    }
  }

  /// Mevcut kilidi üzerimize mühürler. kilitKir parametresiyle diğer cihazı devre dışı bırakabilir.
  Future<void> oturumuKilitle({bool kilitKir = false, bool forceInteractive = false}) async {
    final api = await _getDriveApi(forceInteractive: forceInteractive);
    if (api == null) throw Exception("Google Drive bağlantısı yok.");

    final existingLock = await _findLockFile(api);
    final localCihazId = await _cihazIdGetirOrOlustur();
    final Map<String, dynamic> lockData = {
      'cihazId': localCihazId,
      'sonGuncelleme': DateTime.now().toIso8601String(),
    };
    final String content = jsonEncode(lockData);
    final List<int> bytes = utf8.encode(content);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    if (existingLock != null) {
      if (!kilitKir) {
        final data = await _readLockFileContents(api, existingLock.id!);
        if (data != null) {
          final String? lockCihazId = data['cihazId']?.toString();
          final String? sonGuncellemeStr = data['sonGuncelleme']?.toString();
          if (lockCihazId != localCihazId && sonGuncellemeStr != null) {
            try {
              final DateTime lastUpdate = DateTime.parse(sonGuncellemeStr);
              if (DateTime.now().difference(lastUpdate).inMinutes <= 5) {
                throw Exception("Başka bir cihazda aktif kilit mevcut.");
              }
            } catch (e) {
              if (e is Exception && e.toString().contains("Başka bir cihazda")) rethrow;
            }
          }
        }
      }
      final driveFile = drive.File();
      await api.files.update(driveFile, existingLock.id!, uploadMedia: media);
    } else {
      final driveFile = drive.File()
        ..name = 'oturum.lock'
        ..parents = ['appDataFolder'];
      await api.files.create(driveFile, uploadMedia: media);
    }
  }

  /// Aktif oturum devam ederken kilit ömrünü sessizce +5 dakika daha uzatır.
  Future<void> kilidiUzat() async {
    final api = await _getDriveApi(forceInteractive: false);
    if (api == null) return;

    final existingLock = await _findLockFile(api);
    if (existingLock == null) {
      await oturumuKilitle(forceInteractive: false);
      return;
    }

    final localCihazId = await _cihazIdGetirOrOlustur();
    final Map<String, dynamic> lockData = {
      'cihazId': localCihazId,
      'sonGuncelleme': DateTime.now().toIso8601String(),
    };
    final String content = jsonEncode(lockData);
    final List<int> bytes = utf8.encode(content);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final driveFile = drive.File();
    await api.files.update(driveFile, existingLock.id!, uploadMedia: media);
    debugPrint("Oturum Servisi: Kilit kalp atışıyla başarıyla uzatıldı.");
  }

  /// Oturum kapatıldığında kilit dosyasını temizler.
  Future<void> kilidiKaldir() async {
    final api = await _getDriveApi(forceInteractive: false);
    if (api == null) return;

    final existingLock = await _findLockFile(api);
    if (existingLock != null) {
      final localCihazId = await _cihazIdGetirOrOlustur();
      final data = await _readLockFileContents(api, existingLock.id!);
      if (data != null) {
        final String? lockCihazId = data['cihazId']?.toString();
        if (lockCihazId == localCihazId) {
          await api.files.delete(existingLock.id!);
          debugPrint("Oturum Servisi: Kilit başarıyla serbest bırakıldı.");
        }
      }
    }
  }

  /// Eski kod uyumluluğu için kilit kontrol sarmalayıcısı
  Future<OturumKilitDurumu> oturumKilitDurumuKontrolEt({bool forceAc = false}) async {
    final durum = await kilitDurumunuSorgula(forceInteractive: forceAc);
    
    if (durum == OturumKilitDurumu.kilitBizde) return OturumKilitDurumu.kilitAlindi;
    if (durum == OturumKilitDurumu.baskaCihazAktif) {
      if (forceAc) {
        await oturumuKilitle(kilitKir: true, forceInteractive: true);
        return OturumKilitDurumu.kilitAlindi;
      }
      return OturumKilitDurumu.baskaCihazdaAcik;
    }
    if (durum == OturumKilitDurumu.kilitYok) {
      await oturumuKilitle(forceInteractive: forceAc);
      return OturumKilitDurumu.kilitAlindi;
    }
    return OturumKilitDurumu.hata;
  }
}
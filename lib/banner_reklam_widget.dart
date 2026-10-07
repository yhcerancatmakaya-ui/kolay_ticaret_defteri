/* 
  🛡 TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tema_renk_paleti.dart';

class BannerReklamWidget extends StatefulWidget {
  const BannerReklamWidget({super.key});

  @override
  State<BannerReklamWidget> createState() => _BannerReklamWidgetState();
}

class _BannerReklamWidgetState extends State<BannerReklamWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // Google Play Store Mağaza Linkiniz
  final String _playStoreUrl =
      "https://play.google.com/store/apps/details?id=com.kotidef.uygulama";

  @override
  void initState() {
    super.initState();
    // Yalnızca Mobil (Android veya iOS) platformlarda reklamı yükle
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      // Test Banner Reklam ID'si (Canlıya alırken kendi AdMob Banner ID'niz ile değiştirin)
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner reklam yükleme hatası: ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _playStoreAc() async {
    final Uri url = Uri.parse(_playStoreUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Play Store linki açılamadı: $_playStoreUrl');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌐 EĞER ÇALIŞILAN ORTAM WEB İSE: Google Play Store Mobil İndirme Bağlantısı Göster
    if (kIsWeb) {
      return Container(
        width: double.infinity,
        color: AppColors.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  "Mobil uygulamamızı Google Play'den indirin!",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _playStoreAc,
              icon: const Icon(Icons.get_app_rounded, size: 16),
              label: const Text(
                "İndir",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    // 📱 EĞER MOBİL İSE VE REKLAM YÜKLENDİYSE: AdMob Banner Göster
    if (_isAdLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Reklam yüklenmediyse veya desteklenmeyen masaüstü ortamındaysa boş döndür
    return const SizedBox.shrink();
  }
}
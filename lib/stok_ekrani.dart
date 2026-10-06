/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';

import 'modeller.dart';
import 'tema_renk_paleti.dart';
import 'yardimcilar.dart';
import 'yedek_esitleme_servisi.dart';
import 'ticari_islem_wizard_dialog.dart';

class BinlikParaFormatter extends TextInputFormatter {
  static const double maxTutar = 1000000000.0;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final sadeceRakam = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (sadeceRakam.isEmpty) {
      return const TextEditingValue(text: '');
    }

    double sayi = double.tryParse(sadeceRakam) ?? 0;
    if (sayi > maxTutar) {
      sayi = maxTutar;
    }

    final yeniMetin = formatPara(sayi);
    return TextEditingValue(
      text: yeniMetin,
      selection: TextSelection.collapsed(offset: yeniMetin.length),
    );
  }
}

class StokEkrani extends StatefulWidget {
  const StokEkrani({super.key});

  @override
  State<StokEkrani> createState() => _StokEkraniState();
}

class _StokEkraniState extends State<StokEkrani> {
  final TextEditingController _aramaController = TextEditingController();
  final ValueNotifier<String> _aramaNotifier = ValueNotifier<String>("");
  String _seciliGrupFiltre = "Tümü";

  final List<String> _birimListesi = ["adet", "gr", "kg", "ton", "top"];

  @override
  void dispose() {
    _aramaController.dispose();
    _aramaNotifier.dispose();
    super.dispose();
  }

  Future<bool> _kutulariHazirla() async {
    if (!Hive.isBoxOpen('stokKutusu')) {
      await Hive.openBox('stokKutusu');
    }
    if (!Hive.isBoxOpen('stokGruplariKutusu')) {
      await Hive.openBox('stokGruplariKutusu');
    }
    if (!Hive.isBoxOpen('kisilerKutusu')) {
      await Hive.openBox('kisilerKutusu');
    }
    return true;
  }

  void _ticariIslemWizardAc({required String islemTuru, StokUrun? seciliUrun}) async {
    final sonuc = await showDialog<bool>(
      context: context,
      builder: (context) => TicariIslemWizardDialog(
        varsayilanIslemTuru: islemTuru,
        seciliUrun: seciliUrun,
        urunKilitli: seciliUrun != null,
      ),
    );

    if (sonuc == true && mounted) {
      setState(() {});
    }
  }

  InputDecoration _inputDekorasyon(
    String label, 
    IconData icon, {
    String? helperText, 
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      suffix: suffix,
      isDense: true,
      helperStyle: TextStyle(color: AppColors.inactive.withValues(alpha: 0.8), fontSize: 9.5),
      labelStyle: const TextStyle(color: AppColors.inactive, fontSize: 11.5),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 17),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.inactive.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.inactive.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }

  void _yeniGrupEkleDialog() {
    final grupAdiController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Stok Grubu Ekle",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: grupAdiController,
            style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
            decoration: _inputDekorasyon("Grup Adı", Icons.category_outlined),
            validator: (val) => val == null || val.trim().isEmpty ? "Grup adı girin" : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: AppColors.inactive, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final Box grupKutusu = Hive.box('stokGruplariKutusu');
                final yeniGrup = grupAdiController.text.trim();
                List<String> gruplar = List<String>.from(grupKutusu.get('gruplar', defaultValue: ['Genel']));
                if (!gruplar.contains(yeniGrup)) {
                  gruplar.add(yeniGrup);
                  await grupKutusu.put('gruplar', gruplar);

                  final esitlemeServisi = YedekEsitlemeServisi();
                  await esitlemeServisi.yerelZamanDamgasiGuncelle();
                  esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((e) => false);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text("Ekle", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _grupYonetimiDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Box grupKutusu = Hive.box('stokGruplariKutusu');
            List<String> gruplar = List<String>.from(grupKutusu.get('gruplar', defaultValue: ['Genel']));

            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Stok Gruplarını Yönet",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: gruplar.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final grup = gruplar[index];
                    final bool isGenel = grup == "Genel";

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        grup,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isGenel ? FontWeight.bold : FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      trailing: isGenel
                          ? const Text("(Varsayılan)", style: TextStyle(fontSize: 10, color: AppColors.inactive))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                  onPressed: () => _grupDuzenleDialog(grup, () => setDialogState(() {})),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                  onPressed: () => _grupSilDialog(grup, () => setDialogState(() {})),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kapat", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _grupDuzenleDialog(String eskiGrupAdi, VoidCallback onGuncellendi) {
    final controller = TextEditingController(text: eskiGrupAdi);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Grubu Düzenle", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
            decoration: _inputDekorasyon("Yeni Grup Adı", Icons.category_outlined),
            validator: (val) => val == null || val.trim().isEmpty ? "Grup adı boş olamaz" : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: AppColors.inactive, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.6), 
              foregroundColor: Colors.white
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final yeniGrupAdi = controller.text.trim();
                if (yeniGrupAdi != eskiGrupAdi) {
                  final Box grupKutusu = Hive.box('stokGruplariKutusu');
                  List<String> gruplar = List<String>.from(grupKutusu.get('gruplar', defaultValue: ['Genel']));
                  
                  int idx = gruplar.indexOf(eskiGrupAdi);
                  if (idx != -1) {
                    gruplar[idx] = yeniGrupAdi;
                    await grupKutusu.put('gruplar', gruplar);

                    final Box stokKutusu = Hive.box('stokKutusu');
                    for (var key in stokKutusu.keys) {
                      final urunMap = Map<dynamic, dynamic>.from(stokKutusu.get(key));
                      if (urunMap['stokGrubu'] == eskiGrupAdi) {
                        urunMap['stokGrubu'] = yeniGrupAdi;
                        await stokKutusu.put(key, urunMap);
                      }
                    }

                    final esitlemeServisi = YedekEsitlemeServisi();
                    await esitlemeServisi.yerelZamanDamgasiGuncelle();
                    esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((e) => false);
                  }
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                onGuncellendi();
                setState(() {});
              }
            },
            child: const Text("Kaydet", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _grupSilDialog(String grupAdi, VoidCallback onGuncellendi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Grup Silinsin mi?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Text("'$grupAdi' grubu silinecek ve bu gruptaki ürünler 'Genel' grubuna aktarılacaktır.", style: const TextStyle(fontSize: 12.5, color: AppColors.primary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç", style: TextStyle(color: AppColors.inactive, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              final Box grupKutusu = Hive.box('stokGruplariKutusu');
              List<String> gruplar = List<String>.from(grupKutusu.get('gruplar', defaultValue: ['Genel']));
              gruplar.remove(grupAdi);
              await grupKutusu.put('gruplar', gruplar);

              final Box stokKutusu = Hive.box('stokKutusu');
              for (var key in stokKutusu.keys) {
                final urunMap = Map<dynamic, dynamic>.from(stokKutusu.get(key));
                if (urunMap['stokGrubu'] == grupAdi) {
                  urunMap['stokGrubu'] = "Genel";
                  await stokKutusu.put(key, urunMap);
                }
              }

              if (_seciliGrupFiltre == grupAdi) {
                _seciliGrupFiltre = "Tümü";
              }

              final esitlemeServisi = YedekEsitlemeServisi();
              await esitlemeServisi.yerelZamanDamgasiGuncelle();
              esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((e) => false);

              if (!context.mounted) return;
              Navigator.pop(context);
              onGuncellendi();
              setState(() {});
            },
            child: const Text("Sil", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _urunEkleVeyaDuzenle({StokUrun? mevcutUrun}) {
    final formKey = GlobalKey<FormState>();
    final urunAdiController = TextEditingController(text: mevcutUrun?.urunAdi ?? "");
    final miktarController = TextEditingController(
      text: mevcutUrun != null ? (mevcutUrun.birim == "adet" ? mevcutUrun.mevcutStok.round().toString() : mevcutUrun.mevcutStok.toString()) : "",
    );
    final alisFiyatiController = TextEditingController(
      text: mevcutUrun != null && (mevcutUrun.birimAlisFiyati ?? 0) > 0 
          ? formatPara(mevcutUrun.birimAlisFiyati!) 
          : "",
    );
    final satisFiyatiController = TextEditingController(
      text: mevcutUrun != null && mevcutUrun.birimFiyat > 0 ? formatPara(mevcutUrun.birimFiyat) : "",
    );
    final kritikStokController = TextEditingController(
      text: mevcutUrun != null ? mevcutUrun.kritikStokSeviyesi.toString() : "5",
    );

    String seciliBirim = (mevcutUrun != null && _birimListesi.contains(mevcutUrun.birim)) 
        ? mevcutUrun.birim 
        : "adet";

    final Box grupKutusu = Hive.box('stokGruplariKutusu');
    List<String> mevcutGruplar = List<String>.from(grupKutusu.get('gruplar', defaultValue: ['Genel']));
    
    String seciliGrup = (mevcutUrun != null && mevcutGruplar.contains(mevcutUrun.stokGrubu))
        ? mevcutUrun.stokGrubu ?? "Genel"
        : (mevcutGruplar.isNotEmpty ? mevcutGruplar.first : "Genel");

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      mevcutUrun == null ? Icons.add_box_rounded : Icons.edit_note_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    mevcutUrun == null ? "Yeni Stok Ekle" : "Stok Bilgilerini Düzenle",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: seciliGrup,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                        decoration: _inputDekorasyon("Stok Grubu", Icons.category_outlined),
                        items: mevcutGruplar.map((grup) {
                          return DropdownMenuItem(value: grup, child: Text(grup));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => seciliGrup = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: urunAdiController,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                        decoration: _inputDekorasyon("Ürün Adı", Icons.inventory_2_outlined),
                        validator: (val) => val == null || val.trim().isEmpty ? "Ürün adı giriniz" : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: seciliBirim,
                              style: const TextStyle(fontSize: 12, color: AppColors.primary),
                              decoration: _inputDekorasyon("Miktar Türü", Icons.straighten_rounded),
                              selectedItemBuilder: (BuildContext context) {
                                return _birimListesi.map<Widget>((String item) {
                                  return Text(item, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold));
                                }).toList();
                              },
                              items: _birimListesi.map((b) {
                                return DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12, color: AppColors.primary)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    seciliBirim = val;
                                    if (seciliBirim == "adet") {
                                      final doubleVal = double.tryParse(miktarController.text.replaceAll(',', '.')) ?? 0;
                                      miktarController.text = doubleVal.round().toString();
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: miktarController,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                              keyboardType: seciliBirim == "adet"
                                  ? TextInputType.number
                                  : const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: seciliBirim == "adet"
                                  ? [FilteringTextInputFormatter.digitsOnly]
                                  : [FilteringTextInputFormatter.allow(RegExp(r'^\d*[\,\.]?\d*'))],
                              decoration: _inputDekorasyon("Miktar", Icons.numbers_rounded),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return "Miktar girin";
                                if (double.tryParse(val.replaceAll(',', '.')) == null) return "Geçersiz";
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: alisFiyatiController,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                              keyboardType: TextInputType.number,
                              inputFormatters: [BinlikParaFormatter()],
                              decoration: _inputDekorasyon(
                                "Alış Fiyatı", 
                                Icons.call_received_rounded,
                                suffix: const Text("₺", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: satisFiyatiController,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                              keyboardType: TextInputType.number,
                              inputFormatters: [BinlikParaFormatter()],
                              decoration: _inputDekorasyon(
                                "Satış Fiyatı", 
                                Icons.call_made_rounded,
                                suffix: const Text("₺", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: kritikStokController,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDekorasyon(
                          "Kritik Stok Uyarısı", 
                          Icons.warning_amber_rounded, 
                          helperText: "Stok bu seviyeye inince uyarı verir"
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("İptal", style: TextStyle(color: AppColors.inactive, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text("Kaydet", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final Box stokKutusu = Hive.box('stokKutusu');
                      final temizAlisFiyati = alisFiyatiController.text.replaceAll('.', '');
                      final temizSatisFiyati = satisFiyatiController.text.replaceAll('.', '');

                      final yeniUrun = StokUrun(
                        id: mevcutUrun?.id ?? "${DateTime.now().millisecondsSinceEpoch}_stok",
                        urunAdi: urunAdiController.text.trim(),
                        birim: seciliBirim,
                        mevcutStok: double.parse(miktarController.text.replaceAll(',', '.')),
                        birimAlisFiyati: double.tryParse(temizAlisFiyati) ?? 0.0,
                        birimFiyat: double.tryParse(temizSatisFiyati) ?? 0.0,
                        stokGrubu: seciliGrup,
                        kritikStokSeviyesi: double.tryParse(kritikStokController.text.replaceAll(',', '.')) ?? 5.0,
                        kayitTarihi: mevcutUrun?.kayitTarihi,
                        sonIslemTarihi: DateTime.now(),
                      );

                      await stokKutusu.put(yeniUrun.id, yeniUrun.toMap());

                      final esitlemeServisi = YedekEsitlemeServisi();
                      await esitlemeServisi.yerelZamanDamgasiGuncelle();
                      esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((e) => false);

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _urunSil(StokUrun urun) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              "Stok Kaydı Silinsin mi?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
            ),
          ],
        ),
        content: Text(
          "'${urun.urunAdi}' veritabanından kalıcı olarak silinecektir.",
          style: const TextStyle(fontSize: 12.5, color: AppColors.textOnBackground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç", style: TextStyle(color: AppColors.inactive, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final Box stokKutusu = Hive.box('stokKutusu');
              await stokKutusu.delete(urun.id);

              final esitlemeServisi = YedekEsitlemeServisi();
              await esitlemeServisi.yerelZamanDamgasiGuncelle();
              esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((e) => false);

              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Sil", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _kutulariHazirla(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Text("Stok verileri yüklenirken bir hata oluştu.", style: TextStyle(color: AppColors.error)),
            ),
          );
        }

        final Box grupKutusu = Hive.box('stokGruplariKutusu');
        List<String> gruplar = ["Tümü", ...List<String>.from(grupKutusu.get('gruplar', defaultValue: ['Genel']))];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: ValueListenableBuilder(
            valueListenable: Hive.box('stokKutusu').listenable(),
            builder: (context, Box stokKutusu, _) {
              final tumUrunler = stokKutusu.values
                  .map((map) => StokUrun.fromMap(Map<dynamic, dynamic>.from(map)))
                  .toList();

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: AppColors.cardBackground,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.inactive.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: _yeniGrupEkleDialog,
                                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                                  label: const Text("Grup Ekle", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: "Grupları Düzenle / Sil",
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(32, 32),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: _grupYonetimiDialog,
                                icon: const Icon(Icons.folder_copy_outlined, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.6),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => _urunEkleVeyaDuzenle(),
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text("Ürün Ekle", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 30,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: gruplar.length,
                            itemBuilder: (context, index) {
                              final grup = gruplar[index];
                              final secili = _seciliGrupFiltre == grup;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(grup),
                                  selected: secili,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: secili ? Colors.white : AppColors.primary,
                                    fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  selectedColor: AppColors.primary.withValues(alpha: 0.6),
                                  backgroundColor: AppColors.background,
                                  onSelected: (_) => setState(() => _seciliGrupFiltre = grup),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  showCheckmark: false,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.inactive.withValues(alpha: 0.18)),
                          ),
                          child: TextField(
                            controller: _aramaController,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                            decoration: const InputDecoration(
                              hintText: "Ürün ara...",
                              hintStyle: TextStyle(color: AppColors.inactive, fontSize: 12),
                              prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (val) => _aramaNotifier.value = val,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _aramaNotifier,
                      builder: (context, aramaMetni, _) {
                        final filtrelenmisUrunler = tumUrunler.where((u) {
                          final aramaUygun = u.urunAdi.toLowerCase().contains(aramaMetni.toLowerCase());
                          final grupUygun = _seciliGrupFiltre == "Tümü" || (u.stokGrubu ?? "Genel") == _seciliGrupFiltre;
                          return aramaUygun && grupUygun;
                        }).toList();

                        if (filtrelenmisUrunler.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.inactive),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  aramaMetni.isEmpty 
                                      ? "Henüz bu grupta kayıtlı ürün bulunmuyor." 
                                      : "Aramanıza uygun ürün bulunamadı.",
                                  style: const TextStyle(color: AppColors.inactive, fontSize: 12.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: filtrelenmisUrunler.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final urun = filtrelenmisUrunler[index];
                            final bool kritikAlti = urun.mevcutStok <= urun.kritikStokSeviyesi;

                            return Card(
                              color: AppColors.cardBackground,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: kritikAlti 
                                      ? AppColors.error.withValues(alpha: 0.5) 
                                      : AppColors.inactive.withValues(alpha: 0.2),
                                  width: kritikAlti ? 1.2 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      urun.urunAdi,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.primary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (kritikAlti) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.error.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        "KRİTİK",
                                                        style: TextStyle(
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.error,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Grup: ${urun.stokGrubu ?? 'Genel'}",
                                                style: const TextStyle(fontSize: 10, color: AppColors.inactive),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "Kalan: ${urun.birim == 'adet' ? urun.mevcutStok.round() : urun.mevcutStok} ${urun.birim}",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: kritikAlti ? AppColors.error : AppColors.primary,
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "₺${formatPara(urun.birimAlisFiyati ?? 0.0)}",
                                                  style: const TextStyle(
                                                    fontSize: 10.5, 
                                                    fontWeight: FontWeight.w600, 
                                                    color: AppColors.borc,
                                                  ),
                                                ),
                                                const Text(
                                                  " / ",
                                                  style: TextStyle(
                                                    fontSize: 10.5, 
                                                    fontWeight: FontWeight.bold, 
                                                    color: AppColors.inactive,
                                                  ),
                                                ),
                                                Text(
                                                  "₺${formatPara(urun.birimFiyat)}",
                                                  style: const TextStyle(
                                                    fontSize: 10.5, 
                                                    fontWeight: FontWeight.w600, 
                                                    color: AppColors.alacak,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 12, thickness: 0.5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                              onPressed: () => _urunEkleVeyaDuzenle(mevcutUrun: urun),
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                              onPressed: () => _urunSil(urun),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.borc,
                                                side: BorderSide(color: AppColors.borc.withValues(alpha: 0.5), width: 1),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              onPressed: () => _ticariIslemWizardAc(islemTuru: 'alis', seciliUrun: urun),
                                              icon: const Icon(Icons.local_shipping_outlined, size: 13),
                                              label: const Text("Ürün Al", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 6),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.alacak.withValues(alpha: 0.5),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              onPressed: () => _ticariIslemWizardAc(islemTuru: 'satis', seciliUrun: urun),
                                              icon: const Icon(Icons.shopping_bag_outlined, size: 13),
                                              label: const Text("Ürün Sat", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
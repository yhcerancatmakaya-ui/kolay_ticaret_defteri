/* 
  🛡️ TELİF HAKKI VE HAK SAHİPLİĞİ MÜHÜRÜ (COPYRIGHT SHIELD)
  ========================================================================
  Copyright (c) 2026 Hasan CERAN. Tüm hakları saklıdır.
  ========================================================================
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'modeller.dart';
import 'yedek_esitleme_servisi.dart';
import 'tema_renk_paleti.dart';
import 'yardimcilar.dart';

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

class TicariIslemWizardDialog extends StatefulWidget {
  final Kisi? seciliKisi;
  final StokUrun? seciliUrun;
  final String? varsayilanIslemTuru;
  final bool kisiKilitli;
  final bool urunKilitli;

  const TicariIslemWizardDialog({
    super.key,
    this.seciliKisi,
    this.seciliUrun,
    this.varsayilanIslemTuru,
    this.kisiKilitli = false,
    this.urunKilitli = false,
  });

  @override
  State<TicariIslemWizardDialog> createState() => _TicariIslemWizardDialogState();
}

class _TicariIslemWizardDialogState extends State<TicariIslemWizardDialog> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  final _miktarController = TextEditingController(text: '1');
  final _birimFiyatController = TextEditingController();
  final _toplamTutarController = TextEditingController();
  final _vadeSayisiController = TextEditingController(text: '1');

  String _islemTuru = 'satis';
  bool _isVadeli = false;
  bool _ortakHesabinaAktarilsinMi = false;
  Kisi? _seciliKisi;
  StokUrun? _seciliUrun;
  DateTime _islemTarihi = DateTime.now();

  List<Kisi> _tumKisiler = [];
  List<StokUrun> _urunlerListesi = [];
  final List<Map<String, dynamic>> _taksitListesi = [];

  double _parseFormattedNumber(String text) {
    if (text.isEmpty) return 0.0;
    String cleanText = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleanText) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _seciliKisi = widget.seciliKisi;
    _seciliUrun = widget.seciliUrun;
    if (widget.varsayilanIslemTuru != null) {
      _islemTuru = widget.varsayilanIslemTuru!;
    }

    _verileriYukle();

    if (_seciliUrun != null) {
      _fiyatiVarsayilanAyarla();
    }
  }

  void _verileriYukle() {
    try {
      final kisilerKutusu = Hive.box('defterKutusu');
      final stokKutusu = Hive.box('stokKutusu');

      final List<Kisi> kisiler = [];
      for (var item in kisilerKutusu.values) {
        if (item is Kisi) {
          kisiler.add(item);
        } else if (item is Map) {
          kisiler.add(Kisi.fromMap(Map<String, dynamic>.from(item)));
        }
      }

      final List<StokUrun> urunler = [];
      for (var item in stokKutusu.values) {
        if (item is StokUrun) {
          urunler.add(item);
        } else if (item is Map) {
          urunler.add(StokUrun.fromMap(Map<String, dynamic>.from(item)));
        }
      }

      setState(() {
        _tumKisiler = kisiler;
        _urunlerListesi = urunler;
      });
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
    }
  }

  List<Kisi> get _filtrelenmisKisiler {
    if (_tumKisiler.isEmpty) return [];
    final bool satisMi = _islemTuru == 'satis';
    return _tumKisiler.where((k) => satisMi ? k.isMusteri : k.isTedarikci).toList();
  }

  void _fiyatiVarsayilanAyarla() {
    if (_seciliUrun == null) return;
    double fiyat = 0.0;
    if (_islemTuru == 'satis') {
      fiyat = _seciliUrun!.birimFiyat;
    } else {
      fiyat = _seciliUrun!.birimAlisFiyati ?? _seciliUrun!.birimFiyat;
    }
    _birimFiyatController.text = formatPara(fiyat);
    _miktarKontrolEtVeHesapla(_miktarController.text);
  }

  void _uyariGoster(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mesaj,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _miktarKontrolEtVeHesapla(String val) {
    if (val.trim().isEmpty) {
      _hesaplaToplamTutar();
      return;
    }

    final cleanVal = val.replaceAll(',', '.');
    final double? miktar = double.tryParse(cleanVal);

    if (miktar == null) {
      _uyariGoster("Geçersiz bir miktar girdiniz.");
      _miktarController.clear();
      _hesaplaToplamTutar();
      return;
    }

    if (_islemTuru == 'satis' && _seciliUrun != null) {
      final double stok = _seciliUrun!.mevcutStok;
      if (miktar > stok) {
        final String stokMetin = (stok % 1 == 0) ? stok.toInt().toString() : stok.toString();
        _uyariGoster("Satılmak istenen miktar stoktaki miktardan ($stokMetin ${_seciliUrun!.birim}) fazla olamaz!");
        _miktarController.clear();
        _hesaplaToplamTutar();
        return;
      }
    }

    _hesaplaToplamTutar();
  }

  void _hesaplaToplamTutar() {
    double miktar = double.tryParse(_miktarController.text.replaceAll(',', '.')) ?? 0;
    double birimFiyat = _parseFormattedNumber(_birimFiyatController.text);
    double toplam = miktar * birimFiyat;

    if (toplam > 1000000000) {
      toplam = 1000000000;
    }

    _toplamTutarController.text = formatPara(toplam);
    if (_isVadeli) _taksitleriOlustur();
  }

  void _taksitleriOlustur() {
    int taksitSayisi = int.tryParse(_vadeSayisiController.text) ?? 1;
    if (taksitSayisi < 1) taksitSayisi = 1;

    double toplamTutar = _parseFormattedNumber(_toplamTutarController.text);
    double birimTaksit = (toplamTutar / taksitSayisi);
    birimTaksit = double.parse(birimTaksit.toStringAsFixed(2));

    double fark = toplamTutar - (birimTaksit * taksitSayisi);
    fark = double.parse(fark.toStringAsFixed(2));

    _taksitListesi.clear();

    for (int i = 0; i < taksitSayisi; i++) {
      DateTime hesaplananTarih = DateTime(
        _islemTarihi.year,
        _islemTarihi.month + i + 1,
        _islemTarihi.day,
      );

      double taksitTutari = (i == 0) ? (birimTaksit + fark) : birimTaksit;

      _taksitListesi.add({
        'taksitNo': i + 1,
        'tarih': hesaplananTarih,
        'tutar': taksitTutari,
        'controller': TextEditingController(
          text: formatPara(taksitTutari),
        ),
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _miktarController.dispose();
    _birimFiyatController.dispose();
    _toplamTutarController.dispose();
    _vadeSayisiController.dispose();
    for (var taksit in _taksitListesi) {
      (taksit['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ticari İşlem Kaydı',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.inactive, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildCustomStepHeader(),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildCurrentStepContent(),
                ),
              ),
              const SizedBox(height: 12),
              _buildBottomNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomStepHeader() {
    return Row(
      children: [
        Expanded(child: _buildStepHeaderItem(0, "1. Kişi ve İşlem")),
        const SizedBox(width: 4),
        Expanded(child: _buildStepHeaderItem(1, "2. Ürün")),
        const SizedBox(width: 4),
        Expanded(child: _buildStepHeaderItem(2, "3. Ödeme")),
      ],
    );
  }

  Widget _buildStepHeaderItem(int index, String title) {
    final bool isCurrent = _currentStep == index;
    final bool isDone = _currentStep > index;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary
                : (isDone ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent ? AppColors.primary : AppColors.inactive.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? Colors.white : (isDone ? AppColors.primary : AppColors.inactive),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Content();
      case 1:
        return _buildStep2Content();
      case 2:
        return _buildStep3Content();
      default:
        return Container();
    }
  }

  Widget _buildStep1Content() {
    final kisiler = _filtrelenmisKisiler;

    if (widget.kisiKilitli && _seciliKisi != null && !kisiler.any((k) => k.id == _seciliKisi!.id)) {
      kisiler.insert(0, _seciliKisi!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.kisiKilitli
                    ? null
                    : () {
                        setState(() {
                          _islemTuru = 'satis';
                          if (_seciliKisi != null && !_filtrelenmisKisiler.any((k) => k.id == _seciliKisi!.id)) {
                            _seciliKisi = null;
                          }
                          _fiyatiVarsayilanAyarla();
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: Opacity(
                  opacity: _islemTuru == 'satis' ? 1.0 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _islemTuru == 'satis' ? Colors.green.shade50 : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _islemTuru == 'satis' ? Colors.green : AppColors.inactive.withValues(alpha: 0.2),
                        width: _islemTuru == 'satis' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.add_shopping_cart, color: _islemTuru == 'satis' ? Colors.green : AppColors.inactive, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          'Müşteriye ürün satışı',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _islemTuru == 'satis' ? FontWeight.bold : FontWeight.normal,
                            color: _islemTuru == 'satis' ? Colors.green.shade800 : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: widget.kisiKilitli
                    ? null
                    : () {
                        setState(() {
                          _islemTuru = 'alis';
                          if (_seciliKisi != null && !_filtrelenmisKisiler.any((k) => k.id == _seciliKisi!.id)) {
                            _seciliKisi = null;
                          }
                          _fiyatiVarsayilanAyarla();
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: Opacity(
                  opacity: _islemTuru == 'alis' ? 1.0 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _islemTuru == 'alis' ? Colors.blue.shade50 : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _islemTuru == 'alis' ? Colors.blue : AppColors.inactive.withValues(alpha: 0.2),
                        width: _islemTuru == 'alis' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.local_shipping, color: _islemTuru == 'alis' ? Colors.blue : AppColors.inactive, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          'Tedarikçiden ürün alışı',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _islemTuru == 'alis' ? FontWeight.bold : FontWeight.normal,
                            color: _islemTuru == 'alis' ? Colors.blue.shade800 : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Kisi>(
          initialValue: kisiler.contains(_seciliKisi) ? _seciliKisi : null,
          isExpanded: true,
          style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
          decoration: _inputDekorasyon(
            _islemTuru == 'satis' ? 'Müşteri' : 'Tedarikçi',
            Icons.person_outline_rounded,
          ),
          disabledHint: _seciliKisi != null
              ? Text(
                  "${_seciliKisi!.isim} (Sabit)",
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
              : null,
          hint: Text(
            kisiler.isEmpty
                ? (_islemTuru == 'satis' ? 'Kayıtlı müşteri bulunamadı' : 'Kayıtlı tedarikçi bulunamadı')
                : 'Kişi seçiniz...',
            style: const TextStyle(fontSize: 12, color: AppColors.inactive),
          ),
          items: kisiler.map((kisi) {
            return DropdownMenuItem<Kisi>(
              value: kisi,
              child: Text(
                kisi.isim.isNotEmpty ? kisi.isim : 'İsimsiz Kişi',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: widget.kisiKilitli ? null : (val) => setState(() => _seciliKisi = val),
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      children: [
        InkWell(
          onTap: widget.urunKilitli ? null : () => _urunSecimSecenegiGoster(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inactive.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _seciliUrun != null ? _seciliUrun!.urunAdi : 'Ürün Seçiniz...',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _seciliUrun != null ? AppColors.primary : AppColors.inactive,
                        ),
                      ),
                      if (_seciliUrun != null)
                        Text(
                          "Stok: ${_seciliUrun!.mevcutStok % 1 == 0 ? _seciliUrun!.mevcutStok.toInt() : _seciliUrun!.mevcutStok} ${_seciliUrun!.birim}",
                          style: const TextStyle(fontSize: 11, color: AppColors.inactive),
                        ),
                    ],
                  ),
                ),
                if (!widget.urunKilitli) const Icon(Icons.arrow_drop_down, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _miktarController,
                style: const TextStyle(fontSize: 12),
                decoration: _inputDekorasyon('Miktar (${_seciliUrun?.birim ?? "Adet"})', Icons.numbers),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (val) => _miktarKontrolEtVeHesapla(val),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _birimFiyatController,
                style: const TextStyle(fontSize: 12),
                inputFormatters: [BinlikParaFormatter()],
                decoration: _inputDekorasyon('Birim Fiyat', Icons.payments_outlined, suffixText: ' ₺'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _hesaplaToplamTutar(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _toplamTutarController,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          decoration: _inputDekorasyon('Toplam Tutar', Icons.calculate_outlined, suffixText: ' ₺'),
          readOnly: true,
        ),
      ],
    );
  }

  Widget _buildStep3Content() {
    final bool isOrtak = _seciliKisi?.isOrtak ?? false;

    String ortakSoruMetni = "";
    if (isOrtak && !_isVadeli) {
      if (_islemTuru == 'satis') {
        ortakSoruMetni = "Bu peşin ürün satışı kişinin ortak hesabından düşülsün mü?";
      } else {
        ortakSoruMetni = "Bu peşin ürün alışı kişinin ortak hesabına eklensin mi?";
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<bool>(
          groupValue: _isVadeli,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _isVadeli = val;
                if (_isVadeli) {
                  _taksitleriOlustur();
                  _ortakHesabinaAktarilsinMi = false;
                }
              });
            }
          },
          child: Row(
            children: const [
              Expanded(
                child: RadioListTile<bool>(
                  title: Text('Peşin Ödeme', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: Text('Vadeli Ödeme', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final secilen = await showDatePicker(
              context: context,
              initialDate: _islemTarihi,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              locale: const Locale('tr', 'TR'),
            );
            if (secilen != null) {
              setState(() {
                _islemTarihi = secilen;
                if (_isVadeli) _taksitleriOlustur();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inactive.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("İşlem Tarihi:", style: TextStyle(fontSize: 11.5, color: AppColors.inactive)),
                Text(
                  "${_islemTarihi.day.toString().padLeft(2, '0')}.${_islemTarihi.month.toString().padLeft(2, '0')}.${_islemTarihi.year}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        if (isOrtak && !_isVadeli) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              title: Text(
                ortakSoruMetni,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              value: _ortakHesabinaAktarilsinMi,
              onChanged: (val) => setState(() => _ortakHesabinaAktarilsinMi = val ?? false),
            ),
          ),
        ],
        if (_isVadeli) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _vadeSayisiController,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDekorasyon('Taksit / Vade Sayısı', Icons.format_list_numbered),
            keyboardType: TextInputType.number,
            onChanged: (_) => _taksitleriOlustur(),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _taksitListesi.length,
              itemBuilder: (context, index) {
                final item = _taksitListesi[index];
                final DateTime dt = item['tarih'];
                final String tarihStr = "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          final secilenTarih = await showDatePicker(
                            context: context,
                            initialDate: dt,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            locale: const Locale('tr', 'TR'),
                          );
                          if (secilenTarih != null) {
                            setState(() {
                              item['tarih'] = secilenTarih;
                            });
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              "${item['taksitNo']}. Taksit ($tarihStr): ",
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextFormField(
                          controller: item['controller'],
                          style: const TextStyle(fontSize: 11.5),
                          inputFormatters: [BinlikParaFormatter()],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            suffixText: ' ₺',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          TextButton.icon(
            onPressed: () => setState(() => _currentStep -= 1),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text("Geri", style: TextStyle(fontSize: 12)),
          )
        else
          const SizedBox.shrink(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            if (_currentStep < 2) {
              if (_currentStep == 0 && _seciliKisi == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_islemTuru == 'satis' ? 'Lütfen bir müşteri seçin.' : 'Lütfen bir tedarikçi seçin.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              if (_currentStep == 1) {
                if (_seciliUrun == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen bir ürün seçin.'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                final double miktar = double.tryParse(_miktarController.text.replaceAll(',', '.')) ?? 0;
                if (miktar <= 0) {
                  _uyariGoster("Lütfen geçerli bir ürün miktarı giriniz.");
                  return;
                }
              }
              setState(() => _currentStep += 1);
            } else {
              _kaydet();
            }
          },
          icon: Icon(_currentStep == 2 ? Icons.check : Icons.arrow_forward, size: 16),
          label: Text(_currentStep == 2 ? "İşlemi Kaydet" : "Devam Et", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _urunSecimSecenegiGoster() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String aramaMetni = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtrelenmis = _urunlerListesi.where((u) {
              return u.urunAdi.toLowerCase().contains(aramaMetni.toLowerCase());
            }).toList();

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDekorasyon('Ürün Adı ile Ara...', Icons.search),
                    onChanged: (val) {
                      setModalState(() {
                        aramaMetni = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtrelenmis.isEmpty
                        ? const Center(child: Text("Ürün bulunamadı.", style: TextStyle(fontSize: 12, color: AppColors.inactive)))
                        : ListView.builder(
                            itemCount: filtrelenmis.length,
                            itemBuilder: (context, index) {
                              final urun = filtrelenmis[index];
                              return ListTile(
                                dense: true,
                                title: Text(urun.urunAdi, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                subtitle: Text("Stok: ${urun.mevcutStok % 1 == 0 ? urun.mevcutStok.toInt() : urun.mevcutStok} ${urun.birim}", style: const TextStyle(fontSize: 10.5)),
                                trailing: Text("${formatPara(urun.birimFiyat)} ₺", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                onTap: () {
                                  setState(() {
                                    _seciliUrun = urun;
                                    _fiyatiVarsayilanAyarla();
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDekorasyon(String label, IconData icon, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      isDense: true,
      labelStyle: const TextStyle(color: AppColors.inactive, fontSize: 11),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 16),
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

  Future<void> _kaydet() async {
    if (_formKey.currentState!.validate()) {
      if (_seciliKisi == null || _seciliUrun == null) return;

      final double miktar = double.tryParse(_miktarController.text.replaceAll(',', '.')) ?? 1.0;
      final double birimFiyat = _parseFormattedNumber(_birimFiyatController.text);
      final double toplamTutar = miktar * birimFiyat;

      IslemTuru nihaiTur = (_islemTuru == 'satis') 
          ? IslemTuru.alacagimiz 
          : IslemTuru.borcumuz;

      List<Taksit>? taksitler;
      DateTime sonVade = _islemTarihi;

      if (_isVadeli && _taksitListesi.isNotEmpty) {
        taksitler = _taksitListesi.map((item) {
          final double tutar = _parseFormattedNumber((item['controller'] as TextEditingController).text);
          return Taksit(vadeTarihi: item['tarih'] as DateTime, vadeTutari: tutar);
        }).toList();
        sonVade = taksitler.last.vadeTarihi;
      }

      final String anaIslemId = DateTime.now().millisecondsSinceEpoch.toString();

      // 1. Ana Ticari İşlemi Kaydet
      final basarili = await urunIslemiKaydet(
        customIslemId: anaIslemId,
        kisiId: _seciliKisi!.id,
        stokUrunId: _seciliUrun!.id,
        miktar: miktar,
        birimFiyat: birimFiyat,
        islemTuru: nihaiTur,
        vadeliMi: _isVadeli,
        islemTarihi: _islemTarihi,
        vadeTarihi: sonVade,
        taksitler: taksitler,
        aciklama: "${_seciliUrun!.urunAdi} ($miktar ${_seciliUrun!.birim})",
      );

      // 2. Eğer Peşin İşlem Yapıldıysa Bağlı Ödemeyi Ekleyip Kartı Kapatıyoruz
      if (basarili && !_isVadeli) {
        final kisilerKutusu = Hive.box('defterKutusu');
        final rawKisiMap = kisilerKutusu.get(_seciliKisi!.id);
        if (rawKisiMap != null) {
          final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(rawKisiMap));
          if (kisi.islemler.isNotEmpty) {
            final eklenenIslem = kisi.islemler.last;
            
            final pesinOdeme = TicariIslem(
              id: "${DateTime.now().millisecondsSinceEpoch}_pesin",
              kategori: IslemKategorisi.gunluk,
              tur: (_islemTuru == 'satis') ? IslemTuru.odemeAldik : IslemTuru.odemeYaptik,
              aciklama: "Peşin Ürün Ödemesi",
              kayitTarihi: _islemTarihi,
              tutar: toplamTutar,
              bagliIslemId: anaIslemId,
            );

            eklenenIslem.bagliOdemeler.add(pesinOdeme);
            eklenenIslem.kapandiMi = true;

            await kisilerKutusu.put(_seciliKisi!.id, kisi.toMap());
          }
        }
      }

      // 3. Ortak Sıfatı Varsa ve Peşin İşlem İşaretlendiyse Kasa Hesabına Aktar
      if (basarili && _seciliKisi!.isOrtak && _ortakHesabinaAktarilsinMi && !_isVadeli) {
        final kisilerKutusu = Hive.box('defterKutusu');
        final rawKisiMap = kisilerKutusu.get(_seciliKisi!.id);
        if (rawKisiMap != null) {
          final kisi = Kisi.fromMap(Map<dynamic, dynamic>.from(rawKisiMap));
          
          final IslemTuru kasaTuru = (_islemTuru == 'satis') 
              ? IslemTuru.paraVerildi 
              : IslemTuru.paraAlindi;

          final String kasaAciklamasi = (_islemTuru == 'satis')
              ? "Peşin Ürün Satışı (Kasadan Düşüldü) - ${_seciliUrun!.urunAdi}"
              : "Peşin Ürün Alışı (Kasaya Eklendi) - ${_seciliUrun!.urunAdi}";

          final yeniKasaIslemi = TicariIslem(
            id: "${DateTime.now().millisecondsSinceEpoch}_ortak_kasa",
            kategori: IslemKategorisi.gunluk,
            tur: kasaTuru,
            aciklama: kasaAciklamasi,
            kayitTarihi: _islemTarihi,
            tutar: toplamTutar,
            bagliIslemId: anaIslemId,
          );

          kisi.islemler.add(yeniKasaIslemi);
          await kisilerKutusu.put(_seciliKisi!.id, kisi.toMap());
        }
      }

      // 4. Zaman Damgası Güncelleme ve Bulut Yedeklemesi
      if (basarili) {
        final YedekEsitlemeServisi esitlemeServisi = YedekEsitlemeServisi();
        await esitlemeServisi.yerelZamanDamgasiGuncelle();

        if (mounted) {
          Navigator.pop(context, true);
        }

        // Arka planda garantili yedekleme tetiklenir
        esitlemeServisi.yerelVeriyiGarantiliYedekle().catchError((hata) {
          debugPrint("Bulut senkronizasyonu başarısız (Sistem yerelde çalışıyor): $hata");
          return false;
        });
      }
    }
  }
}
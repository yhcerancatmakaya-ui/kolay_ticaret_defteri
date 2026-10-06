/// 🪙 Para Miktarlarını 3'lü Bloklar Halinde Noktalarla Ayıran ve Kuruş Hanelerini Uçuran Yardımcı Fonksiyon.
/// Bu fonksiyon ortak dosyada tutularak tüm ekranlarda (Ana Ekran, Detay, Liste vb.) mükerrer kod yazılmasını önler.
String formatPara(double miktar) {
  final int tamKisim = miktar.round();
  final String s = tamKisim.abs().toString();
  final List<String> parts = [];
  final int len = s.length;
  
  for (int i = len; i > 0; i -= 3) {
    int start = i - 3;
    if (start < 0) start = 0;
    parts.add(s.substring(start, i));
  }
  
  final String sonuc = parts.reversed.join('.');
  return '${miktar < 0 ? '-' : ''}$sonuc';
}
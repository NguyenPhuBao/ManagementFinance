/// Dòng chữ đọc từ ảnh (OCR) và phép ghép chúng lại theo HÀNG của ảnh. Kiểu thuần — không phụ thuộc gói đọc chữ nào,
/// để mọi luật đọc phía sau (biên lai được chia sẻ, hoá đơn của spike C4) test được bằng dữ liệu dựng tay.
///
/// Dời từ `features/ai_chat/spike/spike_c4.dart` ngày 2026-10-02 khi tính năng chia sẻ biên lai dùng tới nó (spec
/// `2026-10-02-chia-se-bien-lai-design.md`).
library;

/// Một dòng chữ OCR kèm khung của nó trên ảnh (điểm ảnh, gốc ở góc trên trái). Bản thật chép từ
/// `TextLine.boundingBox` của ML Kit sang (`doc_chu_anh_mlkit.dart`).
class DongOcr {
  final String chu;
  final double trai, tren, phai, duoi;
  const DongOcr(this.chu, {required this.trai, required this.tren, required this.phai, required this.duoi});
}

/// Ghép các dòng OCR CÙNG HÀNG thành một dòng chữ, hàng xếp từ trên xuống, trong hàng xếp từ trái sang.
///
/// ⚠️ ML Kit trả `blocks → lines` theo CỘT: hoá đơn hai cột ra cả khối nhãn rồi mới tới khối số, nên nối theo thứ tự
/// trả về thì nhãn *TỔNG CỘNG* không có số nào cạnh nó (đo Realme 2026-10-01: ảnh thử ra tiền khách đưa).
///
/// Hai dòng cùng hàng ⇔ tâm dọc của MỖI dòng nằm trong khung dọc của dòng KIA. Đòi cả hai chiều để một dòng chữ to
/// (tên cửa hàng) không nuốt dòng nhỏ sát dưới nó. Khung là khung thẳng trục — ảnh nghiêng nhiều thì hai đầu một hàng
/// lệch quá nửa chiều cao chữ và phép này tách chúng ra; ảnh chia sẻ từ app ngân hàng thì thẳng, ảnh chụp thì chưa đo.
String ghepDongTheoHang(List<DongOcr> dong) {
  double tam(DongOcr d) => (d.tren + d.duoi) / 2;
  bool cungHang(DongOcr a, DongOcr b) =>
      tam(a) >= b.tren && tam(a) <= b.duoi && tam(b) >= a.tren && tam(b) <= a.duoi;

  final hang = <List<DongOcr>>[];
  for (final d in [...dong]..sort((a, b) => tam(a).compareTo(tam(b)))) {
    // Xét MỌI hàng đã có, không chỉ hàng cuối: ảnh nghiêng thì đầu phải của hàng trên có thể thấp hơn đầu trái hàng dưới.
    final h = hang.where((h) => h.any((x) => cungHang(x, d))).firstOrNull;
    h == null ? hang.add([d]) : h.add(d);
  }
  double dinh(List<DongOcr> h) => h.map((d) => d.tren).reduce((a, b) => a < b ? a : b);
  hang.sort((a, b) => dinh(a).compareTo(dinh(b)));
  return [
    for (final h in hang) ([...h]..sort((a, b) => a.trai.compareTo(b.trai))).map((d) => d.chu).join(' '),
  ].join('\n');
}

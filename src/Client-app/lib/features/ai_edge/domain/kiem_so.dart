/// Bộ kiểm số — điều kiện 10 của mục 13 bản đánh giá: **mọi** con số trong câu
/// phải có trong gói số; sai thì người gọi rơi về mẫu câu.
///
/// Dùng cho cả hai bản diễn giải: mẫu câu (mọi mẫu phải tự qua được bộ kiểm,
/// nếu không P3 sẽ rơi về một câu mà bộ kiểm cũng chặn — có ca test canh ở từng
/// gói số) và SLM (P3). Đây là lớp chắn **duy nhất** giữa mô hình và người
/// dùng, nên nó không được nới vì mô hình lớn hơn (spec mục 4.4).
///
/// Giới hạn cố ý: ngày tháng (`12/09`) cũng là số. Mẫu câu của app không in
/// ngày; nếu sau này gói số cần ngày thì thêm `LoaiSo.ngayThang` chứ đừng nới
/// regex.
library;

import 'goi_so.dart';

class SoTrich {
  final double giaTri;
  final bool laPhanTram;
  const SoTrich(this.giaTri, {required this.laPhanTram});
}

/// Nhóm 1: phần nguyên có chấm nghìn (`2.100.000`) hoặc số trần; nhóm 2: phần
/// thập phân sau **phẩy**; nhóm 3: hậu tố `%`. Không bắt `đ` — có hay không thì
/// cũng là một con số, và `9 đ` với `9 ngày` khác nhau ở **loại** của số liệu
/// chứ không ở cách trích.
final RegExp _mau = RegExp(r'(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?\s*(%)?');

/// Mọi chuỗi số trong [cau], đã chuẩn hoá về `double`.
List<SoTrich> trichSo(String cau) => [
      for (final m in _mau.allMatches(cau))
        SoTrich(
          double.parse(
            '${m.group(1)!.replaceAll('.', '')}.${m.group(2) ?? '0'}',
          ),
          laPhanTram: m.group(3) != null,
        ),
    ];

bool _khop(SoTrich x, SoLieu s) {
  final lech = (x.giaTri - s.soTho).abs();
  return switch (s.loai) {
    // Nửa đồng: đuôi lẻ của double, cùng ngưỡng với đối soát số dư.
    LoaiSo.tien => !x.laPhanTram && lech <= 0.5,
    // Một chữ số thập phân (G2) → sai số làm tròn tối đa 0,05.
    LoaiSo.phanTram => x.laPhanTram && lech <= 0.05,
    LoaiSo.soNgay || LoaiSo.soDem => !x.laPhanTram && lech == 0,
  };
}

/// `true` khi MỌI số trong [cau] khớp một [SoLieu] của [goi]. Câu không có số
/// nào thì lọt — không có gì để bịa.
bool kiemSo(String cau, GoiSo goi) =>
    trichSo(cau).every((x) => goi.soLieu.any((s) => _khop(x, s)));

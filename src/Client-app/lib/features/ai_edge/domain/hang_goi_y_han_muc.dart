/// Tool `goi_y_han_muc` — gợi ý hạn mức MỖI THÁNG theo TÊN danh mục chi (spec
/// bước 2 mục 3.7). Số từ `BudgetRepository.suggestAmount` (cửa sổ nhìn lại
/// cuộn, đã làm tròn lên bội 10.000); hàm này chỉ xếp và cắt.
///
/// Nhãn tổng hợp là `Số ngày gần nhất`: `kiemNhan` đòi câu chứa mọi âm tiết có
/// nghĩa của nhãn, và câu cần nói được là *"suy từ 19 ngày gần nhất"* — đúng
/// luật nhãn form ngân sách (2026-09-21): nói ra số ngày thật khi cửa sổ ngắn.
library;

import 'goi_so.dart';
import 'hang_so_lieu.dart';

class GoiYDanhMuc {
  const GoiYDanhMuc({
    required this.ten,
    required this.mucThang,
    this.hanMucHienTai,
  });

  final String ten;

  /// `suggestAmount` — đã làm tròn.
  final double mucThang;

  /// Hạn mức của ngân sách ĐANG CHẠY cho danh mục; `null` = chưa có ngân sách.
  final double? hanMucHienTai;
}

KetQuaCongCu hangGoiYHanMuc({
  required List<GoiYDanhMuc> goiY,
  required int? soNgayCuaSo,
  required int? soNgayConThieu,
  String? tenDaKhop,
}) {
  if (soNgayCuaSo == null) {
    return KetQuaCongCu(
      hang: const [],
      tongHop: [
        if (soNgayConThieu != null) soNgay('Cần thêm dữ liệu', soNgayConThieu),
      ],
      chuThem: const {'ghi_chu': 'chưa đủ dữ liệu để gợi ý hạn mức'},
    );
  }
  // Mức bằng nhau thì GIỮ thứ tự đầu vào (thứ tự danh mục của repository):
  // `List.sort` của Dart không bảo đảm ổn định, và so tên theo mã ký tự thì
  // "Ăn uống" (Ă = U+0102) đứng sau "Giáo dục" — không phải thứ tự chữ cái.
  final conSo = [
    for (final g in goiY)
      if (g.mucThang > 0) g,
  ];
  final xep = [
    for (var i = 0; i < conSo.length; i++) (i, conSo[i]),
  ]..sort((a, b) {
      final c = b.$2.mucThang.compareTo(a.$2.mucThang);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return KetQuaCongCu(
    hang: [
      for (final (_, g) in xep.take(kToiDaMucMoiGoi))
        HangSoLieu(
          ten: g.ten,
          trangThai: g.hanMucHienTai == null
              ? 'chưa có ngân sách'
              : 'đã có ngân sách',
          canhBao: false,
          soLieu: [
            soTien('Chi trung bình mỗi tháng', g.mucThang, ten: g.ten),
            if (g.hanMucHienTai != null)
              soTien('Hạn mức hiện tại', g.hanMucHienTai!, ten: g.ten),
          ],
        ),
    ],
    tongHop: [soNgay('Số ngày gần nhất', soNgayCuaSo)],
    chuThem: {
      if (tenDaKhop != null && xep.isEmpty)
        'ghi_chu': 'không có khoản chi nào cho danh mục này trong cửa sổ',
    },
    tenLienQuan: [if (tenDaKhop != null) tenDaKhop],
  );
}

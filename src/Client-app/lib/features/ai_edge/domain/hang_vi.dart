/// Tool `danh_sach_vi` — hàng theo TÊN kèm trạng thái và số dư (spec 4b mục 3.4).
/// Trạng thái do `viTinhVaoTong` (một định nghĩa của "ví nào cộng vào tổng") và
/// `viDangAm` (một định nghĩa với gói ví) quyết; lớp này chỉ dịch sang chữ.
library;

import '../../wallet/domain/vi_tinh_vao_tong.dart';
import 'goi_so.dart';
import 'goi_so_vi.dart';
import 'hang_so_lieu.dart';

String chuTrangThaiVi(ViChoGoiSo v) {
  if (viDangAm(v)) return 'đang âm';
  final trongTong = viTinhVaoTong(
    includeInTotal: v.includeInTotal,
    status: v.status,
    isDeleted: v.isDeleted,
  );
  if (trongTong) return 'bình thường';
  // Bị loại khỏi tổng mà cờ includeInTotal vẫn bật → lý do còn lại là lưu trữ.
  return v.includeInTotal ? 'lưu trữ' : 'ngoài tổng';
}

KetQuaCongCu hangVi(List<ViChoGoiSo> vis) {
  // Ví đã xoá mềm không còn là ví của người dùng ở bất kỳ vế nào (G42).
  // Số dư tăng dần nên ví âm đứng đầu — mô hình đọc từ trên xuống.
  final conSong = [
    for (final v in vis)
      if (!v.isDeleted) v,
  ]..sort((x, y) => x.soDu.compareTo(y.soDu));

  var tong = 0.0;
  var soTrong = 0;
  for (final v in conSong) {
    if (viTinhVaoTong(
      includeInTotal: v.includeInTotal,
      status: v.status,
      isDeleted: v.isDeleted,
    )) {
      tong += v.soDu;
      soTrong++;
    }
  }

  final hang = [
    for (final v in conSong.take(kToiDaMucMoiGoi))
      HangSoLieu(
        ten: v.ten,
        trangThai: chuTrangThaiVi(v),
        canhBao: viDangAm(v),
        soLieu: [soTien('Số dư', v.soDu, ten: v.ten)],
      ),
  ];
  return KetQuaCongCu(
    hang: hang,
    tongHop: [soTien('Tổng tài sản', tong), soDem('Số ví', soTrong)],
  );
}

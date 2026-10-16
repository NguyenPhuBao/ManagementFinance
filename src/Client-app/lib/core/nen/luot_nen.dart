/// Bộ điều phối MỘT lượt nền của tự chuyển tiền (spec `2026-10-10-tu-chuyen-tien-chay-nen-design.md` mục 3.3) —
/// thuần, mọi phụ thuộc tiêm vào để test được; bản thật dựng ở `chay_nen.dart`.
library;

import 'lich_nen.dart';

typedef PhienNen = ({int idaccount, String loaiPhien});

class LuotNen {
  LuotNen({
    required this.docPhien,
    required this.coToken,
    required this.datGoi,
    required this.datNhatKy,
    required this.dongBo,
    required this.quet,
    required this.tinhLich,
  });

  /// Phiên đã lưu (quy tắc 2: `idaccount` CHỈ từ phiên, không suy từ SQLite).
  final Future<PhienNen?> Function() docPhien;

  /// Còn access token không — đăng xuất là xoá token, phiên đệm có thể còn sót.
  final Future<bool> Function() coToken;

  /// `GoiRepository.datTaiKhoan` — BẮT BUỘC trước khi quét: `coQuyenNen` trả `true` khi gói chưa có tài khoản, nên
  /// thiếu bước này thì tài khoản Basic được tự trả / tự trích ở nền.
  final Future<void> Function(int idaccount, String loaiPhien) datGoi;

  /// `NhatKyThongBao.datNguonPhien` — `main.dart` gắn từ `AuthBloc`; ở nền không có bloc.
  final void Function(int idaccount) datNhatKy;
  final Future<void> Function(int idaccount) dongBo;
  final Future<int> Function(int idaccount) quet;
  final Future<LichNenKeTiep> Function(int idaccount) tinhLich;

  static const LichNenKeTiep _rong = (moc: null, coTuDong: false);

  Future<LichNenKeTiep> chay() async {
    final PhienNen? phien;
    try {
      if (!await coToken()) return _rong;
      phien = await docPhien();
    } catch (_) {
      return _rong;
    }
    if (phien == null) return _rong;
    final id = phien.idaccount;

    try {
      await datGoi(id, phien.loaiPhien);
      datNhatKy(id);
      // Kéo về TRƯỚC khi quét: thấy máy kia đã trả / đã trích thì khỏi đua; `gopKyTrung` (G87) cũng cần dữ liệu
      // vừa kéo về. Đẩy SAU khi quét: khoản vừa ghi lên server ngay.
      await _nuot(() => dongBo(id));
      await _nuot(() => quet(id));
      await _nuot(() => dongBo(id));
    } catch (_) {
      // Bỏ qua có chủ ý — vẫn trả lịch bên dưới.
    }
    try {
      return await tinhLich(id);
    } catch (_) {
      return (moc: null, coTuDong: true); // không biết thì đừng huỷ lượt định kỳ
    }
  }

  Future<void> _nuot(Future<Object?> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }
}

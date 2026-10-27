import '../data/models/tran_goi.dart';
import '../data/models/trang_thai_goi.dart';
import 'hang_goi.dart';

/// Trần theo gói và câu hỏi *"được tạo thêm không"* — MỘT định nghĩa cho mọi loại (spec Premium 2026-10-06 mục 5.2; từ
/// B1 2026-10-27 trần cột Premium cũng áp). Hàm KHÔNG biết đếm: nó nhận số đang hoạt động (`DemDangHoatDong`, tầng data).
sealed class KetQuaTran {
  const KetQuaTran();
}

class Duoc extends KetQuaTran {
  const Duoc();
}

class Vuot extends KetQuaTran {
  const Vuot({required this.loai, required this.tran, required this.dangCo});
  final LoaiTran loai;
  final int tran;
  final int dangCo;
}

/// Trần đang áp dụng (spec B1 mục 2): bảng đã lưu nếu là của gói đang hiệu lực ([bangDungDuoc]); không thì Premium →
/// không giới hạn, Basic → [TranGoi.macDinh] (G109: Premium hết hạn lúc offline giữ trần của Premium — toàn `null`). MỌI
/// chỗ đọc trần đi qua đây: [conTaoDuoc], cửa route, câu màn Nâng cấp, thẻ Gói — đọc `goi.tran` thô là G109.
TranGoi tranHieuLuc(TrangThaiGoi goi, DateTime now) {
  if (bangDungDuoc(goi, now)) return goi.tran;
  return goi.laPremium(now) ? TranGoi.khongGioiHan : TranGoi.macDinh;
}

/// Trần `null` (không giới hạn) → [Duoc]; `dangCo >= tran` → [Vuot]. Basic HAY Premium đều theo [tranHieuLuc] (B1 — bản
/// trước: Premium luôn [Duoc]). BẰNG trần là vượt (3/3 không tạo cái thứ tư); người bị hạ cấp đang có 5 cũng chỉ bị chặn
/// tạo, không mất gì.
KetQuaTran conTaoDuoc({
  required LoaiTran loai,
  required int dangCo,
  required TrangThaiGoi goi,
  required DateTime now,
}) {
  final tran = tranHieuLuc(goi, now).cua(loai);
  if (tran == null) return const Duoc();
  return dangCo >= tran ? Vuot(loai: loai, tran: tran, dangCo: dangCo) : const Duoc();
}

/// Bảng quyền / trần đã lưu có phải của gói ĐANG hiệu lực không (spec B1 2026-10-27 mục 2): lúc nhận
/// ([TrangThaiGoi.nhanLuc]) và bây giờ cùng là Premium còn hạn, hoặc cùng không. Premium hết hạn lúc offline → bảng lưu là
/// của Premium → `false`.
///
/// ⚠️ Vế đầu (thêm khi lập kế hoạch, ngoài thân spec): Premium **không có hạn** (`hetHan == null` — `premium_expires_at`
/// trống, hoặc chỉ biết `type` của phiên) → `false`. Server coi tài khoản ấy là Basic (`payment.service.js`, `isExpired` khi
/// thiếu hạn) và trả bảng Basic, còn client coi là Premium còn hạn: đọc bảng ấy là mọi thứ Basic tắt hiện *"Đang tạm ngừng"*
/// với người Premium. Giữ hành vi trước B1 (mở hết, không giới hạn) tới B4.
bool bangDungDuoc(TrangThaiGoi goi, DateTime now) =>
    !(goi.loai == LoaiGoi.premium && goi.hetHan == null) && goi.laPremium(goi.nhanLuc) == goi.laPremium(now);

/// Mã trong query `?tran=` của `/premium`.
String maTran(LoaiTran loai) => switch (loai) {
      LoaiTran.vi => 'vi',
      LoaiTran.nganSach => 'ngan_sach',
      LoaiTran.mucTieu => 'muc_tieu',
      LoaiTran.hoaDon => 'hoa_don',
      LoaiTran.danhMucRieng => 'danh_muc_rieng',
    };

LoaiTran? loaiTranTuMa(String? ma) => switch (ma) {
      'vi' => LoaiTran.vi,
      'ngan_sach' => LoaiTran.nganSach,
      'muc_tieu' => LoaiTran.mucTieu,
      'hoa_don' => LoaiTran.hoaDon,
      'danh_muc_rieng' => LoaiTran.danhMucRieng,
      _ => null,
    };

String tenTran(LoaiTran loai) => switch (loai) {
      LoaiTran.vi => 'ví',
      LoaiTran.nganSach => 'ngân sách',
      LoaiTran.mucTieu => 'mục tiêu tiết kiệm',
      LoaiTran.hoaDon => 'hóa đơn định kỳ',
      LoaiTran.danhMucRieng => 'danh mục riêng',
    };

/// Dòng phụ của thẻ Gói (tab Cá nhân): mọi trần có số, `null` (không giới hạn) bị bỏ — *"3 ví · 3 ngân sách · 3 mục
/// tiêu · 3 hoá đơn · 5 danh mục riêng"*. Tên ngắn hơn [tenTran] vì thẻ chật; trong mỗi mục là dấu cách KHÔNG
/// ngắt nên chữ chỉ xuống dòng ở dấu `·` (nghiệm thu OnePlus: *"3 mục / tiêu"*).
String tomTatTran(TranGoi tran) => [
      for (final l in LoaiTran.values)
        if (tran.cua(l) case final n?)
          '$n ${switch (l) {
            LoaiTran.vi => 'ví',
            LoaiTran.nganSach => 'ngân sách',
            LoaiTran.mucTieu => 'mục tiêu',
            LoaiTran.hoaDon => 'hoá đơn',
            LoaiTran.danhMucRieng => 'danh mục riêng',
          }}'.replaceAll(' ', '\u00A0'),
    ].join(' · ');

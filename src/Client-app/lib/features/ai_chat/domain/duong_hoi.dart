/// Luật đường hỏi của màn Trợ lý AI — spec trợ lý online 2026-10-11 §3.1, §3.3.
/// Hàm thuần; trang không giữ `if` nghiệp vụ nào ngoài việc gọi các hàm này.
library;

import '../../ai_edge/domain/chu_de_chan.dart';
import 'su_kien_online.dart';

const String kNguonOnline = 'Trợ lý online';
const String kNguonTrenMay = 'AI trên máy';
const String kGhiChuRoiVeMay = 'máy chủ không phản hồi';
const String kGhiChuGianDoan = 'kết nối gián đoạn';
const String kGhiChuDaDung = 'đã dừng';

/// Cổng 3 của `_hoi`: công tắc online bật ∧ máy có mạng lúc gửi ∧ không phải dữ liệu sống.
bool nenHoiOnline({required bool congTacBat, required bool coMang, required String cauHoi}) =>
    congTacBat && coMang && !chuDeBiChanOnline(cauHoi);

sealed class KetQuaOnline {
  const KetQuaOnline();
}

class HoanTat extends KetQuaOnline {
  const HoanTat();
}

/// Chưa có chữ nào mà lượt online hỏng → cùng câu đi đường trên máy.
class RoiVeMay extends KetQuaOnline {
  const RoiVeMay(this.lyDo);
  final String lyDo;
}

/// Đã có chữ (hoặc người dùng tự dừng) → giữ phần đã hiện, kèm ghi chú.
class GiuPhanDaCo extends KetQuaOnline {
  const GiuPhanDaCo(this.ghiChu);
  final String ghiChu;
}

KetQuaOnline quyetDinhSauOnline({
  required bool daCoChu,
  required SuKienOnline cuoi,
  required bool daDung,
}) {
  if (daDung) return const GiuPhanDaCo(kGhiChuDaDung);
  switch (cuoi) {
    case XongOnline():
      return daCoChu ? const HoanTat() : const RoiVeMay('rỗng');
    case DuPhongOnline(:final reason):
      return daCoChu ? const GiuPhanDaCo(kGhiChuGianDoan) : RoiVeMay(reason);
    case LoiOnline(:final http, :final lyDo):
      return daCoChu ? const GiuPhanDaCo(kGhiChuGianDoan) : RoiVeMay('http=$http $lyDo');
    case ChuOnline():
      // Luồng đóng sau một chữ mà không có done: coi như gián đoạn.
      return daCoChu ? const GiuPhanDaCo(kGhiChuGianDoan) : const RoiVeMay('đóng không done');
  }
}

typedef MucHoiThoai = ({bool cuaToi, String cau, bool laThe});

/// ≤ [toiDa] tin CHỮ gần nhất (bỏ thẻ lệnh tạo), vai `user` / `model`, thứ tự cũ → mới.
/// Không gồm câu đang hỏi — người gọi truyền hội thoại TRƯỚC khi thêm nó.
List<TinLichSu> xepHistory(Iterable<MucHoiThoai> hoiThoai, {int toiDa = 6}) {
  final chu = hoiThoai.where((m) => !m.laThe && m.cau.isNotEmpty).toList();
  final tu = chu.length > toiDa ? chu.length - toiDa : 0;
  return [for (final m in chu.sublist(tu)) (role: m.cuaToi ? 'user' : 'model', text: m.cau)];
}

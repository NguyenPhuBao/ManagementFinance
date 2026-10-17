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

/// Lượt online hỏng, hoặc server báo dự phòng (`DuPhongOnline` — bất kể đã có chữ) → cùng câu đi
/// đường trên máy.
class RoiVeMay extends KetQuaOnline {
  const RoiVeMay(this.lyDo);
  final String lyDo;
}

/// Đã có chữ mà luồng đứt / đóng không `done`, hoặc người dùng bấm Dừng → giữ phần đã hiện,
/// kèm ghi chú.
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
      // Server luôn chẻ câu thông báo thành delta rồi mới done.fallback: chữ đã có không phải
      // câu trả lời thật, nên bỏ nó và rơi về máy bất kể daCoChu.
      return RoiVeMay(reason);
    case LoiOnline(:final http, :final lyDo):
      return daCoChu ? const GiuPhanDaCo(kGhiChuGianDoan) : RoiVeMay('http=$http $lyDo');
    case ChuOnline():
      // Luồng đóng sau một chữ mà không có done: coi như gián đoạn.
      return daCoChu ? const GiuPhanDaCo(kGhiChuGianDoan) : const RoiVeMay('đóng không done');
  }
}

typedef MucHoiThoai = ({bool cuaToi, String cau, bool laThe});

/// History gửi Gemini, ghép theo CẶP trên hội thoại CHƯA lọc (cũ → mới): một cặp = tin của
/// người dùng đứng NGAY TRƯỚC một lời đáp của AI (cả hai là chữ thật, không phải thẻ lệnh /
/// câu cố định của hệ thống). Lấy ≤ `toiDa ~/ 2` cặp cuối; tin không thuộc cặp nào bị bỏ.
///
/// Vì sao theo cặp: tin `user` mà lời đáp là câu hệ thống (câu bị chặn ở client, lệnh tạo C3) hay
/// bị Dừng không chữ là tin MỒ CÔI — để lọt lên Gemini thì lách được `chuDeBiChanOnline`; còn
/// SDK Gemini đòi tin đầu là `user` và ném lỗi (mở circuit breaker dùng chung) nếu không. Kết quả
/// luôn xen kẽ user/model, bắt đầu `user`, kết bằng `model`, độ dài chẵn ≤ [toiDa].
/// Không gồm câu đang hỏi — người gọi truyền hội thoại TRƯỚC khi thêm nó.
List<TinLichSu> xepHistory(Iterable<MucHoiThoai> hoiThoai, {int toiDa = 6}) {
  final tin = hoiThoai.toList();
  final cap = <TinLichSu>[];
  for (var i = 0; i + 1 < tin.length; i++) {
    final h = tin[i], d = tin[i + 1];
    final hopLe = h.cuaToi && !h.laThe && h.cau.isNotEmpty && !d.cuaToi && !d.laThe && d.cau.isNotEmpty;
    if (!hopLe) continue;
    cap
      ..add((role: 'user', text: h.cau))
      ..add((role: 'model', text: d.cau));
    i++;
  }
  final toiDaCap = toiDa ~/ 2;
  final tu = cap.length > toiDaCap * 2 ? cap.length - toiDaCap * 2 : 0;
  return cap.sublist(tu);
}

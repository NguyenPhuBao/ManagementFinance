/// Chuỗi tiến độ mục tiêu theo thời gian, cho khối biểu đồ ở trang chi tiết.
///
/// Tách khỏi widget vì phần khó ở đây không phải phần vẽ mà là **chỗ neo của
/// chuỗi**: lịch sử giao dịch không bảo đảm cộng lại bằng `currentAmount`, nên
/// cộng xuôi từ 0 cho ra một điểm cuối cãi nhau với vòng phần trăm ngay phía
/// trên. Xem `goal_progress_series_test.dart`.
library;

import '../data/models/goal_entity.dart';
import 'goal_history_filter.dart';

/// Một điểm trên đường tiến độ: tại [ngay] thì mục tiêu đang giữ [soTien].
class DiemTienDo {
  final DateTime ngay;
  final double soTien;

  const DiemTienDo({required this.ngay, required this.soTien});
}

/// Dữ liệu đã dựng sẵn cho khối biểu đồ.
class ChuoiTienDo {
  /// Đường thực tế, **cũ nhất trước**.
  final List<DiemTienDo> thucTe;

  /// Đường kế hoạch: **hai** điểm, hoặc **rỗng** khi không có ngày bắt đầu.
  ///
  /// Rỗng chứ không phải một đường đoán: cùng kỷ luật với
  /// `GoalEntity.isBehindSchedule`, thiếu căn cứ thì im lặng.
  final List<DiemTienDo> keHoach;

  /// Biên trái và phải của trục thời gian.
  final DateTime tuNgay;
  final DateTime denNgay;

  /// Trần của trục dọc, luôn dương.
  final double dinhY;

  const ChuoiTienDo({
    required this.thucTe,
    required this.keHoach,
    required this.tuNgay,
    required this.denNgay,
    required this.dinhY,
  });
}

/// Khoảng hở giữa trần trục dọc và điểm cao nhất, để đường không dính mép.
const double _hoTranTrucDoc = 1.05;

/// Kẹp giá trị đem vẽ ở 0.
///
/// Lịch sử có thể cộng lại **nhiều hơn** số tiền đang giữ — đo được trên máy
/// ảo ngày 2026-09-09: mục tiêu "MuaXe" có 11 khoản tổng 2.201.000 đ trong khi
/// chỉ giữ 1.101.000 đ. Phép đi lùi khi ấy cho điểm gốc âm, và một mục tiêu
/// "từng giữ âm một triệu" vừa là lời nói dối vừa rơi ra ngoài dải của biểu đồ.
///
/// Kẹp ở 0 đọc ra "chưa có dữ liệu mạch lạc tới đó" — gần sự thật hơn hẳn.
double _khongAm(double x) => x < 0 ? 0 : x;

/// Dựng chuỗi tích luỹ theo thời gian, hoặc `null` khi không có gì để vẽ.
///
/// Chuỗi được dựng bằng cách **đi lùi** từ [soTienHienTai]: điểm cuối luôn là
/// con số mà vòng phần trăm đang hiện, và phần lịch sử còn thiếu lộ ra thành
/// một điểm gốc khác 0. Đi xuôi từ 0 thì phần thiếu ấy dồn hết vào điểm cuối.
ChuoiTienDo? chuoiTienDo({
  required List<KhoanTichLuy> khoan,
  required double soTienHienTai,
  required double soTienDich,
  required DateTime? ngayBatDau,
  required DateTime hanChot,
  required DateTime now,
}) {
  if (khoan.isEmpty) return null;

  // Truy vấn trả về `date desc`; trục thời gian đọc từ trái sang phải.
  final tang = [...khoan]..sort((a, b) => a.ngay.compareTo(b.ngay));
  final delta = [
    for (final k in tang) k.laKhoanRut ? -k.soTien : k.soTien,
  ];

  var chay = soTienHienTai - delta.fold(0.0, (s, d) => s + d);

  final diem = <DiemTienDo>[];
  final mocGoc = ngayBatDau;
  if (mocGoc != null && mocGoc.isBefore(tang.first.ngay)) {
    diem.add(DiemTienDo(ngay: mocGoc, soTien: _khongAm(chay)));
  }
  for (var i = 0; i < tang.length; i++) {
    // `chay` cộng dồn ở dạng THÔ; chỉ giá trị đem vẽ mới bị kẹp. Kẹp cả biến
    // chạy thì sai số dồn lại và điểm cuối trượt khỏi [soTienHienTai].
    chay += delta[i];
    diem.add(DiemTienDo(ngay: tang[i].ngay, soTien: _khongAm(chay)));
  }

  // Kéo phẳng tới hôm nay: một mục tiêu đứng im bốn tháng phải đọc ra là đứng
  // im, chứ không phải là hết dữ liệu.
  if (now.isAfter(diem.last.ngay)) {
    diem.add(DiemTienDo(ngay: now, soTien: _khongAm(chay)));
  }

  var dinh = soTienDich;
  for (final d in diem) {
    if (d.soTien > dinh) dinh = d.soTien;
  }

  // Quá hạn mà chưa đạt thì trục phải chạy tiếp, nếu không điểm hôm nay rơi ra
  // ngoài vùng vẽ đúng lúc cần nhìn nhất.
  var den = hanChot.isAfter(now) ? hanChot : now;
  // Tạo mục tiêu, nạp tiền và tới hạn trong cùng một ngày là trục rộng 0 —
  // chia cho 0 ở mọi phép quy đổi ngày sang toạ độ.
  if (!den.isAfter(diem.first.ngay)) {
    den = diem.first.ngay.add(const Duration(days: 1));
  }

  return ChuoiTienDo(
    thucTe: diem,
    keHoach: ngayBatDau == null
        ? const []
        : [
            DiemTienDo(ngay: ngayBatDau, soTien: 0),
            DiemTienDo(ngay: hanChot, soTien: soTienDich),
          ],
    tuNgay: diem.first.ngay,
    denNgay: den,
    dinhY: dinh <= 0 ? 1.0 : dinh * _hoTranTrucDoc,
  );
}

/// Vị trí của tiến độ hiện tại so với đường kế hoạch.
enum NhipKeHoach { cham, dungNhip, vuot }

/// So số đã tích với mốc kế hoạch tại [now]; `null` khi không đủ căn cứ.
///
/// Phép phân loại dùng **đúng** `GoalEntity.bienDungSai` và **đúng** phép so
/// của `GoalEntity.isBehindSchedule` — tỉ lệ tiền so với tỉ lệ ngày. Thẻ "Cấu
/// hình" ngay phía trên đã nói "Chậm so với nhịp" bằng luật ấy; chép một biên
/// khác vào đây là hai câu nói ngược nhau trên cùng một trang.
///
/// [chenhLech] trả bằng **tiền** chứ không phải điểm phần trăm: người dùng nạp
/// bù bằng tiền.
({NhipKeHoach nhip, double chenhLech})? nhipSoVoiKeHoach({
  required double soTienHienTai,
  required double soTienDich,
  required DateTime? ngayBatDau,
  required DateTime hanChot,
  required DateTime now,
}) {
  if (soTienDich <= 0) return null;

  final batDau = ngayBatDau;
  if (batDau == null) return null;

  // Cắt về NGÀY trước khi trừ, y như isBehindSchedule: trừ DateTime thô thì
  // cùng một mục tiêu đọc ra chậm hay đúng nhịp tuỳ giờ người dùng mở app.
  final tuNgay = DateTime(batDau.year, batDau.month, batDau.day);
  final denNgay = DateTime(hanChot.year, hanChot.month, hanChot.day);
  final homNay = DateTime(now.year, now.month, now.day);

  if (homNay.isBefore(tuNgay)) return null;

  final tongNgay = denNgay.difference(tuNgay).inDays;
  if (tongNgay <= 0) return null;

  final daQua = homNay.difference(tuNgay).inDays;
  // Quá hạn thì kế hoạch đã đòi đủ 100%. Ngoại suy tiếp cho ra một mốc lớn hơn
  // chính mục tiêu, tức chê người dùng vì không vượt đích.
  final tiLeKeHoach = daQua >= tongNgay ? 1.0 : daQua / tongNgay;
  final tiLeHienTai = soTienHienTai / soTienDich;

  final nhip = tiLeHienTai < tiLeKeHoach - GoalEntity.bienDungSai
      ? NhipKeHoach.cham
      : tiLeHienTai > tiLeKeHoach + GoalEntity.bienDungSai
          ? NhipKeHoach.vuot
          : NhipKeHoach.dungNhip;

  return (nhip: nhip, chenhLech: soTienHienTai - soTienDich * tiLeKeHoach);
}

/// Bề rộng một nhãn trục thời gian, tính theo **tỉ lệ của cả dải**.
///
/// Nhãn "09/26" rộng khoảng 40px trên vùng vẽ ~325px ở khổ 411dp, tức xấp xỉ
/// 12%. Đây là con số đo trên máy chứ không phải chọn cho đẹp.
const double _beRongNhanTruc = 0.12;

/// Có nên vẽ nhãn trục thời gian ở mốc [v] không.
///
/// `fl_chart` vẽ nhãn ở **cả hai biên** rồi **cộng thêm** các mốc theo
/// `interval`. Mốc rơi sát biên vì thế in đè lên nhãn biên — thấy trên máy ảo
/// ngày 2026-09-09 với mục tiêu "MuaDT": "08/27" và "09/27" chồng nhau thành
/// một mớ không đọc được. Không lỗi, không log; nó chỉ trông sai.
///
/// Hai nhãn biên luôn được giữ: chúng nói trục trải từ đâu tới đâu.
bool hienNhanTruc({
  required double v,
  required double min,
  required double max,
}) {
  // fl_chart hỏi cả những mốc ngoài dải khi vẽ lưới.
  if (v < min - 1 || v > max + 1) return false;

  final dai = max - min;
  if (dai <= 0) return true;

  final laBien = v <= min + 1 || v >= max - 1;
  if (laBien) return true;

  final chua = dai * _beRongNhanTruc;
  return v - min >= chua && max - v >= chua;
}

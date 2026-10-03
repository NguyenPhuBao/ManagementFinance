/// C2 §2.8 — ô *Nhập nhanh* đọc câu bằng mô hình trên máy (Gemma 4 E2B). Người dùng chọn *"AI đọc mọi câu"*
/// (2026-09-30): máy có mô hình và công tắc AI bật thì mọi câu qua đây; không thì chỉ luật.
///
/// Đây CHỈ là chỗ gọi mô hình. Kết quả là [KetQuaAi] **thô** — lớp kiểm nằm ở `docCauGiaoDich(ai: …)`, nơi mỗi ô của
/// AI phải qua luật mới được dùng. Mọi hỏng hóc (chưa sẵn sàng, nạp lỗi, máy từng sập ở phiên có tool, quá hạn, đã huỷ,
/// mô hình không gọi tool) đều trả `null`: người gọi dùng kết quả luật, không báo lỗi to.
///
/// Phiên có **đúng một** tool — prompt ngắn (bẫy 4.51 `AI_EDGE_FEATURE.md`: phiên một tool mô hình viết đúng mọi số).
/// Tên ví / danh mục là `enum` trong schema để engine ép mô hình chỉ chọn tên có thật (lớp kiểm vẫn soát lại).
///
/// ⚠️ Nằm ở `transaction/data/`, không ở `ai_edge/`: schema phải mang chữ `'thu'` / `'chi'`, mà test quét 14 cấm
/// `ai_edge/` chứa chúng. Chỉ `slm_runtime.dart` được import `flutter_gemma` (test quét 16) — tệp này đi qua `SlmRuntime`.
library;

import 'dart:async';

import '../../ai_edge/data/phien_mot_loi_goi.dart';
import '../../ai_edge/data/slm_runtime.dart';
import '../../ai_edge/domain/cong_cu.dart';
import '../domain/doc_cau_giao_dich.dart';

const String kTenCongCuDienGiaoDich = 'dien_giao_dich';

/// Quá chừng này (tính từ lúc mở phiên, không tính nạp mô hình) thì bỏ AI, dùng luật. Đo Realme CPU 2026-09-30: lượt sinh
/// 12–17 s, cả lượt ~18 s (mục 9.41 `AI_EDGE_FEATURE.md`).
const Duration kThoiHanDocAi = Duration(seconds: 45);

const List<String> _tenThu = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];

String _dd(int n) => n.toString().padLeft(2, '0');

/// Lời hệ thống. Hôm nay đi kèm để mô hình đọc được *"hôm qua"*, *"thứ sáu tuần trước"* — ngày nó trả vẫn qua kiểm.
String promptNhapNhanh(DateTime now) =>
    'Bạn đọc MỘT câu ghi chép chi tiêu hoặc thu nhập bằng tiếng Việt rồi gọi công cụ '
    '$kTenCongCuDienGiaoDich đúng MỘT lần với những gì câu nói. Hôm nay là ${_tenThu[now.weekday - 1]}, '
    '${_dd(now.day)}/${_dd(now.month)}/${now.year}. Không đoán thứ câu không nói: để trống hoặc 0. '
    'Số tiền tính bằng đồng: k = nghìn, tr / triệu / củ = triệu, lít / xị = trăm nghìn, "ba chục" = ba mươi nghìn.';

KhaiBaoCongCu khaiBaoDienGiaoDich({required List<String> tenVi, required List<String> tenDanhMuc}) => KhaiBaoCongCu(
      ten: kTenCongCuDienGiaoDich,
      moTa: 'Điền sẵn một giao dịch từ câu người dùng vừa gõ.',
      thamSo: {
        'type': 'object',
        'properties': {
          'so_tien': {'type': 'integer', 'description': 'Số tiền bằng đồng; 0 nếu câu không nói.'},
          'loai': {
            'type': 'string',
            'enum': ['chi', 'thu', 'chuyen_vi', 'khong_ro'],
            'description': 'thu = tiền vào (lương, thưởng, bán, được cho); chi = tiền ra; chuyen_vi = chuyển tiền giữa '
                'hai ví của chính người dùng; khong_ro nếu không rõ.',
          },
          'ngay': {
            'type': 'string',
            'description': 'Ngày giao dịch dạng dd/mm/yyyy nếu câu nói (hôm qua, thứ sáu tuần trước…); rỗng nếu không.',
          },
          'vi': {
            'type': 'string',
            'enum': [...tenVi, ''],
            'description': 'Ví trả tiền (ví nguồn khi chuyen_vi) câu nói tới; rỗng nếu không nói.',
          },
          'vi_den': {
            'type': 'string',
            'enum': [...tenVi, ''],
            'description': 'Ví nhận tiền khi chuyen_vi; rỗng nếu không phải chuyển ví.',
          },
          'danh_muc': {
            'type': 'string',
            'enum': [...tenDanhMuc, ''],
            'description': 'Danh mục hợp nhất; rỗng nếu không chắc.',
          },
          'ghi_chu': {
            'type': 'string',
            'description': 'Phần mô tả còn lại của câu, bỏ số tiền, ngày và ví. Không thêm chữ.',
          },
        },
        'required': ['so_tien', 'loai', 'ngay', 'vi', 'vi_den', 'danh_muc', 'ghi_chu'],
      },
    );

class DocCauBangAi {
  DocCauBangAi({
    required this.runtime,
    required this.sanSang,
    required this.duongTep,
    this.thoiHan = kThoiHanDocAi,
  });

  final SlmRuntime runtime;

  /// Máy dùng được AI không — tệp mô hình đủ **và** công tắc AI bật (cùng hai điều kiện của màn Trợ lý AI).
  final Future<bool> Function() sanSang;
  final Future<String> Function() duongTep;
  final Duration thoiHan;

  /// Vòng đời phiên (nạp một lần, lời gọi đầu tiên, quá hạn, huỷ) dùng chung với lệnh tạo của màn Trợ lý (C3 §8.2).
  late final PhienMotLoiGoi _phien = PhienMotLoiGoi(
    runtime: runtime,
    sanSang: sanSang,
    duongTep: duongTep,
    thoiHan: thoiHan,
    nhan: '[NhapNhanh][AI]',
  );

  /// Nạp mô hình ngầm — màn gọi khi ô Nhập nhanh có focus (người dùng chốt), để lúc bấm Điền chỉ còn chờ lượt sinh.
  /// MỘT `Future` dùng chung: bấm Điền lúc đang nạp thì chờ chính nó. `false` = không dùng được AI; nạp lỗi thì lần
  /// sau thử lại.
  Future<bool> chuanBi() => _phien.chuanBi();

  /// Các ô thô mô hình đọc được từ [cau], hoặc `null` (người gọi dùng luật).
  Future<KetQuaAi?> doc(
    String cau, {
    required DateTime now,
    required List<String> tenVi,
    required List<String> tenDanhMuc,
  }) async {
    final goi = await _phien.goiDauTien(
      heThong: promptNhapNhanh(now),
      cauHoi: cau,
      congCu: [khaiBaoDienGiaoDich(tenVi: tenVi, tenDanhMuc: tenDanhMuc)],
      laDich: (g) => g.ten == kTenCongCuDienGiaoDich,
    );
    return goi == null ? null : KetQuaAi.tuThamSo(goi.args);
  }

  /// Người dùng bấm Huỷ: lượt đang chạy trả `null`, engine thôi giải mã.
  Future<void> huy() => _phien.huy();
}

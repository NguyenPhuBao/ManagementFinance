/// C3 §8.2 — lệnh tạo hoá đơn / mục tiêu / ngân sách đọc bằng mô hình trên máy: phiên RIÊNG ba tool, không nhét vào
/// phiên sáu tool của vòng hỏi đáp (trần token — mục 9.34 `AI_EDGE_FEATURE.md`: chín tool khai cùng lúc từng vỡ trần).
///
/// Đây CHỈ là chỗ gọi mô hình. Kết quả là [KetQuaLenhAi] **thô** — lưới kiểm nằm ở `lenhTaoTuAi`, nơi mỗi ô của AI phải
/// qua một chốt mới được dùng. Mọi hỏng hóc (chưa sẵn sàng, nạp lỗi, máy từng sập ở phiên có tool, quá hạn, đã huỷ, mô
/// hình không gọi tool) đều trả `null`: màn dùng bộ luật dự phòng.
///
/// ⚠️ Tầng 4: KHÔNG tool nào có tham số bật tự trả / trích tự động — đó là việc của người dùng trong form.
///
/// Nằm ở `ai_chat/data/` cạnh `nguon_lenh_tao.dart` (bên lọc danh mục CHI — test quét 14 cấm `ai_edge/` so chiều tiền).
/// Đi qua `SlmRuntime` (test quét 16).
library;

import '../../ai_edge/data/phien_mot_loi_goi.dart';
import '../../ai_edge/data/slm_runtime.dart';
import '../../ai_edge/domain/cong_cu.dart';
import '../../ai_edge/domain/lenh_tao.dart';
import '../../transaction/data/doc_cau_bang_ai.dart' show kThoiHanDocAi;

/// Dòng chỉ báo của màn chat khi phiên này đang chạy.
const String kDangDocLenh = 'Đang đọc lệnh bằng AI…';

const List<String> _tenThu = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];

String _dd(int n) => n.toString().padLeft(2, '0');

/// Lời hệ thống. Hôm nay đi kèm để mô hình đọc được *"hè năm sau"*, *"cuối năm"* — hạn nó trả vẫn qua kiểm.
String promptLenhTao(DateTime now) =>
    'Người dùng muốn TẠO một hoá đơn định kỳ, một mục tiêu tiết kiệm, hoặc ĐẶT một ngân sách. Đọc câu tiếng Việt rồi '
    'gọi đúng MỘT công cụ phù hợp với những gì câu nói. Hôm nay là ${_tenThu[now.weekday - 1]}, '
    '${_dd(now.day)}/${_dd(now.month)}/${now.year}. Không đoán thứ câu không nói: để trống hoặc 0. '
    'Số tiền tính bằng đồng: k = nghìn, tr / triệu = triệu. Hạn dạng dd/mm/yyyy ("hè năm sau" = 30/06 năm sau, '
    '"cuối năm" = 31/12 năm nay, "tết" = 31/01 năm sau). Nếu câu không phải muốn tạo gì thì không gọi công cụ nào.';

/// Ba tool, mong đợi đúng MỘT lời gọi. Tên ví / danh mục là `enum` để engine ép mô hình chỉ chọn tên có thật (lưới
/// kiểm vẫn soát lại); chuỗi rỗng trong enum là chỗ để mô hình được phép KHÔNG chọn. Mọi tham số `required`: mô hình
/// điền rỗng / 0 khi câu không nói.
List<KhaiBaoCongCu> khaiBaoLenhTao({required List<String> tenVi, required List<String> tenDanhMuc}) => [
      KhaiBaoCongCu(
        ten: kTenCongCuTaoHoaDon,
        moTa: 'Tạo hoá đơn định kỳ — một khoản PHẢI TRẢ lặp lại (tiền nhà, điện, Netflix, gym…).',
        thamSo: {
          'type': 'object',
          'properties': {
            'ten': {'type': 'string', 'description': 'Tên hoá đơn, chỉ lấy chữ có trong câu.'},
            'so_tien': {'type': 'integer', 'description': 'Số tiền mỗi kỳ bằng đồng; 0 nếu câu không nói.'},
            'chu_ky': {
              'type': 'string',
              'enum': ['tuan', 'thang', 'quy', 'nam', ''],
              'description': 'Chu kỳ; rỗng nếu không nói.',
            },
            'ngay_goc': {'type': 'integer', 'description': 'Ngày trong tháng đến hạn (1–31); 0 nếu không nói.'},
            'vi': {
              'type': 'string',
              'enum': [...tenVi, ''],
              'description': 'Ví trả, rỗng nếu không nói.',
            },
            'danh_muc': {
              'type': 'string',
              'enum': [...tenDanhMuc, ''],
              'description': 'Danh mục chi, rỗng nếu không chắc.',
            },
          },
          'required': ['ten', 'so_tien', 'chu_ky', 'ngay_goc', 'vi', 'danh_muc'],
        },
      ),
      const KhaiBaoCongCu(
        ten: kTenCongCuTaoMucTieu,
        moTa: 'Tạo mục tiêu tiết kiệm / để dành một khoản.',
        thamSo: {
          'type': 'object',
          'properties': {
            'ten': {'type': 'string', 'description': 'Tên mục tiêu, chỉ lấy chữ có trong câu (vd "mua xe").'},
            'so_tien_dich': {'type': 'integer', 'description': 'Số tiền cần đạt bằng đồng; 0 nếu không nói.'},
            'han': {'type': 'string', 'description': 'Hạn đạt dạng dd/mm/yyyy; rỗng nếu không nói.'},
          },
          'required': ['ten', 'so_tien_dich', 'han'],
        },
      ),
      KhaiBaoCongCu(
        ten: kTenCongCuDatNganSach,
        // Đo Realme 2026-10-01: với mô tả ngắn, *"ăn uống tối đa 3 triệu một tháng"* bị gọi thành tao_hoa_don.
        moTa: 'Đặt hạn mức chi TỐI ĐA cho một danh mục (vd "ăn uống tối đa 3 triệu một tháng").',
        thamSo: {
          'type': 'object',
          'properties': {
            'danh_muc': {
              'type': 'string',
              'enum': [...tenDanhMuc, ''],
              'description': 'Danh mục chi; rỗng nếu không chắc.',
            },
            'han_muc': {'type': 'integer', 'description': 'Hạn mức bằng đồng; 0 nếu không nói.'},
          },
          'required': ['danh_muc', 'han_muc'],
        },
      ),
    ];

/// Khe tiêm cho màn chat (test thay bằng bản giả).
abstract class DocLenh {
  /// Các ô thô mô hình đọc được từ [cau], hoặc `null` (mô hình không coi câu là lệnh tạo, hoặc hỏng hóc).
  Future<KetQuaLenhAi?> doc(
    String cau, {
    required DateTime now,
    required List<String> tenVi,
    required List<String> tenDanhMuc,
  });

  /// Người dùng bấm Huỷ: lượt đang chạy trả `null`.
  Future<void> huy();
}

class DocLenhBangAi implements DocLenh {
  DocLenhBangAi({
    required this.runtime,
    required this.sanSang,
    required this.duongTep,
    this.thoiHan = kThoiHanDocAi,
  });

  final SlmRuntime runtime;

  /// Máy dùng được AI không — tệp mô hình đủ **và** công tắc AI bật.
  final Future<bool> Function() sanSang;
  final Future<String> Function() duongTep;
  final Duration thoiHan;

  late final PhienMotLoiGoi _phien = PhienMotLoiGoi(
    runtime: runtime,
    sanSang: sanSang,
    duongTep: duongTep,
    thoiHan: thoiHan,
    nhan: '[SLM][lenh]',
  );

  Future<bool> chuanBi() => _phien.chuanBi();

  @override
  Future<KetQuaLenhAi?> doc(
    String cau, {
    required DateTime now,
    required List<String> tenVi,
    required List<String> tenDanhMuc,
  }) async {
    final goi = await _phien.goiDauTien(
      heThong: promptLenhTao(now),
      cauHoi: cau,
      congCu: khaiBaoLenhTao(tenVi: tenVi, tenDanhMuc: tenDanhMuc),
      laDich: (g) => kTenCongCuLenhTao.contains(g.ten),
    );
    return goi == null ? null : KetQuaLenhAi.tuLoiGoi(goi.ten, goi.args);
  }

  @override
  Future<void> huy() => _phien.huy();
}

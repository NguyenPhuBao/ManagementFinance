/// A5 — luật đọc ảnh quét + chốt tổng chạy trên chữ OCR mà `/quet` THẬT đã thấy (Realme, 2026-10-21; dữ liệu ở
/// `hoa_don_quet_that_du_lieu.dart`). Khác `hoa_don_that_test.dart`: chữ ở đây đã qua `image_picker` (ảnh nén lại), nên
/// đây mới là phép kiểm hồi quy đầu-cuối của `/quet` trên 15 tờ R01–R16 + một tờ mới.
///
/// Nhóm đầu là phép kiểm CHÍNH dữ liệu: luật trên chữ đã che thông tin phải ra đúng dòng `[Quet][luat]` của logcat
/// hôm ấy — đỏ là dữ liệu chép sai, hoặc luật đã đổi cách đọc một tờ thật.
library;

import 'package:flowmoney/features/transaction/domain/chot_tong_quet.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hoa_don_quet_that_du_lieu.dart';

/// Đáp án chấm bằng mắt trên ảnh (bảng mục 7 `QUET_ANH_FEATURE.md`). R15 lấy *Tổng tiền* như quy ước 08/10.
const Map<String, int> kDapAnQuet = {
  'N01': 398800, 'R01': 262000, 'R02': 158000, 'R03': 217500, 'R04': 55500, 'R05': 57000, 'R06': 76872,
  'R07': 44700, 'R08': 75700, 'R10': 45000, 'R11': 79243, 'R12': 300240, 'R13': 72127, 'R14': 44745, 'R15': 32160,
  'R16': 36000,
};

/// Tổng Gemma CPU (Realme, nhìn ảnh) trả trong cùng lượt — dòng `[Quet][Gemma]` của logcat.
const Map<String, int> kGemmaQuet = {
  'N01': 161000, 'R01': 262000, 'R02': 158000, 'R03': 217500, 'R04': 55500, 'R05': 57000, 'R06': 76872,
  'R07': 44700, 'R08': 55000, 'R10': 45000, 'R11': 119180, 'R12': 300240, 'R13': 72127, 'R14': 44745, 'R15': 13500,
  'R16': 36000,
};

void main() {
  final luc = DateTime(2026, 10, 21, 14);
  KetQuaAnhQuet doc(String ma) => docAnhQuet(vanBan: kHoaDonQuetRealme[ma]!, luc: luc);

  group('luật trên chữ /quet ra đúng dòng [Quet][luat] của logcat 2026-10-21', () {
    // (tổng, ghi chú, ngày giờ in trên tờ — null = không đọc ra, form dùng lúc quét)
    const logcat = <String, (int, String, (int, int, int, int, int)?)>{
      'N01': (398800, 'ỦA TEA', (2026, 10, 14, 0, 0)),
      'R01': (262000, 'STARBUCKS"', (2026, 9, 28, 14, 19)),
      'R02': (158000, 'ỦA TEA', (2026, 10, 2, 14, 26)),
      'R03': (217500, 'ỦA TEA', (2026, 10, 2, 14, 33)),
      'R04': (55500, 'DHIẾU TRANH TOẢN BÁCH HÓA XANH', null),
      'R05': (57000, 'eco-shop Invoice', (2026, 8, 30, 0, 0)),
      'R06': (76872, 'NHÀ THUỐc', (2026, 8, 20, 16, 43)),
      'R07': (44700, '', (2026, 9, 21, 18, 55)),
      'R08': (75706, 'MAXIDI ORE', (2026, 9, 11, 19, 42)),
      'R10': (45000, '', (2026, 9, 19, 18, 6)),
      'R11': (79243, 'PHIỀU THANH TOÁN BẢCH HÔA XANH', null),
      'R12': (300240, 'DOOKKI Topokki Buftet', null),
      // Ngày OCR đọc "912/2025" (08/10 đọc ra 9/2/2026) — không đọc ra, lấy lúc quét.
      'R13': (2127, 'MAXIDI', null),
      'R14': (44745, '', (2026, 10, 1, 20, 2)),
      'R15': (32160, 'CHTAU THANH OAN BACP HÓA KATL', null),
      'R16': (36000, 'BEE BEE MART 18K', (2026, 9, 19, 21, 29)),
    };

    test('đủ 16 tờ, không thừa', () => expect(kHoaDonQuetRealme.keys.toSet(), logcat.keys.toSet()));

    for (final e in logcat.entries) {
      test(e.key, () {
        final (tong, ghi, ngay) = e.value;
        final kq = doc(e.key);
        expect(kq.loai, LoaiAnhQuet.hoaDon);
        expect(kq.soTien, tong.toDouble());
        expect(kq.ghiChu, ghi);
        if (ngay == null) {
          expect(kq.thoiGian, luc);
          expect(kq.oThieu, contains(OAnhQuet.thoiGian));
        } else {
          final (y, m, d, h, p) = ngay;
          expect(kq.thoiGian, DateTime(y, m, d, h, p));
          expect(kq.oThieu, isNot(contains(OAnhQuet.thoiGian)));
        }
        expect(kq.oThieu.contains(OAnhQuet.ghiChu), ghi.isEmpty);
      });
    }
  });

  // G101 (mở 2026-10-21): trên chữ này form ĐIỀN SẴN R08 = 75.706 (OCR đọc nhầm dòng tổng) và R13 = 2.127 (OCR mất chữ
  // 7), không dấu hiệu gì — cả Premium (số Gemma bị bỏ) lẫn Basic. Ba lưới của `chotTongQuet` (người dùng chọn
  // 2026-10-21) chuyển hai tờ ấy sang HỎI; mười bốn tờ còn lại giữ nguyên.
  group('G101 — số chốt trên form (Premium: luật + Gemma; Basic: chỉ luật)', () {
    ChotTong chot(String ma, {required bool premium}) => chotTongQuet(
          luat: doc(ma).soTien,
          ai: premium ? kGemmaQuet[ma] : null,
          vanBan: kHoaDonQuetRealme[ma]!,
        );

    /// Điền `int`; hỏi chip `List<int>`; ô trống không chip `null`.
    Object? hien(ChotTong c) => c.soTien?.round() ?? (c.luaChon.isEmpty ? null : [for (final v in c.luaChon) v.round()]);

    for (final premium in [true, false]) {
      final goi = premium ? 'Premium' : 'Basic';

      test('⭐ $goi — không tờ nào bị ĐIỀN SẴN một số sai; tờ có chip thì số đúng nằm trong chip', () {
        for (final ma in kHoaDonQuetRealme.keys) {
          final c = chot(ma, premium: premium);
          final dung = kDapAnQuet[ma]!.toDouble();
          if (c.soTien != null) expect(c.soTien, dung, reason: '$ma — G101: số sai điền sẵn, không dấu hiệu gì');
          if (c.luaChon.isNotEmpty) expect(c.luaChon, contains(dung), reason: ma);
        }
      });
    }

    test('Premium — từng tờ', () {
      expect({for (final ma in kHoaDonQuetRealme.keys) ma: hien(chot(ma, premium: true))}, {
        ...{for (final e in kDapAnQuet.entries) e.key: e.value},
        // Lưới B: số luật đứng một mình (Gemma 55.000 không in trên ảnh) mà dòng VAT in 75,700 — lệch ≤ 1%, hỏi.
        'R08': [75706, 75700],
        // Lưới C: Gemma 72.127 hơn số luật 2.127 đúng MỘT chữ số (OCR mất chữ 7) — thành ứng viên, lệch > 1% nên hỏi.
        'R13': [72127, 2127],
        // Có từ trước: Gemma 13.500 có in trên ảnh (dòng món) nhưng lệch Tổng tiền.
        'R15': [13500, 32160],
      });
    });

    test('Basic — từng tờ', () {
      expect({for (final ma in kHoaDonQuetRealme.keys) ma: hien(chot(ma, premium: false))}, {
        ...{for (final e in kDapAnQuet.entries) e.key: e.value},
        'R08': [75706, 75700],
        // Lưới A: tổng 2.127 nhỏ hơn dòng món 19.800 in phía trên — không tin, không có số nào khác để hỏi → ô trống.
        'R13': null,
      });
    });
  });
}

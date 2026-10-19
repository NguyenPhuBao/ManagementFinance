/// Luật đường hỏi của màn Trợ lý AI (spec trợ lý online 2026-10-11 §3.1, §3.3):
/// hàm thuần, không Flutter, không DI — trang chỉ gọi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/domain/duong_hoi.dart';
import 'package:flowmoney/features/ai_chat/domain/su_kien_online.dart';

void main() {
  group('nenHoiOnline', () {
    test('câu chào cũng đi online (spec §3.1)', () {
      expect(nenHoiOnline(congTacBat: true, coMang: true, cauHoi: 'xin chào'), isTrue);
    });
    test('công tắc bật ∧ có mạng ∧ không phải dữ liệu sống → online', () {
      expect(nenHoiOnline(congTacBat: true, coMang: true, cauHoi: 'quỹ khẩn cấp là gì'), isTrue);
    });
    test('thiếu một vế → trên máy', () {
      expect(nenHoiOnline(congTacBat: false, coMang: true, cauHoi: 'quỹ khẩn cấp là gì'), isFalse);
      expect(nenHoiOnline(congTacBat: true, coMang: false, cauHoi: 'quỹ khẩn cấp là gì'), isFalse);
      expect(nenHoiOnline(congTacBat: true, coMang: true, cauHoi: 'giá vàng hôm nay'), isFalse,
          reason: 'dữ liệu sống chặn ở cả hai đường (câu 2, 2026-10-11)');
    });
  });

  group('quyetDinhSauOnline — bảng §3.3', () {
    test('Xong sau ≥ 1 chữ → HoanTat', () {
      expect(quyetDinhSauOnline(daCoChu: true, cuoi: const XongOnline(responseTimeMs: 700), daDung: false), isA<HoanTat>());
    });
    test('Xong mà CHƯA có chữ → RoiVeMay("rỗng") — câu trống cũng là hỏng', () {
      final k = quyetDinhSauOnline(daCoChu: false, cuoi: const XongOnline(), daDung: false);
      expect(k, isA<RoiVeMay>());
      expect((k as RoiVeMay).lyDo, 'rỗng');
    });
    test('DuPhong / Loi khi chưa có chữ → RoiVeMay mang lý do (403, 429, 503, hết giờ đều thế)', () {
      for (final sk in const [
        DuPhongOnline('Hệ thống chưa thiết lập API Key Google Gemini'),
        LoiOnline(http: 403, lyDo: 'FEATURE_DISABLED'),
        LoiOnline(http: 429, lyDo: 'quá hạn mức'),
        LoiOnline(http: 503, lyDo: 'MAINTENANCE_MODE'),
        LoiOnline(http: null, lyDo: 'receiveTimeout'),
      ]) {
        final k = quyetDinhSauOnline(daCoChu: false, cuoi: sk, daDung: false);
        expect(k, isA<RoiVeMay>(), reason: '$sk');
      }
    });
    test('DuPhong khi ĐÃ có chữ → vẫn RoiVeMay', () {
      final k = quyetDinhSauOnline(daCoChu: true, cuoi: const DuPhongOnline('thiếu khoá'), daDung: false);
      expect(k, isA<RoiVeMay>(),
          reason: 'server luôn chẻ câu thông báo thành delta rồi mới done.fallback; chữ ấy không phải câu trả lời');
      expect((k as RoiVeMay).lyDo, 'thiếu khoá');
    });
    test('ChuOnline là sự kiện cuối (đóng không done)', () {
      expect(quyetDinhSauOnline(daCoChu: true, cuoi: const ChuOnline('x'), daDung: false), isA<GiuPhanDaCo>());
      expect(quyetDinhSauOnline(daCoChu: false, cuoi: const ChuOnline('x'), daDung: false), isA<RoiVeMay>());
    });
    test('Loi khi ĐÃ có chữ → giữ, ghi chú gián đoạn', () {
      final k = quyetDinhSauOnline(daCoChu: true, cuoi: const LoiOnline(http: null, lyDo: 'đứt'), daDung: false);
      expect(k, isA<GiuPhanDaCo>());
      expect((k as GiuPhanDaCo).ghiChu, kGhiChuGianDoan);
    });
    test('bấm Dừng → giữ phần đã có, ghi chú "đã dừng" — kể cả khi sự kiện cuối là lỗi huỷ', () {
      final k = quyetDinhSauOnline(daCoChu: true, cuoi: const LoiOnline(http: null, lyDo: 'cancel'), daDung: true);
      expect(k, isA<GiuPhanDaCo>());
      expect((k as GiuPhanDaCo).ghiChu, kGhiChuDaDung);
    });
    test('Dừng khi chưa có chữ → GiuPhanDaCo("đã dừng"): người dùng tự dừng thì không hỏi máy thay', () {
      // Spec §3.3 hàng cuối: "chưa có chữ → bong bóng rỗng không tạo, chỉ huỷ lượt".
      final k = quyetDinhSauOnline(daCoChu: false, cuoi: const LoiOnline(http: null, lyDo: 'cancel'), daDung: true);
      expect(k, isA<GiuPhanDaCo>());
      expect((k as GiuPhanDaCo).ghiChu, kGhiChuDaDung);
    });
  });

  group('xepHistory', () {
    test('≤ 6 tin chữ gần nhất, bỏ thẻ lệnh tạo, vai user/model, thứ tự cũ → mới', () {
      final hoiThoai = <MucHoiThoai>[
        (cuaToi: false, cau: 'Xin chào!', laThe: false),
        (cuaToi: true, cau: 'c1', laThe: false),
        (cuaToi: false, cau: 't1', laThe: false),
        (cuaToi: false, cau: '', laThe: true), // thẻ lệnh tạo
        (cuaToi: true, cau: 'c2', laThe: false),
        (cuaToi: false, cau: 't2', laThe: false),
        (cuaToi: true, cau: 'c3', laThe: false),
        (cuaToi: false, cau: 't3', laThe: false),
      ];
      final h = xepHistory(hoiThoai);
      expect(h.length, 6);
      expect(h.first, (role: 'user', text: 'c1'));
      expect(h.last, (role: 'model', text: 't3'));
      expect(h.any((t) => t.text.isEmpty), isFalse, reason: 'thẻ lệnh tạo không vào history');
    });
    test('rỗng → rỗng; toiDa tuỳ chỉnh', () {
      expect(xepHistory(const []), isEmpty);
      expect(
          xepHistory([(cuaToi: true, cau: 'a', laThe: false), (cuaToi: false, cau: 'b', laThe: false)], toiDa: 1),
          isEmpty,
          reason: 'nửa cặp không gửi: toiDa 1 không chứa nổi một cặp');
    });
    test('chỉ có lời chào AI → rỗng', () {
      expect(xepHistory([(cuaToi: false, cau: 'Xin chào!', laThe: false)]), isEmpty,
          reason: 'history bắt đầu bằng model làm backend ném lỗi và đếm vào circuit breaker');
    });
    test('[chào, u1, a1] → bỏ chào', () {
      expect(
          xepHistory([
            (cuaToi: false, cau: 'chào', laThe: false),
            (cuaToi: true, cau: 'u1', laThe: false),
            (cuaToi: false, cau: 'a1', laThe: false),
          ]),
          [(role: 'user', text: 'u1'), (role: 'model', text: 'a1')]);
    });
    MucHoiThoai u(String c) => (cuaToi: true, cau: c, laThe: false);
    MucHoiThoai a(String c) => (cuaToi: false, cau: c, laThe: false);
    const MucHoiThoai the = (cuaToi: false, cau: '', laThe: true);
    TinLichSu tu(String c) => (role: 'user', text: c);
    TinLichSu tm(String c) => (role: 'model', text: c);

    test('7 tin u0 a0 u1 a1 u2 a2 u3 → u3 không có lời đáp nên bỏ, còn 3 cặp', () {
      final h = xepHistory([u('u0'), a('a0'), u('u1'), a('a1'), u('u2'), a('a2'), u('u3')]);
      expect(h, [tu('u0'), tm('a0'), tu('u1'), tm('a1'), tu('u2'), tm('a2')],
          reason: 'tin user cuối chưa có lời đáp là nửa cặp, không gửi');
    });
    test('4 cặp → chỉ 3 cặp cuối', () {
      final h = xepHistory([u('u0'), a('a0'), u('u1'), a('a1'), u('u2'), a('a2'), u('u3'), a('a3')]);
      expect(h, [tu('u1'), tm('a1'), tu('u2'), tm('a2'), tu('u3'), tm('a3')]);
    });
    test('câu bị chặn ở client (lời đáp là câu hệ thống) không lên Gemini qua history', () {
      final h = xepHistory([u('Giá vàng hôm nay?'), the, u('Quỹ khẩn cấp là gì?'), a('Là quỹ dự phòng.')]);
      expect(h, [tu('Quỹ khẩn cấp là gì?'), tm('Là quỹ dự phòng.')],
          reason: 'câu bị chặn ở client không được lên Gemini qua history (lách chuDeBiChanOnline)');
    });
    test('Dừng không chữ để lại user cuối → bỏ', () {
      expect(xepHistory([u('u1'), a('a1'), u('u2')]), [tu('u1'), tm('a1')]);
    });
    test('lệnh tạo C3: user + thẻ không thành cặp', () {
      expect(xepHistory([u('tạo hoá đơn điện 500k'), the, u('u3'), a('a3')]), [tu('u3'), tm('a3')]);
    });
    test('dãy trộn → xen kẽ, đầu user, cuối model, độ dài chẵn', () {
      final h = xepHistory([a('chào'), u('u1'), a('a1'), u('mồ côi'), the, u('u2'), a('a2'), u('u3')]);
      expect(h, [tu('u1'), tm('a1'), tu('u2'), tm('a2')]);
      expect(h.length.isEven, isTrue);
      expect(h.first.role, 'user');
      expect(h.last.role, 'model');
      for (var i = 0; i < h.length; i++) {
        expect(h[i].role, i.isEven ? 'user' : 'model');
      }
    });
  });
}

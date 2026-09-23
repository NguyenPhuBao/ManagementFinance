/// Phép dịch từ `background_downloader` sang `TinLuot` — hai hàm thuần của bản
/// thật, tách ra vì lượt đo máy thật 2026-09-22 tối (Realme RMX2205) lộ hai
/// lỗi mà không ca test nào thấy:
///
/// 1. Màn hiện *"Đang tải… −400%"* / *"−9,64 GB / 2,41 GB"*: gói dùng **giá
///    trị âm làm mã trạng thái** trong sự kiện tiến độ (−1 hỏng · −2 huỷ · −3
///    không thấy · −4 chờ thử lại · −5 tạm dừng), bản đầu đưa thẳng lên màn.
/// 2. `waitingToRetry` dịch thành `dangCho` → màn nói *"Đang chờ Wi-Fi"* trong
///    khi thật ra là lỗi mạng đang được thử lại — một câu nói dối về nguyên nhân.
library;

import 'package:background_downloader/background_downloader.dart';
import 'package:flowmoney/features/ai_edge/data/nguon_tai_nen.dart';
import 'package:flowmoney/features/ai_edge/data/tai_nen_background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tinTuTienDo — giá trị âm là MÃ, không phải phần trăm', () {
    test('tiến độ thật trong [0, 1] → dangChay đúng số', () {
      final t = tinTuTienDo(0.42);
      expect(t, isNotNull);
      expect(t!.trangThai, TrangThaiLuot.dangChay);
      expect(t.phanTram, 0.42);
    });

    test('⭐ −4 (chờ thử lại) KHÔNG phải −400% — không phát tin tiến độ', () {
      // Realme 2026-09-22: sau ba lần "Enqueuing task" vì cleartext bị chặn,
      // màn hiện "Đang tải… −400%". Trạng thái đã có `TaskStatusUpdate` lo;
      // tin tiến độ âm thì bỏ.
      expect(tinTuTienDo(-4), isNull);
    });

    test('mọi giá trị âm khác cũng bỏ', () {
      for (final v in [-1.0, -2.0, -3.0, -5.0]) {
        expect(tinTuTienDo(v), isNull, reason: 'progress=$v');
      }
    });
  });

  group('canceled — của NGƯỜI DÙNG hay của WorkManager?', () {
    // Realme 2026-09-22: tắt Wi-Fi giữa lượt → WorkManager dừng worker vì
    // ràng buộc và báo `canceled`, rồi tự chạy lại khi Wi-Fi về. Dịch mù thành
    // "huỷ" là màn nói "Chưa tải mô hình" cho một lượt vẫn đang xếp hàng.
    test('người dùng bấm Huỷ → huy', () {
      expect(dichTrangThai(TaskStatus.canceled, huyDoNguoiDung: true),
          TrangThaiLuot.huy);
    });
    test('⭐ không ai bấm Huỷ mà canceled → dangCho (chờ ràng buộc)', () {
      expect(dichTrangThai(TaskStatus.canceled, huyDoNguoiDung: false),
          TrangThaiLuot.dangCho);
    });
  });

  group('dichTrangThai', () {
    test('enqueued → dangCho (chờ Wi-Fi / tài nguyên)', () {
      expect(dichTrangThai(TaskStatus.enqueued), TrangThaiLuot.dangCho);
    });

    test('⭐ waitingToRetry → dangChay, KHÔNG phải dangCho', () {
      // dangCho được màn dịch thành "Đang chờ Wi-Fi". Lượt đang thử lại sau
      // lỗi mạng mà nói "chờ Wi-Fi" là chỉ sai nguyên nhân — máy đang ở Wi-Fi.
      expect(dichTrangThai(TaskStatus.waitingToRetry), TrangThaiLuot.dangChay);
    });

    test('bốn trạng thái còn lại', () {
      expect(dichTrangThai(TaskStatus.running), TrangThaiLuot.dangChay);
      expect(dichTrangThai(TaskStatus.paused), TrangThaiLuot.tamDung);
      expect(dichTrangThai(TaskStatus.complete), TrangThaiLuot.xong);
      expect(dichTrangThai(TaskStatus.canceled, huyDoNguoiDung: true),
          TrangThaiLuot.huy);
      expect(dichTrangThai(TaskStatus.failed), TrangThaiLuot.hong);
      expect(dichTrangThai(TaskStatus.notFound), TrangThaiLuot.hong);
    });
  });
}

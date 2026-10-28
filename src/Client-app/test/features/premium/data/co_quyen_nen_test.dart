import 'package:flowmoney/features/premium/data/co_quyen_nen.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/data/models/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) => throw UnimplementedError();
}

class _ApiTra implements PaymentApi {
  _ApiTra(this.json);
  Map<String, Object?> json;
  @override
  Future<Map<String, Object?>> thongTinGoi() async => json;
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) => throw UnimplementedError();
}

/// `coQuyenNen` — cửa quyền của bộ chạy nền (tự trả, tự trích, thông báo cân đối, nhập biến động / biên lai). Spec
/// phân quyền 2026-10-08 mục 4.3 (3).
void main() {
  final now = DateTime(2026, 10, 8, 12);

  test('Basic bị tắt bill_auto_pay → false; quyền khác thiếu khoá → true', () async {
    final kho = InMemoryGoiStore();
    await kho.ghi(10,
        TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: now, quyenTinhNang: const {'bill_auto_pay': false}));
    final goi = GoiRepository(api: _ApiIm(), kho: kho, clock: () => now);
    await goi.datTaiKhoan(10);
    addTearDown(goi.dispose);
    expect(coQuyenNen(MaQuyen.billAutoPay, goi: goi, clock: () => now), isFalse);
    expect(coQuyenNen(MaQuyen.goalAutoDeposit, goi: goi, clock: () => now), isTrue);
  });

  test('chưa có phiên → true (không có lượt nào chạy; không đoán)', () {
    final goi = GoiRepository(api: _ApiIm(), kho: InMemoryGoiStore(), clock: () => now);
    addTearDown(goi.dispose);
    expect(coQuyenNen(MaQuyen.billAutoPay, goi: goi, clock: () => now), isTrue);
  });

  group('noiKhiQuyenDoi — quyền nền đổi → gọi lại (B1, spec 2026-10-27 mục 5)', () {
    const nhac = {MaQuyen.dailyRecordingReminder, MaQuyen.billReminderNotifications};
    Future<void> nghi() => Future<void>.delayed(Duration.zero);

    test('⭐ lamMoi đổi daily_recording_reminder → gọi ĐÚNG MỘT lần với tài khoản; lamMoi lặp không đổi → không gọi',
        () async {
      final api = _ApiTra({'accountType': 'Basic', 'features': {'daily_recording_reminder': true}});
      final goi = GoiRepository(api: api, kho: InMemoryGoiStore(), clock: () => now);
      addTearDown(goi.dispose);
      final goiLai = <int>[];
      final sub = noiKhiQuyenDoi(goi, nhac, (id) async => goiLai.add(id), clock: () => now);
      addTearDown(sub.cancel);
      await goi.datTaiKhoan(10);
      await goi.lamMoi();
      await nghi();
      expect(goiLai, isEmpty, reason: 'true = mặc định khi thiếu → không đổi');
      api.json = {'accountType': 'Basic', 'features': {'daily_recording_reminder': false}};
      await goi.lamMoi();
      await nghi();
      expect(goiLai, [10]);
      await goi.lamMoi();
      await nghi();
      expect(goiLai, [10], reason: 'lamMoi lặp (resumed 5 phút, socket) không đổi quyền → resync không chạy vô cớ');
    });

    test('quyền NGOÀI tập đổi → không gọi', () async {
      final api = _ApiTra({'accountType': 'Basic', 'features': {'export_reports': false}});
      final goi = GoiRepository(api: api, kho: InMemoryGoiStore(), clock: () => now);
      addTearDown(goi.dispose);
      final goiLai = <int>[];
      final sub = noiKhiQuyenDoi(goi, nhac, (id) async => goiLai.add(id), clock: () => now);
      addTearDown(sub.cancel);
      await goi.datTaiKhoan(10);
      await goi.lamMoi();
      await nghi();
      expect(goiLai, isEmpty);
    });

    test('đăng xuất (xoaPhien) → không gọi dù quyền về mặc định', () async {
      final api = _ApiTra({'accountType': 'Basic', 'features': {'daily_recording_reminder': false}});
      final goi = GoiRepository(api: api, kho: InMemoryGoiStore(), clock: () => now);
      addTearDown(goi.dispose);
      final goiLai = <int>[];
      final sub = noiKhiQuyenDoi(goi, nhac, (id) async => goiLai.add(id), clock: () => now);
      addTearDown(sub.cancel);
      await goi.datTaiKhoan(10);
      await goi.lamMoi();
      await nghi();
      expect(goiLai, [10]);
      goi.xoaPhien();
      await nghi();
      expect(goiLai, [10], reason: 'không phiên → không có tài khoản để resync');
    });
  });
}

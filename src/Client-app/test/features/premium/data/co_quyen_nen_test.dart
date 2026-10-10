import 'package:flowmoney/features/premium/data/co_quyen_nen.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
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
}

/// `GoiCubit` mỏng: phản chiếu `GoiRepository.theoDoi`, `laPremium` theo giờ
/// máy lúc hỏi (spec Premium 6.3 — hết hạn offline tự về Basic).
library;

import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/cubit/goi_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiGia implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() async => const {
        'accountType': 'Premium',
        'premiumExpiresAt': '2026-11-05T00:00:00.000Z',
      };
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) =>
      throw UnimplementedError();
}

void main() {
  test('state ban đầu = hienTai của repo; repo phát → cubit phát; laPremium theo giờ máy',
      () async {
    var now = DateTime(2026, 10, 6, 10);
    final repo = GoiRepository(
        api: _ApiGia(), kho: InMemoryGoiStore(), clock: () => now);
    final cubit = GoiCubit(repo, clock: () => now);
    expect(cubit.state.loai, LoaiGoi.basic);
    expect(cubit.laPremium, isFalse);

    await repo.datTaiKhoan(10);
    await cubit.lamMoi();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.laPremium(now), isTrue);
    expect(cubit.laPremium, isTrue);

    // Giờ máy trôi qua hạn mà không có sự kiện nào → Basic ở lần hỏi kế.
    now = DateTime(2026, 11, 6);
    expect(cubit.laPremium, isFalse,
        reason: 'hết hạn offline tự về Basic — không cần server báo');

    await cubit.close();
    await repo.dispose();
  });
}

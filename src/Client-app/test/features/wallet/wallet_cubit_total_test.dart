import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tổng tài sản mà `WalletCubit` phát ra ngay sau khi thêm ví.
///
/// `getTotalBalance` của repository lọc `includeInTotal` đúng, nhưng Cubit tự
/// tính lại một lần nữa trong `addWallet` bằng `fold` trên **mọi** ví — không
/// lọc gì. Nó tự khỏi ở lượt `loadWallets` ngay sau đó, nên chỉ sai một nhịp;
/// nhưng nhịp ấy là đúng cái người dùng đang nhìn khi vừa bấm "Lưu", và con số
/// nhảy hai lần trên màn hình.
class _RepoGia implements WalletRepository {
  _RepoGia(this._vi);

  final List<WalletEntity> _vi;

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => List.of(_vi);

  @override
  Stream<List<WalletEntity>> watchAll(int idaccount) => Stream.value(List.of(_vi));

  @override
  Future<WalletEntity?> getById(String id) async =>
      _vi.where((w) => w.id == id).firstOrNull;

  @override
  Future<WalletEntity?> getDefault(int idaccount) async =>
      _vi.where((w) => w.isDefault).firstOrNull;

  @override
  Future<WalletEntity> addWallet({
    required int idaccount,
    required String name,
    required String type,
    required double balance,
    String currency = 'VND',
    String icon = 'wallet',
    String colour = '#4CAF50',
    bool isDefault = false,
    bool includeInTotal = true,
  }) async {
    final w = WalletEntity(
      id: 'w_$name',
      idaccount: idaccount,
      name: name,
      type: type,
      balance: balance,
      includeInTotal: includeInTotal,
      updatedAt: DateTime(2026, 9, 9),
    );
    _vi.add(w);
    return w;
  }

  @override
  Future<void> updateWallet(WalletEntity wallet) async {}

  @override
  Future<void> deleteWallet(String id) async => _vi.removeWhere((w) => w.id == id);

  @override
  Future<double> getTotalBalance(int idaccount) async => _vi
      .where((w) => w.includeInTotal)
      .fold<double>(0.0, (s, w) => s + w.balance);
}

WalletEntity vi(String id, double balance, {required bool tinhVaoTong}) =>
    WalletEntity(
      id: id,
      idaccount: 7,
      name: 'Ví $id',
      type: 'cash',
      balance: balance,
      includeInTotal: tinhVaoTong,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  test('tổng phát ra sau khi thêm ví phải bỏ ví không tính vào tổng', () async {
    // Ví 'ngoai' mang 900.000đ và bị loại khỏi tổng — đúng thứ phân biệt được
    // hai cách cài đặt: `fold` trên mọi ví cho 1.050.000đ, luật đúng cho
    // 150.000đ.
    final repo = _RepoGia([
      vi('trong', 100000, tinhVaoTong: true),
      vi('ngoai', 900000, tinhVaoTong: false),
    ]);
    final cubit = WalletCubit(repository: repo);
    addTearDown(cubit.close);

    final tong = <double>[];
    final sub = cubit.stream.listen((s) {
      if (s is WalletOperationSuccess) tong.add(s.totalBalance);
    });

    await cubit.loadWallets(7);
    await cubit.addWallet(
      idaccount: 7,
      name: 'moi',
      type: 'cash',
      balance: 50000,
    );
    await sub.cancel();

    expect(tong, [150000.0],
        reason: 'Cubit tự cộng lại tổng thay vì hỏi `getTotalBalance`, và phép '
            'cộng ấy không lọc `includeInTotal` — nên con số hiện ngay sau khi '
            'bấm Lưu cộng cả ví mà người dùng đã cố ý loại ra, rồi nhảy về '
            'đúng ở lượt tải lại.');
  });
}

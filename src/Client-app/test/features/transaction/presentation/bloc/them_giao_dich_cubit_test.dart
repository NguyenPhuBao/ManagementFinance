// test/features/transaction/presentation/bloc/them_giao_dich_cubit_test.dart
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/services/category_suggestion_engine.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/tach_giao_dich.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/them_giao_dich_cubit.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/them_giao_dich_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/them_giao_dich_nguon_gia.dart';
import '../../../category/presentation/category_test_fakes.dart';

final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt').copyWith(isDefault: false);
final tcb = makeWallet(id: 'tcb', name: 'Techcombank').copyWith(type: 'bank');
final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
final diChuyen = makeCategory(id: 'move', name: 'Di chuyển', isDefault: true);
final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);
final choVay = makeCategory(id: 'chovay', name: 'Cho vay', classify: 'vay_no', isDefault: true);

ThemGiaoDichCubit taoCubit(
  NguonThemGiaoDichGia nguon, {
  int? taiKhoan = 1,
  TransactionEntity? dangSua,
  Category? danhMucDangSua,
  String? huongBanDau,
  DienSanBienDong? bienDong,
  bool choTickMon = false,
}) {
  final c = ThemGiaoDichCubit(
    nguon: nguon,
    taiKhoan: () => taiKhoan,
    boGoiY: const CategorySuggestionEngine(),
    dangSua: dangSua,
    danhMucDangSua: danhMucDangSua,
    huongBanDau: huongBanDau,
    bienDong: bienDong,
    choTickMon: choTickMon,
  );
  // Đóng sau mỗi ca: `ghiChuDoi` / `dienKetQua` để lại hẹn giờ 300 ms thật — sống quá ca là phát state vào ca sau.
  // Gọi `close()` hai lần (ca tự đóng) là vô hại.
  addTearDown(c.close);
  return c;
}

TransactionEntity giaoDichCu({String type = 'chi', String? categoryId = 'food', double amount = 45000}) =>
    TransactionEntity(
      id: 'tx-cu',
      walletId: 'cash',
      idaccount: 1,
      categoryId: categoryId,
      walletTransfer: null,
      goalId: 'goal-1',
      amount: amount,
      type: type,
      note: 'phở',
      date: DateTime(2026, 9, 3, 7, 30),
      images: const ['a.jpg'],
      syncStatus: 'synced',
      isDeleted: false,
      updatedAt: DateTime(2026, 9, 3),
    );

void main() {
  group('state', () {
    test('copyWith xoá được từng trường nullable về null (không "dính")', () {
      final s = ThemGiaoDichState(laSua: false, huong: 'chi', chuoiSoTien: '0', hienBanPhimSo: true, ngay: DateTime(2026))
          .copyWith(viNguon: tcb, viDich: tienMat, danhMuc: anUong, chieuNo: 'chi', duongDanAnh: 'x');
      final xoa = s.copyWith(viNguon: null, viDich: null, danhMuc: null, chieuNo: null, duongDanAnh: null);
      expect([xoa.viNguon, xoa.viDich, xoa.danhMuc, xoa.chieuNo, xoa.duongDanAnh], everyElement(isNull));
      expect(s.copyWith().viNguon, tcb, reason: 'không truyền = giữ nguyên');
    });

    test('loaiGhi suy từ danh mục; vay/nợ theo chiều nợ; chuyển là transfer', () {
      final s = ThemGiaoDichState(laSua: false, huong: 'chi', chuoiSoTien: '0', hienBanPhimSo: true, ngay: DateTime(2026));
      expect(s.loaiGhi, isNull);
      expect(s.copyWith(danhMuc: luong).loaiGhi, 'thu');
      expect(s.copyWith(danhMuc: choVay, chieuNo: 'thu').loaiGhi, 'thu');
      expect(s.copyWith(huong: 'transfer').loaiGhi, 'transfer');
    });
  });

  group('mở trang', () {
    test('tạo mới: ví mặc định chọn sẵn, ví đích là ví KHÁC; hết "đang nạp"', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat, tcb.copyWith(isDefault: true)]));
      await c.moTrang();
      expect(c.state.viNguon?.id, 'tcb');
      expect(c.state.viDich?.id, 'cash');
      expect(c.state.dangNapVi, isFalse);
    });

    test('đường SỬA: điền sẵn từ giao dịch, ví của giao dịch thắng ví mặc định', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat, tcb.copyWith(isDefault: true)]),
          dangSua: giaoDichCu(), danhMucDangSua: anUong);
      expect(c.state.chuoiSoTien, '45000');
      expect(c.state.ghiChu, 'phở');
      expect(c.state.hienBanPhimSo, isFalse);
      await c.moTrang();
      expect(c.state.viNguon?.id, 'cash');
    });

    test('đường SỬA số lẻ giữ dấu chấm thô ("12.5"), không làm tròn', () {
      final c = taoCubit(NguonThemGiaoDichGia(), dangSua: giaoDichCu(amount: 12.5), danhMucDangSua: anUong);
      expect(c.state.chuoiSoTien, '12.5');
    });

    test('huongBanDau đặt đoạn; giá trị lạ bị bỏ', () {
      expect(taoCubit(NguonThemGiaoDichGia(), huongBanDau: 'thu').state.huong, 'thu');
      expect(taoCubit(NguonThemGiaoDichGia(), huongBanDau: 'xyz').state.huong, 'chi');
    });

    test('form biến động có số tiền → 16 phím ẨN ngay từ đầu (không chớp lên rồi tắt)', () {
      const d = DienSanBienDong(khoa: 'bienDong:x', nguon: 'MB Bank', ghiChu: '', soTien: 50000);
      expect(taoCubit(NguonThemGiaoDichGia(), bienDong: d).state.hienBanPhimSo, isFalse);
      expect(taoCubit(NguonThemGiaoDichGia()).state.hienBanPhimSo, isTrue);
    });

    test('⭐ G38: không phiên → không ví nào (chốt "chọn ví" chặn lưu)', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tcb]), taiKhoan: null);
      await c.moTrang();
      expect(c.state.vi, isEmpty);
      expect(c.state.viNguon, isNull);
    });
  });

  group('bất biến 1 — ví hay dùng không đè lựa chọn', () {
    NguonThemGiaoDichGia nguon() => NguonThemGiaoDichGia(
          vi: [tienMat, tcb.copyWith(isDefault: true)],
          lichSu: (viHayDung: const {'food': 'cash'}, boPhanLoai: null, boSoTien: null, mauDeXuat: null),
        );

    test('chọn danh mục → ví hay dùng của danh mục ấy', () async {
      final c = taoCubit(nguon());
      await c.moTrang();
      c.chonDanhMuc(anUong);
      expect(c.state.viNguon?.id, 'cash');
    });

    test('⭐ người dùng đã chọn ví thì phép đoán KHÔNG đè', () async {
      final c = taoCubit(nguon());
      await c.moTrang();
      c.chonVi(tcb);
      c.chonDanhMuc(anUong);
      expect(c.state.viNguon?.id, 'tcb');
    });

    test('đường sửa: ví của giao dịch là sự thật, phép đoán không chen', () async {
      final c = taoCubit(nguon(), dangSua: giaoDichCu(), danhMucDangSua: diChuyen);
      await c.moTrang();
      c.chonDanhMuc(anUong);
      expect(c.state.viNguon?.id, 'cash', reason: 'ví của giao dịch cũ, không phải do bảng ví hay dùng');
      c.chonVi(tcb);
      c.chonDanhMuc(anUong);
      expect(c.state.viNguon?.id, 'tcb');
    });

    test('tra không thấy ví trong bảng → GIỮ ví đang có', () async {
      final c = taoCubit(nguon());
      await c.moTrang();
      c.chonDanhMuc(diChuyen);
      expect(c.state.viNguon?.id, 'tcb');
    });
  });

  group('bất biến 2 — chiều và danh mục', () {
    test('chọn đoạn Thu bỏ danh mục CHI; chọn danh mục thu thì đoạn nhảy về Thu', () async {
      final c = taoCubit(NguonThemGiaoDichGia());
      c.chonDanhMuc(anUong);
      c.chonHuong('thu');
      expect(c.state.danhMuc, isNull);
      c.chonDanhMuc(luong);
      expect(c.state.huong, 'thu');
    });

    test('vay/nợ: đoạn Chi/Thu chính là chiều tiền', () {
      final c = taoCubit(NguonThemGiaoDichGia());
      c.chonDanhMuc(choVay);
      c.chonHuong('thu');
      expect(c.state.danhMuc?.id, 'chovay');
      expect(c.state.chieuNo, 'thu');
      c.chonChieuNo('chi');
      expect(c.state.huong, 'chi');
    });

    test('đoạn khác Chi bỏ mọi phần tách; danh mục chính trùng một phần thì phần ấy gộp vào chính', () {
      final c = taoCubit(NguonThemGiaoDichGia());
      c.chonDanhMuc(anUong);
      const p = PhanTach(categoryId: 'move', soTien: 10000);
      c.luuPhan(p);
      expect(c.state.phanTach, [p]);
      c.chonDanhMuc(diChuyen);
      expect(c.state.phanTach, isEmpty, reason: 'gopKhiDoiDanhMucChinh');
      c.luuPhan(const PhanTach(categoryId: 'food', soTien: 5000));
      c.chonHuong('thu');
      expect(c.state.phanTach, isEmpty);
    });
  });

  group('số tiền', () {
    test('gõ phím đi qua themPhimSoTien (trần 13 chữ số)', () {
      final c = taoCubit(NguonThemGiaoDichGia());
      for (var i = 0; i < 20; i++) {
        c.goPhim('9');
      }
      expect(c.state.chuoiSoTien.length, 13);
    });

    test('chạm khối số tiền: bàn phím hệ thống đang mở → MỞ 16 phím; không thì đảo', () {
      final c = taoCubit(NguonThemGiaoDichGia());
      c.chamSoTien(banPhimHeThongMo: false);
      expect(c.state.hienBanPhimSo, isFalse);
      c.chamSoTien(banPhimHeThongMo: true);
      expect(c.state.hienBanPhimSo, isTrue);
      c.chamSoTien(banPhimHeThongMo: true);
      expect(c.state.hienBanPhimSo, isTrue);
    });

    test('chọn số (chip / điền sẵn) ẩn 16 phím, cùng trần', () {
      final c = taoCubit(NguonThemGiaoDichGia());
      c.chonSoTien(1e17);
      expect(c.state.chuoiSoTien.length, 13);
      expect(c.state.hienBanPhimSo, isFalse);
    });
  });

  test('danhMucChoTach chỉ danh mục CHI hợp lệ và nạp bảng tra cho khối tách', () async {
    final c = taoCubit(NguonThemGiaoDichGia(danhMuc: [anUong, luong]));
    final ds = await c.danhMucChoTach();
    expect(ds.map((x) => x.id), ['food']);
    expect(c.state.dmTheoId.keys, ['food']);
  });
}

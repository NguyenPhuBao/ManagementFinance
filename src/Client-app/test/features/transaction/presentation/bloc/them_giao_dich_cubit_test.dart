// test/features/transaction/presentation/bloc/them_giao_dich_cubit_test.dart
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/services/category_suggestion_engine.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart' show kKetQuaGoiYBoQua, kKetQuaGoiYChon;
import 'package:flowmoney/features/category/domain/phan_loai_so_tien.dart';
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

  /// Mười hai mẫu chi ví cash: Ăn uống 6 × 30.000 · Di chuyển 6 × 7.000 (chép `add_transaction_goi_y_so_tien_test`).
  final muoiMauTien = mauSoTienTu([
    for (final d in [1, 2, 3, 5, 6, 12])
      (loai: 'chi', categoryId: 'food', ghiChu: '', soTien: 30000.0, walletId: 'cash', ngay: DateTime(2026, 9, d), daXoa: false),
    for (final d in [1, 2, 3, 5, 6, 12])
      (loai: 'chi', categoryId: 'move', ghiChu: '', soTien: 7000.0, walletId: 'cash', ngay: DateTime(2026, 9, d), daXoa: false),
  ]);

  NguonThemGiaoDichGia nguonSoTien() => NguonThemGiaoDichGia(
        vi: [tienMat.copyWith(isDefault: true)],
        danhMuc: [anUong, diChuyen, luong],
        lichSu: (viHayDung: const {}, boPhanLoai: null, boSoTien: BoPhanLoaiSoTien.hoc(muoiMauTien), mauDeXuat: null),
      );

  group('bất biến 5 — thẻ theo số tiền chỉ khi ghi chú TRỐNG', () {
    test('gõ 30.000, ghi chú trống → thẻ Ăn uống nguồn số tiền, bộ đếm cuộn tăng', () {
      fakeAsync((fa) {
        final c = taoCubit(nguonSoTien());
        c.moTrang();
        fa.flushMicrotasks();
        for (final k in ['3', '0', '0', '0', '0']) {
          c.goPhim(k);
        }
        fa.elapse(const Duration(milliseconds: 350));
        expect(c.state.goiY?.categoryId, 'food');
        expect(c.state.goiY?.nguon, kNguonGoiYSoTien);
        expect(c.state.soLanCuonGoiY, 1);
      });
    });

    test('⭐ chữ đầu vào ô ghi chú gỡ thẻ số tiền NGAY (không chờ 300 ms)', () {
      fakeAsync((fa) {
        final c = taoCubit(nguonSoTien());
        c.moTrang();
        fa.flushMicrotasks();
        for (final k in ['3', '0', '0', '0', '0']) {
          c.goPhim(k);
        }
        fa.elapse(const Duration(milliseconds: 350));
        c.ghiChuDoi('c');
        expect(c.state.goiY, isNull);
      });
    });

    test('đường sửa không có nguồn số tiền', () {
      fakeAsync((fa) {
        final c = taoCubit(nguonSoTien(), dangSua: giaoDichCu(categoryId: null), danhMucDangSua: null);
        c.moTrang();
        fa.flushMicrotasks();
        c.ghiChuDoi('');
        c.goPhim('0');
        fa.elapse(const Duration(milliseconds: 350));
        expect(c.state.goiY, isNull);
      });
    });
  });

  group('bất biến 4 (một nửa) — kết quả về muộn bị bỏ', () {
    test('số tiền đổi trong lúc chờ danh mục → gợi ý của lượt cũ không hiện', () {
      fakeAsync((fa) {
        final nguon = nguonSoTien();
        final c = taoCubit(nguon);
        c.moTrang();
        fa.flushMicrotasks();
        // Giữ lượt tính đang chờ danh mục cho tới khi test thả — `elapse` chạy luôn vi tác vụ, không giữ thì lượt ấy
        // xong ngay trong `elapse` và ca không đo được gì.
        final cho = Completer<List<Category>>();
        nguon.choDanhMuc = cho;
        for (final k in ['3', '0', '0', '0', '0']) {
          c.goPhim(k);
        }
        fa.elapse(const Duration(milliseconds: 300)); // hẹn giờ nổ, lượt tính treo ở `danhMucChonDuoc`
        c.goPhim('0'); // 300.000 — đổi bậc giữa chừng
        cho.complete([anUong, diChuyen, luong]);
        fa.flushMicrotasks();
        expect(c.state.goiY, isNull, reason: 'kết quả của 30.000 về sau khi số tiền đã đổi');
      });
    });
  });

  group('bất biến 4 (nửa còn lại) — đường từ khoá', () {
    // ⚠️ Ca "số tiền đổi trong lúc chờ" ở trên KHÔNG bắt được việc bỏ vế `chuoiSoTien` của phép so lúc về: nguồn số tiền
    // tính SAU lần chờ danh mục, bằng state hiện tại, nên lượt cũ vốn ra `null`. Chỉ đường từ khoá (ghi chú có chữ) mới
    // mang kết quả của đúng lúc hỏi — ca này là ca duy nhất canh vế ấy.
    test('ghi chú có chữ, số tiền đổi trong lúc chờ → thẻ từ khoá của lượt cũ không hiện', () {
      fakeAsync((fa) {
        final nguon = nguonSoTien()..bangTuKhoa = {'food': ['pho']};
        final c = taoCubit(nguon);
        c.moTrang();
        fa.flushMicrotasks();
        final cho = Completer<List<Category>>();
        nguon.choDanhMuc = cho;
        c.ghiChuDoi('pho');
        fa.elapse(const Duration(milliseconds: 300));
        c.goPhim('5');
        cho.complete([anUong, diChuyen, luong]);
        fa.flushMicrotasks();
        expect(c.state.goiY, isNull);
      });
    });

    test('đối chứng: không đổi gì trong lúc chờ → thẻ từ khoá hiện', () {
      fakeAsync((fa) {
        final nguon = nguonSoTien()..bangTuKhoa = {'food': ['pho']};
        final c = taoCubit(nguon);
        c.moTrang();
        fa.flushMicrotasks();
        c.ghiChuDoi('pho');
        fa.elapse(const Duration(milliseconds: 350));
        expect(c.state.goiY?.categoryId, 'food');
      });
    });
  });

  group('bất biến 6 — phản hồi gợi ý', () {
    test('chọn thẻ → ghi "chon" với đúng danh mục, rồi đặt danh mục qua chonDanhMuc', () {
      fakeAsync((fa) {
        final nguon = nguonSoTien();
        final c = taoCubit(nguon);
        c.moTrang();
        fa.flushMicrotasks();
        for (final k in ['3', '0', '0', '0', '0']) {
          c.goPhim(k);
        }
        fa.elapse(const Duration(milliseconds: 350));
        c.chonGoiY(c.state.goiY!);
        expect(nguon.phanHoiDaGhi.single, (goiY: 'food', ketQua: kKetQuaGoiYChon, chon: 'food'));
        expect(c.state.danhMuc?.id, 'food');
        expect(c.state.goiY, isNull);
      });
    });

    test('bỏ qua thẻ số tiền → ghi "bo_qua", cặp ấy im tới hết lượt mở màn', () {
      fakeAsync((fa) {
        final nguon = nguonSoTien();
        final c = taoCubit(nguon);
        c.moTrang();
        fa.flushMicrotasks();
        for (final k in ['3', '0', '0', '0', '0']) {
          c.goPhim(k);
        }
        fa.elapse(const Duration(milliseconds: 350));
        c.boQuaGoiY(c.state.goiY!);
        expect(nguon.phanHoiDaGhi.single.ketQua, kKetQuaGoiYBoQua);
        c.goPhim('0');
        c.goPhim('backspace');
        fa.elapse(const Duration(milliseconds: 350));
        expect(c.state.goiY, isNull);
      });
    });
  });

  test('ghiChuDoi trùng chữ không làm gì (trang chép ô → Cubit không vòng lặp)', () {
    final c = taoCubit(NguonThemGiaoDichGia());
    c.ghiChuDoi('abc');
    final truoc = c.state;
    c.ghiChuDoi('abc');
    expect(identical(c.state, truoc), isTrue);
  });

  test('close() huỷ hẹn giờ — không phát state sau khi đóng', () {
    fakeAsync((fa) {
      // Dựng thẳng, KHÔNG qua `taoCubit`: nó thêm `addTearDown(c.close)` chạy ngoài vùng giả, mà đóng một Cubit lần hai
      // sau khi lần đầu đóng trong `fakeAsync` thì treo (`_stateController.close()` đợi một vi tác vụ đã chết cùng vùng).
      final c = ThemGiaoDichCubit(
        nguon: nguonSoTien(),
        taiKhoan: () => 1,
        boGoiY: const CategorySuggestionEngine(),
      );
      c.moTrang();
      fa.flushMicrotasks();
      c.goPhim('3');
      c.close();
      // Ngay sau `close()`, chưa `elapse`: hẹn giờ 300 ms mà không bị huỷ thì còn nằm trong hàng đợi ở đây.
      expect(fa.pendingTimers, isEmpty, reason: 'close() phải huỷ cả ba hẹn giờ');
      fa.elapse(const Duration(seconds: 1));
      expect(fa.pendingTimers, isEmpty);
    });
  });
}

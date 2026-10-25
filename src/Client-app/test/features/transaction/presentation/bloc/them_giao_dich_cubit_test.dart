// test/features/transaction/presentation/bloc/them_giao_dich_cubit_test.dart
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart' show LoaiThongBao;
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/domain/category_suggestion_engine.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart'
    show kKetQuaGoiYBoQua, kKetQuaGoiYChon, kKetQuaGoiYKhac, kNguonGoiYHoc;
import 'package:flowmoney/features/category/domain/phan_loai_so_tien.dart';
import 'package:flowmoney/features/transaction/domain/mau_hoc_danh_muc.dart';
import 'package:flowmoney/features/transaction/data/doc_cau_bang_ai.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_cau_giao_dich.dart';
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
  CategoryEntity? danhMucDangSua,
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

/// AI giả: `sanSang` luôn đúng, `doc` treo tới khi test trả [ketQua].
class _DocAiGia implements DocCauBangAi {
  final ketQua = Completer<KetQuaAi?>();
  int soLanHuy = 0;
  @override
  Future<bool> Function() get sanSang => () async => true;
  @override
  Future<bool> chuanBi() async => true;
  @override
  Future<KetQuaAi?> doc(String cau,
          {required DateTime now, required List<String> tenVi, required List<String> tenDanhMuc}) =>
      ketQua.future;
  @override
  Future<void> huy() async => soLanHuy++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Cubit cho phép ÉP state — chỉ để chạm chốt "chiều tiền" của `chuanBiLuu` mà API công khai không dẫn tới được:
/// `suggestDebtDirection` luôn trả `chi` / `thu`, nên danh mục vay/nợ chọn qua `chonDanhMuc` luôn có `chieuNo`.
class _CubitEpState extends ThemGiaoDichCubit {
  _CubitEpState(NguonThemGiaoDichGia nguon)
      : super(nguon: nguon, taiKhoan: () => 1, boGoiY: const CategorySuggestionEngine());
  void ep(ThemGiaoDichState s) => emit(s);
}

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
      expect(s.copyWith(danhMuc: choVay).loaiGhi, isNull,
          reason: 'vay/nợ mà chưa có chiều tiền → chưa đủ dữ kiện (tiền đề của câu "Vui lòng chọn chiều tiền")');
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
        final cho = Completer<List<CategoryEntity>>();
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
        final cho = Completer<List<CategoryEntity>>();
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

  group('bất biến 3 — dienKetQua đi đúng đường', () {
    test('⭐ chiều → số tiền (trần) → ví đặt cờ → danh mục → ghi chú SAU danh mục', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tienMat, tcb.copyWith(isDefault: true)], danhMuc: [anUong, luong]);
      final c = taoCubit(nguon);
      await c.moTrang();
      c.dienKetQua(
        const KetQuaDocCau(soTien: 1e17, loai: 'thu', walletId: 'cash', categoryId: 'luong', ghiChu: 'lương tháng'),
        chonDuoc: [anUong, luong],
      );
      expect(c.state.huong, 'thu');
      expect(c.state.chuoiSoTien.length, 13);
      expect(c.state.hienBanPhimSo, isFalse);
      expect(c.state.viNguon?.id, 'cash');
      expect(c.state.danhMuc?.id, 'luong');
      expect(c.state.ghiChu, 'lương tháng');
      expect(c.state.soLanDatGhiChu, 1, reason: 'trang chỉ chép sang ô khi bộ đếm tăng');
      expect(c.state.ketQuaDien?.docDuoc, isTrue);
      expect(c.state.goiY, isNull, reason: 'đã có danh mục → không hẹn thẻ gợi ý');
    });

    test('ví đọc từ câu KHÔNG bị ví hay dùng của danh mục đè', () async {
      final nguon = NguonThemGiaoDichGia(
        vi: [tienMat, tcb.copyWith(isDefault: true)],
        lichSu: (viHayDung: const {'food': 'tcb'}, boPhanLoai: null, boSoTien: null, mauDeXuat: null),
      );
      final c = taoCubit(nguon);
      await c.moTrang();
      c.dienKetQua(const KetQuaDocCau(walletId: 'cash', categoryId: 'food', ghiChu: ''), chonDuoc: [anUong]);
      expect(c.state.viNguon?.id, 'cash');
    });

    test('câu chỉ nêu ví đích trùng ví nguồn đang chọn → ví nguồn TRỐNG (§2.9)', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat, tcb.copyWith(isDefault: true)]));
      await c.moTrang();
      c.dienKetQua(const KetQuaDocCau(loai: 'transfer', walletToId: 'tcb', ghiChu: ''), chonDuoc: const []);
      expect(c.state.viDich?.id, 'tcb');
      expect(c.state.viNguon, isNull);
    });

    test('không đọc được gì → câu mời điền tay, không ô nào đổi', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tcb.copyWith(isDefault: true)]));
      await c.moTrang();
      c.dienKetQua(const KetQuaDocCau(ghiChu: 'xin chào'), chonDuoc: const []);
      expect(c.state.ketQuaDien?.tomTat, kCauChuaDocDuoc);
      expect(c.state.ghiChu, '');
    });

    test('⭐ ghi chú đặt SAU danh mục → KHÔNG hẹn lượt tính thẻ gợi ý (chỉ còn hẹn đề xuất từ khoá)', () {
      fakeAsync((fa) {
        // Dựng thẳng, không qua `taoCubit` (xem ca "close() huỷ hẹn giờ").
        final c = ThemGiaoDichCubit(
          nguon: NguonThemGiaoDichGia(
            vi: [tcb.copyWith(isDefault: true)],
            danhMuc: [luong],
            bangTuKhoa: {'luong': ['lương']},
          ),
          taiKhoan: () => 1,
          boGoiY: const CategorySuggestionEngine(),
        );
        c.moTrang();
        fa.flushMicrotasks();
        final truoc = fa.pendingTimers.length;
        c.dienKetQua(const KetQuaDocCau(categoryId: 'luong', ghiChu: 'lương tháng'), chonDuoc: [luong]);
        // Ghi chú thấy đã có danh mục thì chỉ hẹn đề xuất từ khoá; đặt TRƯỚC danh mục là hẹn thêm một lượt gợi ý thừa.
        expect(fa.pendingTimers.length - truoc, 1);
        c.close();
        fa.elapse(const Duration(seconds: 1));
      });
    });
  });

  test('bất biến 4 — kết quả AI về sau khi bấm Huỷ bị BỎ, form điền bằng luật', () async {
    final ai = _DocAiGia();
    final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat.copyWith(isDefault: true)], danhMuc: [anUong], docAiGia: ai));
    await c.moTrang();
    // C4 2026-10-12: luật chọn N2 đọc "mất ba chục" nên câu phương tiện đổi sang "45 ở quán" (luật không đọc → ô thiếu).
    final dien = c.dienTuCau('cà phê 45 ở quán');
    await Future<void>.delayed(Duration.zero);
    expect(c.state.dangDocAi, isTrue, reason: 'tiền đề: câu này có ô thiếu nên đi đường AI');
    await c.huyDocAi('cà phê 45 ở quán');
    expect(ai.soLanHuy, 1);
    ai.ketQua.complete(KetQuaAi.tuThamSo({
      'so_tien': 45000,
      'loai': 'chi',
      'ngay': '',
      'vi': '',
      'vi_den': '',
      'danh_muc': '',
      'ghi_chu': '',
    }));
    await dien;
    expect(c.state.chuoiSoTien, '0', reason: 'số AI của lượt đã huỷ không được điền');
    expect(c.state.dangDocAi, isFalse);
  });

  test('C4 kiểm chéo: câu chỉ có số tiền nói, AI khác → tóm tắt RỖNG nhưng vẫn giữ nguồn / cảnh báo (preflight Task 9→14)',
      () async {
    final ai = _DocAiGia();
    final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat.copyWith(isDefault: true)], danhMuc: [anUong], docAiGia: ai));
    await c.moTrang();
    final dien = c.dienTuCau('tiền điện một triệu hai, tiền nhà 2 tr 5');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 2026-10-22: AI phải chọn số tiền KHÁC (tiền nhà) mới là lệch — 1.000.000 là bản cụt của chính cụm luật.
    ai.ketQua.complete(KetQuaAi.tuThamSo({
      'so_tien': 2500000,
      'loai': 'chi',
      'ngay': '',
      'vi': '',
      'vi_den': '',
      'danh_muc': '',
      'ghi_chu': '',
    }));
    await dien;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.state.luaChonTienCau, isNotEmpty, reason: 'tiền đề: hai chip');
    final kq = c.state.ketQuaDien;
    expect(kq, isNotNull, reason: 'còn nguồn AI / cảnh báo thì KetQuaDien không bị bỏ');
    expect(kq!.tomTat, '', reason: 'số luật đã rút khỏi form → không còn gì để nói trong "Đã điền"');
    expect(kq.canhBao, isNotEmpty, reason: 'cảnh báo nhiều số tiền được GIỮ khi tóm tắt rỗng');
  });

  group('bất biến 7 — D1 / ảnh quét', () {
    DienSanBienDong tin({String khoa = 'bienDong:a', String? anh}) => DienSanBienDong(
          khoa: khoa,
          nguon: 'MB Bank',
          ghiChu: 'ck',
          soTien: 50000,
          chieu: 'chi',
          duoi: '7777',
          thoiGian: DateTime(2026, 10, 1, 12, 1),
          anh: anh,
        );

    test('⭐ lần đầu của cặp nguồn + đuôi → ví TRỐNG (không ví mặc định)', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tcb.copyWith(isDefault: true)]), bienDong: tin());
      await c.moTrang();
      expect(c.state.viNguon, isNull);
      expect(c.state.chuoiSoTien, '50000');
      expect(c.state.ngay, DateTime(2026, 10, 1, 12, 1), reason: 'giờ trong tin là giờ giao dịch');
    });

    test('cặp đã nhớ ví đang dùng → chọn sẵn ví ấy; Lưu không ghi đè bảng', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tcb.copyWith(isDefault: true), tienMat], viNho: {'MB Bank|7777': 'cash'});
      final c = taoCubit(nguon, bienDong: tin());
      await c.moTrang();
      expect(c.state.viNguon?.id, 'cash');
      await c.dongSauLuu();
      expect(nguon.viDaNho, isEmpty);
      expect(nguon.hangDaXoa, ['bienDong:a']);
    });

    test('Lưu lần đầu của cặp → nhớ ví vừa lưu, xoá hàng, xoá ảnh biên lai', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tcb.copyWith(isDefault: true)]);
      final c = taoCubit(nguon, bienDong: tin(anh: 'x.jpg'));
      await c.moTrang();
      c.chonVi(tcb);
      await c.dongSauLuu();
      expect(nguon.viDaNho, ['MB Bank|7777=tcb']);
      expect(nguon.anhBienLaiDaXoa, ['x.jpg']);
    });

    test('A5 ảnh quét: không đọc bảng nguồn → ví, không nhắc trùng; close() xoá ảnh quét (bất biến 10)', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tcb.copyWith(isDefault: true)], so: [
        (id: 't', soTien: 50000, loai: 'chi', ngay: DateTime(2026, 10, 1), ghiChu: ''),
      ]);
      final c = taoCubit(nguon, bienDong: tin(khoa: 'quet:a.jpg', anh: 'a.jpg'));
      await c.moTrang();
      expect(nguon.soLanDocViTheoNguon, 0);
      expect(c.state.viNguon?.id, 'tcb', reason: 'ảnh quét giữ ví mặc định');
      expect(c.state.trungTrongSo, isEmpty);
      await c.close();
      expect(nguon.anhQuetDaXoa, ['a.jpg']);
    });

    test('nhắc trùng: khoản cùng tiền + chiều + ngày trong sổ', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tcb], so: [
        (id: 't', soTien: 50000, loai: 'chi', ngay: DateTime(2026, 10, 1, 8), ghiChu: ''),
      ]);
      final c = taoCubit(nguon, bienDong: tin());
      await c.moTrang();
      expect(c.state.trungTrongSo.map((k) => k.id), ['t']);
    });
  });

  group('bất biến 8–9 — lưu', () {
    Future<ThemGiaoDichCubit> sanSang({int? taiKhoan = 1, NguonThemGiaoDichGia? nguon}) async {
      final c = taoCubit(nguon ?? NguonThemGiaoDichGia(vi: [tcb.copyWith(isDefault: true), tienMat]), taiKhoan: taiKhoan);
      await c.moTrang();
      return c;
    }

    test('thứ tự câu lỗi: số tiền → ví → danh mục', () async {
      final c = await sanSang();
      expect((await c.chuanBiLuu() as LoiLuu).cau, 'Vui lòng nhập số tiền hợp lệ');
      c.goPhim('5');
      c.chonDanhMuc(anUong);
      expect(await c.chuanBiLuu(), isA<SanSangLuu>());
      final khongDm = await sanSang();
      khongDm.goPhim('5');
      expect((await khongDm.chuanBiLuu() as LoiLuu).cau, 'Vui lòng chọn danh mục');
      // Ví đứng TRƯỚC danh mục: không có ví nào VÀ chưa chọn danh mục → câu về ví thắng.
      final khongVi = await sanSang(nguon: NguonThemGiaoDichGia());
      expect((await khongVi.chuanBiLuu() as LoiLuu).cau, 'Vui lòng nhập số tiền hợp lệ',
          reason: 'số tiền đứng trước cả ví');
      khongVi.goPhim('5');
      expect(khongVi.state.viNguon, isNull);
      expect(khongVi.state.danhMuc, isNull);
      expect((await khongVi.chuanBiLuu() as LoiLuu).cau, 'Vui lòng chọn ví thanh toán',
          reason: 'ví phải được kiểm TRƯỚC danh mục — đảo hai chốt là người dùng chưa có ví bị bảo chọn danh mục');
    });

    test('chuyển khoản mà chưa có ví đích → "Vui lòng chọn ví đích" (đứng sau chốt ví nguồn)', () async {
      // Không `moTrang()`: `_napVi` luôn điền ví đích khi đã có ví nguồn, nên ví đích trống chỉ đến được khi người dùng
      // chọn ví nguồn trước lúc danh sách ví về.
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tcb]));
      c.chonVi(tcb);
      c.chonHuong('transfer');
      c.goPhim('5');
      expect(c.state.viDich, isNull);
      expect((await c.chuanBiLuu() as LoiLuu).cau, 'Vui lòng chọn ví đích');
      c.chonViDich(tienMat);
      expect(await c.chuanBiLuu(), isA<SanSangLuu>(), reason: 'chọn ví đích thì qua chốt');
    });

    test('chốt chiều tiền: danh mục vay/nợ mà chưa có chiều → "Vui lòng chọn chiều tiền" (nhánh phòng thủ)', () async {
      // Nhánh này không dẫn tới được bằng API công khai (xem `_CubitEpState`) — ép state để ghim câu chữ của chốt.
      final c = _CubitEpState(NguonThemGiaoDichGia());
      addTearDown(c.close);
      c.ep(c.state.copyWith(viNguon: tcb, danhMuc: choVay, chuoiSoTien: '5'));
      expect(c.state.chieuNo, isNull);
      expect((await c.chuanBiLuu() as LoiLuu).cau, 'Vui lòng chọn chiều tiền');
    });

    test('⭐ G38: có ví mà KHÔNG phiên → không dựng giao dịch nào', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tcb]), taiKhoan: null);
      await c.moTrang();
      c.chonVi(tcb);
      c.goPhim('5');
      c.chonDanhMuc(anUong);
      expect((await c.chuanBiLuu() as LoiLuu).cau, 'Chưa xác định được tài khoản đăng nhập');
    });

    test('biểu thức "50000+30000" lưu 80.000 (A12 — không bỏ dấu chấm, không parse thẳng)', () async {
      final c = await sanSang();
      for (final k in ['5', '0', '0', '0', '0', '+', '3', '0', '0', '0', '0']) {
        c.goPhim(k);
      }
      c.chonDanhMuc(anUong);
      final r = await c.chuanBiLuu() as SanSangLuu;
      expect(r.giaoDich.single.amount, 80000);
    });

    test('đường SỬA giữ id, goalId, ảnh; truoc là giao dịch cũ', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat]), dangSua: giaoDichCu(), danhMucDangSua: anUong);
      await c.moTrang();
      final r = await c.chuanBiLuu() as SanSangLuu;
      final tx = r.giaoDich.single;
      expect([tx.id, tx.goalId, tx.images], ['tx-cu', 'goal-1', ['a.jpg']]);
      expect(r.truoc?.id, 'tx-cu');
      expect(r.laTach, isFalse);
    });

    test('tách: N giao dịch một lô; tra ngân sách hỏng KHÔNG chặn lưu', () async {
      final c = await sanSang(
          nguon: NguonThemGiaoDichGia(vi: [tcb.copyWith(isDefault: true)], nganSach: (_, __) async => throw StateError('hỏng')));
      for (final k in ['5', '0', '0', '0', '0']) {
        c.goPhim(k);
      }
      c.chonDanhMuc(anUong);
      c.luuPhan(const PhanTach(categoryId: 'move', soTien: 10000));
      final r = await c.chuanBiLuu() as SanSangLuu;
      expect(r.laTach, isTrue);
      expect(r.giaoDich, hasLength(2));
      expect(r.canXacNhan, isEmpty);
    });

    test('tách sai (phần còn lại ≤ 0) → câu lỗi của tách', () async {
      final c = await sanSang();
      c.goPhim('5');
      c.chonDanhMuc(anUong);
      c.luuPhan(const PhanTach(categoryId: 'move', soTien: 10000));
      expect((await c.chuanBiLuu() as LoiLuu).cau, 'Phần còn lại phải lớn hơn 0');
    });

    group('câu lỗi của tách — ba mã còn lại', () {
      // Khoản chi 50.000 ở danh mục chính Ăn uống; `luuPhan` không tự kiểm (chỉ `chonDanhMuc` gộp phần trùng).
      Future<ThemGiaoDichCubit> chi50k() async {
        final c = await sanSang();
        for (final k in ['5', '0', '0', '0', '0']) {
          c.goPhim(k);
        }
        c.chonDanhMuc(anUong);
        return c;
      }

      test('một phần không dương → "Mỗi phần phải lớn hơn 0"', () async {
        final c = await chi50k();
        c.luuPhan(const PhanTach(categoryId: 'move', soTien: 0));
        expect((await c.chuanBiLuu() as LoiLuu).cau, 'Mỗi phần phải lớn hơn 0');
      });

      test('phần trùng danh mục chính, hoặc hai phần cùng danh mục → "Mỗi danh mục chỉ một phần"', () async {
        final c = await chi50k();
        c.luuPhan(const PhanTach(categoryId: 'food', soTien: 10000));
        expect((await c.chuanBiLuu() as LoiLuu).cau, 'Mỗi danh mục chỉ một phần');
        final d = await chi50k();
        d.luuPhan(const PhanTach(categoryId: 'move', soTien: 10000));
        d.luuPhan(const PhanTach(categoryId: 'move', soTien: 5000));
        expect((await d.chuanBiLuu() as LoiLuu).cau, 'Mỗi danh mục chỉ một phần');
      });

      test('một món nằm ở hai phần → "Một món chỉ thuộc một phần"', () async {
        final c = await chi50k();
        c.luuPhan(const PhanTach(categoryId: 'move', soTien: 10000, monIds: {1}));
        c.luuPhan(const PhanTach(categoryId: 'shop', soTien: 10000, monIds: {1}));
        expect((await c.chuanBiLuu() as LoiLuu).cau, 'Một món chỉ thuộc một phần');
      });
    });

    test('daGuiLuu tạo mới ghi phản hồi thẻ gợi ý; cauSauLuu nói số giao dịch của lô tách', () async {
      final c = await sanSang();
      for (final k in ['5', '0', '0', '0', '0']) {
        c.goPhim(k);
      }
      c.chonDanhMuc(anUong);
      c.luuPhan(const PhanTach(categoryId: 'move', soTien: 10000));
      final r = await c.chuanBiLuu() as SanSangLuu;
      c.daGuiLuu(r);
      expect(c.cauSauLuu().cau, 'Đã lưu 2 giao dịch');
      expect(c.cauSauLuu().cau, 'Thêm giao dịch thành công!', reason: 'số giao dịch đặt lại về 1 sau khi đọc');
    });

    test('đường SỬA: cauSauLuu nói "Đã lưu thay đổi", loại xong', () async {
      final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat]), dangSua: giaoDichCu(), danhMucDangSua: anUong);
      await c.moTrang();
      c.daGuiLuu(await c.chuanBiLuu() as SanSangLuu);
      final t = c.cauSauLuu();
      expect(t.cau, 'Đã lưu thay đổi');
      expect(t.loai, LoaiThongBao.xong);
    });

    group('ngân sách', () {
      // Ngân sách Ăn uống 100.000 đã chi 90.000, kỳ tháng này; `kieu` quyết chặn (hỏi xác nhận) hay chỉ cảnh báo.
      Future<BudgetView?> Function(int, String) tra(String kieu) => (_, categoryId) async {
            if (categoryId != 'food') return null;
            final now = DateTime.now();
            return BudgetView(
              budget: BudgetEntity(
                id: 'b1',
                idaccount: 1,
                categoryId: 'food',
                amount: 100000,
                spent: 90000,
                overSpending: kieu,
                startDate: DateTime(now.year, now.month, 1),
                recurrence: true,
                updatedAt: now,
              ),
              categoryName: 'Ăn uống',
            );
          };

      test('khoản làm vượt ngân sách CHẶN → canXacNhan có đúng một tác động; cảnh báo thì không hỏi', () async {
        final chan = await sanSang(nguon: NguonThemGiaoDichGia(vi: [tienMat], nganSach: tra(BudgetOverSpending.stop)));
        for (final k in ['2', '0', '0', '0', '0']) {
          chan.goPhim(k);
        }
        chan.chonDanhMuc(anUong);
        final r = await chan.chuanBiLuu() as SanSangLuu;
        expect(r.canXacNhan, hasLength(1));
        expect(r.tacDong?.exceeds, isTrue);

        final canhBao = await sanSang(nguon: NguonThemGiaoDichGia(vi: [tienMat], nganSach: tra(BudgetOverSpending.over)));
        for (final k in ['2', '0', '0', '0', '0']) {
          canhBao.goPhim(k);
        }
        canhBao.chonDanhMuc(anUong);
        final r2 = await canhBao.chuanBiLuu() as SanSangLuu;
        expect(r2.canXacNhan, isEmpty);
        expect(r2.tacDong?.exceeds, isTrue);
        canhBao.daGuiLuu(r2);
        final t = canhBao.cauSauLuu();
        expect(t.cau, contains('đã vượt hạn mức'));
        expect(t.loai, LoaiThongBao.thongTin, reason: 'lưu kèm cảnh báo ngân sách là THÔNG TIN, không phải xong trơn');
        expect(canhBao.cauSauLuu().cau, 'Thêm giao dịch thành công!',
            reason: 'tác động ngân sách xoá ngay khi đã dùng — lần lưu sau không mang lời nhắn cũ');
      });

      test('đường SỬA trừ số cũ khỏi "đã chi" — sửa khoản 45.000 giữ nguyên số không báo vượt oan', () async {
        // Đã chi 90.000 (đã gồm khoản 45.000 đang sửa): 90.000 − 45.000 + 45.000 = 90.000 < 100.000. Không trừ số cũ
        // thì 90.000 + 45.000 = 135.000 → báo vượt và đòi xác nhận một khoản không đổi gì.
        final c = taoCubit(NguonThemGiaoDichGia(vi: [tienMat], nganSach: tra(BudgetOverSpending.stop)),
            dangSua: giaoDichCu().copyWith(date: DateTime.now()), danhMucDangSua: anUong);
        await c.moTrang();
        final r = await c.chuanBiLuu() as SanSangLuu;
        expect(r.canXacNhan, isEmpty);
        expect(r.tacDong?.exceeds, isFalse);
      });
    });

    group('phản hồi thẻ gợi ý', () {
      test('tạo mới: thẻ hiện mà người dùng chọn danh mục KHÁC qua bảng → ghi "khac" lúc daGuiLuu', () {
        fakeAsync((fa) {
          final nguon = nguonSoTien();
          final c = taoCubit(nguon);
          c.moTrang();
          fa.flushMicrotasks();
          for (final k in ['3', '0', '0', '0', '0']) {
            c.goPhim(k);
          }
          fa.elapse(const Duration(milliseconds: 350));
          expect(c.state.goiY?.categoryId, 'food');
          c.chonDanhMuc(diChuyen);
          SanSangLuu? r;
          c.chuanBiLuu().then((x) => r = x as SanSangLuu);
          fa.flushMicrotasks();
          expect(nguon.phanHoiDaGhi, isEmpty, reason: 'chuanBiLuu chưa ghi gì — chỉ khi trang đã gửi event');
          c.daGuiLuu(r!);
          expect(nguon.phanHoiDaGhi.single, (goiY: 'food', ketQua: kKetQuaGoiYKhac, chon: 'move'));
        });
      });

      test('đường SỬA không ghi phản hồi (kể cả khi đang có một thẻ chờ phán xử)', () {
        fakeAsync((fa) {
          final nguon = nguonSoTien();
          final c = taoCubit(nguon, dangSua: giaoDichCu(), danhMucDangSua: anUong);
          c.moTrang();
          fa.flushMicrotasks();
          // Dựng thế "có thẻ chờ phán xử" bằng cửa điền sẵn (Nhập nhanh vốn không có ở đường sửa — chỉ để canh chốt
          // `truoc == null` của daGuiLuu): không có nó thì bản bỏ chốt vẫn xanh vì đường sửa không bao giờ có thẻ.
          c.dienKetQua(
            KetQuaDocCau(
              categoryId: 'food',
              ghiChu: 'pho',
              goiY: CategorySuggestion(
                  category: anUong, matchedKeyword: 'pho', nguon: kNguonGoiYHoc, amTietChinh: 'pho'),
            ),
            chonDuoc: [anUong],
          );
          SanSangLuu? r;
          c.chuanBiLuu().then((x) => r = x as SanSangLuu);
          fa.flushMicrotasks();
          c.daGuiLuu(r!);
          expect(nguon.phanHoiDaGhi, isEmpty);
        });
      });
    });
  });
  // Người dùng chốt 2026-10-16 (vòng lặp học sai mục 5d `CATEGORY_RATIONALE.md`): giao dịch MỚI có danh mục do AI chọn
  // mà người dùng lưu NGUYÊN thì đánh dấu — B1 bỏ nó khỏi mẫu học; mở Sửa rồi Lưu là gỡ dấu.
  group('đánh dấu danh mục do AI chọn', () {
    Future<ThemGiaoDichCubit> dienAi(NguonThemGiaoDichGia nguon, {bool tuAi = true}) async {
      final c = taoCubit(nguon);
      await c.moTrang();
      c.dienKetQua(KetQuaDocCau(soTien: 45000, categoryId: 'food', danhMucTuAi: tuAi, ghiChu: 'bún chả'),
          chonDuoc: [anUong, diChuyen]);
      return c;
    }

    test('⭐ lưu nguyên danh mục AI → đánh dấu đúng giao dịch vừa lưu', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tienMat], danhMuc: [anUong, diChuyen]);
      final c = await dienAi(nguon);
      final r = await c.chuanBiLuu() as SanSangLuu;
      c.daGuiLuu(r);
      expect(nguon.aiDoanDaDanhDau, [(tx: r.giaoDich.single.id, dm: 'food')]);
      expect(nguon.aiDoanDaGo, isEmpty);
    });

    test('đổi sang danh mục khác trước khi lưu → KHÔNG đánh dấu', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tienMat], danhMuc: [anUong, diChuyen]);
      final c = await dienAi(nguon);
      c.chonDanhMuc(diChuyen);
      c.daGuiLuu(await c.chuanBiLuu() as SanSangLuu);
      expect(nguon.aiDoanDaDanhDau, isEmpty, reason: 'người dùng đã sửa — đó là phán xét của họ, B1 được học');
    });

    test('danh mục KHÔNG từ AI (B1 / từ khoá / tên trong câu) → KHÔNG đánh dấu', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tienMat], danhMuc: [anUong, diChuyen]);
      final c = await dienAi(nguon, tuAi: false);
      c.daGuiLuu(await c.chuanBiLuu() as SanSangLuu);
      expect(nguon.aiDoanDaDanhDau, isEmpty);
    });

    test('Điền lần hai bằng luật (cùng danh mục) xoá dấu của lần AI trước', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tienMat], danhMuc: [anUong, diChuyen]);
      final c = await dienAi(nguon);
      c.dienKetQua(const KetQuaDocCau(categoryId: 'food', ghiChu: 'phở'), chonDuoc: [anUong, diChuyen]);
      c.daGuiLuu(await c.chuanBiLuu() as SanSangLuu);
      expect(nguon.aiDoanDaDanhDau, isEmpty,
          reason: 'cờ chỉ nói về lần điền GẦN NHẤT — để sót cờ cũ là đánh dấu một danh mục luật đã chọn');
    });

    test('đường SỬA: lưu là gỡ dấu của chính giao dịch ấy, không đánh dấu mới', () async {
      final nguon = NguonThemGiaoDichGia(vi: [tienMat], danhMuc: [anUong]);
      final c = taoCubit(nguon, dangSua: giaoDichCu(), danhMucDangSua: anUong);
      await c.moTrang();
      c.daGuiLuu(await c.chuanBiLuu() as SanSangLuu);
      expect(nguon.aiDoanDaGo, ['tx-cu'], reason: 'mở Sửa rồi Lưu = người dùng đã nhìn lại (người dùng chốt)');
      expect(nguon.aiDoanDaDanhDau, isEmpty);
    });
  });
}

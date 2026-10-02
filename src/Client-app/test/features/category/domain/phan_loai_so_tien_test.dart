/// Dự án C, việc đầu — gợi ý danh mục theo SỐ TIỀN (spec `2026-10-02-du-an-c-goi-y-danh-muc-theo-so-tien-design.md`).
/// Luật thuần; chỗ nối trên màn ở `transaction/presentation/add_transaction_goi_y_so_tien_test.dart`.
library;

import 'package:flowmoney/features/bill/domain/bill_note.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/category/domain/phan_loai_so_tien.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _GiaoDich = ({
  String loai,
  String? categoryId,
  String? ghiChu,
  double soTien,
  String walletId,
  DateTime ngay,
  bool daXoa
});

/// Mặc định: khoản chi, không ghi chú, ví cash, 01/09/2026 (thứ Ba).
_GiaoDich _gd(
  String? c,
  double soTien, {
  String loai = 'chi',
  String? ghiChu = '',
  String vi = 'cash',
  DateTime? ngay,
  bool daXoa = false,
}) =>
    (
      loai: loai,
      categoryId: c,
      ghiChu: ghiChu,
      soTien: soTien,
      walletId: vi,
      ngay: ngay ?? DateTime(2026, 9, 1),
      daXoa: daXoa,
    );

void main() {
  group('bacTienCua — thang 1·2·5', () {
    test('biên từng bậc', () {
      expect(bacTienCua(9999), (duoi: 0, tren: 10000));
      expect(bacTienCua(10000), (duoi: 10000, tren: 20000));
      expect(bacTienCua(19999), (duoi: 10000, tren: 20000));
      expect(bacTienCua(20000), (duoi: 20000, tren: 50000));
      expect(bacTienCua(35000), (duoi: 20000, tren: 50000));
      expect(bacTienCua(49999), (duoi: 20000, tren: 50000));
      expect(bacTienCua(50000), (duoi: 50000, tren: 100000), reason: 'biên dưới thuộc bậc trên');
      expect(bacTienCua(1000000), (duoi: 1000000, tren: 2000000));
      expect(bacTienCua(3000000), (duoi: 2000000, tren: 5000000));
    });

    test('con số lớn nhất bàn phím cho gõ (13 chữ số) vẫn có bậc', () {
      expect(bacTienCua(9999999999999), (duoi: 5000000000000, tren: 10000000000000));
    });

    test('đuôi lẻ double: 49999,99999994 là 50.000 (ngưỡng nửa đồng)', () {
      expect(bacTienCua(49999.99999994), (duoi: 50000, tren: 100000));
    });

    test('dung sai chỉ NỬA đồng: 49999,4 vẫn ở bậc dưới', () {
      expect(bacTienCua(49999.4), (duoi: 20000, tren: 50000));
      expect(bacTienCua(9999.4), (duoi: 0, tren: 10000));
    });

    test('mã bậc', () {
      expect(maBacCua(bacTienCua(35000)), '20000-50000');
      expect(maBacCua(bacTienCua(7000)), '0-10000');
    });
  });

  group('nhomThuCua', () {
    test('thứ Sáu là ngày thường, thứ Bảy và Chủ nhật là cuối tuần, thứ Hai lại là ngày thường', () {
      expect(nhomThuCua(DateTime(2026, 9, 4)), kNhomNgayThuong); // thứ Sáu
      expect(nhomThuCua(DateTime(2026, 9, 5)), kNhomCuoiTuan); // thứ Bảy
      expect(nhomThuCua(DateTime(2026, 9, 6)), kNhomCuoiTuan); // Chủ nhật
      expect(nhomThuCua(DateTime(2026, 9, 7)), kNhomNgayThuong); // thứ Hai
    });

    test('29/02 năm nhuận (thứ Ba)', () => expect(nhomThuCua(DateTime(2028, 2, 29)), kNhomNgayThuong));
  });

  group('mauSoTienTu', () {
    test('⭐ khoản KHÔNG ghi chú vẫn là mẫu — tín hiệu ở đây là số tiền', () {
      final m = mauSoTienTu([_gd('food', 30000, ghiChu: null), _gd('food', 30000, ghiChu: '')]);
      expect(m, hasLength(2));
      expect(m.first.categoryId, 'food');
      expect(m.first.chieu, 'chi');
      expect(m.first.maBac, '20000-50000');
      expect(m.first.nhomThu, kNhomNgayThuong);
      expect(m.first.walletId, 'cash');
    });

    test('bỏ khoản chuyển khoản', () => expect(mauSoTienTu([_gd('food', 30000, loai: 'transfer')]), isEmpty));
    test('bỏ khoản không danh mục', () => expect(mauSoTienTu([_gd(null, 30000)]), isEmpty));
    test('bỏ khoản đã xoá', () => expect(mauSoTienTu([_gd('food', 30000, daXoa: true)]), isEmpty));
    test('bỏ khoản số tiền 0', () => expect(mauSoTienTu([_gd('food', 0)]), isEmpty));
    test('bỏ khoản do máy gắn ghi chú (trả hoá đơn)', () {
      expect(mauSoTienTu([_gd('food', 30000, ghiChu: '${kGhiChuTraHoaDon}Tiền nhà')]), isEmpty);
    });

    test('ghi chú do người gõ không làm mất mẫu', () {
      expect(mauSoTienTu([_gd('food', 30000, ghiChu: 'cafe sáng')]), hasLength(1));
    });
  });

  // ── Phép đoán ───────────────────────────────────────────────────────────────
  // 01/09/2026 là thứ Ba; 05–06/09 và 12/09 là cuối tuần.

  /// Mười bốn mẫu chi: Ăn uống 5 khoản 20–50k · Di chuyển 5 khoản dưới 10k + 1 khoản 15k (đều ví cash, ngày thường)
  /// · Mua sắm 3 khoản lớn, ví bank, cuối tuần. Mười mẫu ĐẦU (Ăn uống + 5 khoản Di chuyển dưới 10k) đủ để lên tiếng.
  final muoiHai = mauSoTienTu([
    _gd('food', 25000, ngay: DateTime(2026, 9, 1)),
    _gd('food', 30000, ngay: DateTime(2026, 9, 2)),
    _gd('food', 35000, ngay: DateTime(2026, 9, 3)),
    _gd('food', 40000, ngay: DateTime(2026, 9, 4)),
    _gd('food', 45000, ngay: DateTime(2026, 9, 7)),
    _gd('move', 7000, ngay: DateTime(2026, 9, 1)),
    _gd('move', 7000, ngay: DateTime(2026, 9, 2)),
    _gd('move', 8000, ngay: DateTime(2026, 9, 3)),
    _gd('move', 5000, ngay: DateTime(2026, 9, 4)),
    _gd('move', 9000, ngay: DateTime(2026, 9, 7)),
    _gd('move', 15000, ngay: DateTime(2026, 9, 4)),
    _gd('shop', 150000, vi: 'bank', ngay: DateTime(2026, 9, 5)),
    _gd('shop', 180000, vi: 'bank', ngay: DateTime(2026, 9, 6)),
    _gd('shop', 300000, vi: 'bank', ngay: DateTime(2026, 9, 12)),
  ]);

  /// Ăn uống: 12 mẫu ví cash ngày thường, 5 ở bậc 20–50k. Mua sắm: 8 mẫu ví bank cuối tuần, [soShopCungBac] ở bậc ấy.
  /// → 30.000 ngày thường ví cash: hậu nghiệm Ăn uống ≈ 0,99 (thắng nhờ ví + thứ), nhưng ở BẬC ấy Mua sắm đông bằng
  /// hoặc hơn. ⚠️ Ăn uống có ĐỦ 5 khoản ở bậc — bộ đầu thiếu, và khi ấy chốt "ít nhất N khoản" trả `null` trước,
  /// nên bản sai bỏ hẳn vòng so với danh mục khác vẫn xanh (đo bằng bản sai 2026-10-02).
  List<MauSoTien> thangNhoViVaThu({int soShopCungBac = 6}) => mauSoTienTu([
        for (var i = 0; i < 5; i++) _gd('food', 30000),
        for (var i = 0; i < 7; i++) _gd('food', 60000),
        for (var i = 0; i < soShopCungBac; i++) _gd('shop', 30000, vi: 'bank', ngay: DateTime(2026, 9, 5)),
        for (var i = soShopCungBac; i < 8; i++) _gd('shop', 150000, vi: 'bank', ngay: DateTime(2026, 9, 6)),
      ]);

  /// Ăn uống 10 mẫu (7 ở 20–50k), Mua sắm 6 mẫu (2 ở 20–50k) với ví / ngày tuỳ chọn. Cùng ví cùng nhóm thứ thì bậc
  /// tiền một mình cho Ăn uống ≈ 0,75: TRÊN 0,6 của B1, DƯỚI 0,8 của nguồn này.
  List<MauSoTien> khongDuChac({String viShop = 'cash', DateTime? ngayShop}) => mauSoTienTu([
        for (var i = 0; i < 7; i++) _gd('food', 30000),
        for (var i = 0; i < 3; i++) _gd('food', 60000),
        for (var i = 0; i < 2; i++) _gd('shop', 30000, vi: viShop, ngay: ngayShop),
        for (var i = 0; i < 4; i++) _gd('shop', 150000, vi: viShop, ngay: ngayShop),
      ]);

  const moi = {'food', 'move', 'shop', 'rent', 'salary', 'bonus', 'rare'};
  final thuBa = DateTime(2026, 9, 8);

  group('BoPhanLoaiSoTien.doan', () {
    test('⭐ 35.000 ngày thường ví cash → Ăn uống, 5/5 khoản của bậc 20–50k', () {
      final d = BoPhanLoaiSoTien.hoc(muoiHai)
          .doan(chieu: 'chi', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect(d.categoryId, 'food');
      expect(d.maBac, '20000-50000');
      expect(d.soLanCung, 5);
      expect(d.soLanTong, 5);
      expect(d.xacSuat, greaterThanOrEqualTo(kNguongXacSuatSoTien));
    });

    test('7.000 → Di chuyển, 5/5 khoản của bậc dưới 10k', () {
      final d = BoPhanLoaiSoTien.hoc(muoiHai)
          .doan(chieu: 'chi', soTien: 7000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect((d.categoryId, d.maBac, d.soLanCung, d.soLanTong), ('move', '0-10000', 5, 5));
    });

    group('giá trị LẠ của một đặc trưng thì bỏ đặc trưng ấy, không phạt danh mục đông mẫu', () {
      // Ăn uống 12 mẫu (8 ở 20–50k), Mua sắm 3 mẫu (1 ở 20–50k), cùng ví cash, cùng ngày thường. Bậc tiền cho Ăn
      // uống ≈ 0,88. Tính thêm một đặc trưng mà MỌI danh mục đều đếm 0 thì phép làm trơn 1/(N(c)+K) phạt danh mục
      // đông mẫu — hậu nghiệm tụt xuống ≈ 0,69, thẻ im oan.
      final bo = BoPhanLoaiSoTien.hoc(mauSoTienTu([
        for (var i = 0; i < 8; i++) _gd('food', 30000),
        for (var i = 0; i < 4; i++) _gd('food', 60000),
        _gd('shop', 30000),
        _gd('shop', 150000),
        _gd('shop', 150000),
      ]));

      test('ví chưa chọn (null)', () {
        expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBa, hopLe: moi)?.categoryId, 'food');
      });

      test('ví mới tạo, chưa có giao dịch nào', () {
        expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'vi_moi', hopLe: moi)?.categoryId, 'food');
      });

      test('nhóm thứ chưa có mẫu nào (mọi mẫu là ngày thường, đang nhập cuối tuần)', () {
        final thuBay = DateTime(2026, 9, 12);
        expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBay, walletId: 'cash', hopLe: moi)?.categoryId, 'food');
      });
    });

    test('sổ mỏng: 9 mẫu cùng chiều → im', () {
      final bo = BoPhanLoaiSoTien.hoc(muoiHai.sublist(0, 9));
      expect(bo.doan(chieu: 'chi', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
    });

    test('đủ đúng 10 mẫu cùng chiều → lên tiếng', () {
      final bo = BoPhanLoaiSoTien.hoc(muoiHai.sublist(0, 10));
      expect(bo.doan(chieu: 'chi', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: moi)?.categoryId, 'food');
    });

    test('⭐ ngưỡng mẫu đếm theo CHIỀU: 12 mẫu chi không cho phép đoán khoản thu', () {
      final bo = BoPhanLoaiSoTien.hoc(muoiHai);
      expect(bo.doan(chieu: 'thu', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
    });

    test('số tiền 0 hoặc âm → im', () {
      final bo = BoPhanLoaiSoTien.hoc(muoiHai);
      expect(bo.doan(chieu: 'chi', soTien: 0, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
      expect(bo.doan(chieu: 'chi', soTien: -5, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
    });

    test('⭐ hậu nghiệm ≈ 0,75 — qua ngưỡng 0,6 của B1 nhưng dưới 0,8 của nguồn này → im, dù dẫn đầu bậc', () {
      // Ngưỡng 0,8 do người dùng chốt sau phép đo CSDL thật 2026-10-02: ở 0,6 thẻ đúng 1/5 lần.
      final bo = BoPhanLoaiSoTien.hoc(khongDuChac());
      expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
    });

    test('⭐ VÍ có góp phần: cùng bộ số tiền ấy, Mua sắm toàn ví bank → khoản ví cash là Ăn uống', () {
      // Bậc tiền một mình cho ≈ 0,75 (ca trên: im). Thêm ví: Ăn uống 10/10 ví cash, Mua sắm 0/6 → ≈ 0,96.
      final d = BoPhanLoaiSoTien.hoc(khongDuChac(viShop: 'bank'))
          .doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect((d.categoryId, d.soLanCung, d.soLanTong), ('food', 7, 9));
    });

    test('⭐ THỨ có góp phần: cùng bộ số tiền ấy, Mua sắm toàn cuối tuần → khoản ngày thường là Ăn uống', () {
      final d = BoPhanLoaiSoTien.hoc(khongDuChac(ngayShop: DateTime(2026, 9, 5)))
          .doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect((d.categoryId, d.soLanCung, d.soLanTong), ('food', 7, 9));
    });

    test('hoà ở đỉnh → im', () {
      final bo = BoPhanLoaiSoTien.hoc(mauSoTienTu([
        for (var i = 0; i < 5; i++) _gd('food', 30000),
        for (var i = 0; i < 5; i++) _gd('shop', 30000),
      ]));
      expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
    });

    test('⭐ thắng nhờ ví + thứ mà KHÔNG dẫn đầu bậc tiền → im (câu lý do sẽ nói ngược gợi ý)', () {
      final bo = BoPhanLoaiSoTien.hoc(thangNhoViVaThu());
      expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull,
          reason: 'Ăn uống có 5 khoản ở bậc 20–50k nhưng Mua sắm có 6');
    });

    test('NGANG số khoản ở bậc với một danh mục khác cũng chưa phải dẫn đầu → im', () {
      final bo = BoPhanLoaiSoTien.hoc(thangNhoViVaThu(soShopCungBac: 5));
      expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
    });

    test('hơn danh mục khác đúng một khoản ở bậc → lên tiếng', () {
      final d = BoPhanLoaiSoTien.hoc(thangNhoViVaThu(soShopCungBac: 4))
          .doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect((d.categoryId, d.soLanCung, d.soLanTong), ('food', 5, 9));
    });

    group('ít nhất 5 khoản ở đúng bậc tiền ấy', () {
      // Danh mục hiếm ở bậc 2–5 triệu, ví cash ngày thường; tám khoản Ăn uống ví bank cuối tuần → hậu nghiệm ≈ 1.
      List<MauSoTien> hiem(int soKhoan) => mauSoTienTu([
            for (var i = 0; i < soKhoan; i++) _gd('rare', 3000000),
            for (var i = 0; i < 8; i++) _gd('food', 30000, vi: 'bank', ngay: DateTime(2026, 9, 5)),
          ]);

      test('⭐ dẫn đầu bậc nhưng mới có 4 khoản → im (3 khoản như B1 là chưa đủ cho số tiền)', () {
        final bo = BoPhanLoaiSoTien.hoc(hiem(4));
        expect(bo.doan(chieu: 'chi', soTien: 3000000, ngay: thuBa, walletId: 'cash', hopLe: moi), isNull);
      });

      test('đủ 5 khoản → lên tiếng', () {
        final d = BoPhanLoaiSoTien.hoc(hiem(5))
            .doan(chieu: 'chi', soTien: 3000000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
        expect((d.categoryId, d.soLanCung, d.soLanTong), ('rare', 5, 5));
      });
    });

    test('⭐ cùng số tiền, đoạn Chi và đoạn Thu ra hai danh mục khác nhau', () {
      final bo = BoPhanLoaiSoTien.hoc(mauSoTienTu([
        for (var i = 0; i < 6; i++) _gd('salary', 9000000, loai: 'thu'),
        for (var i = 0; i < 4; i++) _gd('bonus', 500000, loai: 'thu'),
        for (var i = 0; i < 5; i++) _gd('rent', 9000000),
        for (var i = 0; i < 5; i++) _gd('food', 30000),
      ]));
      final thu = bo.doan(chieu: 'thu', soTien: 9000000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect((thu.categoryId, thu.soLanCung, thu.soLanTong), ('salary', 6, 6));
      final chi = bo.doan(chieu: 'chi', soTien: 9000000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect((chi.categoryId, chi.soLanCung, chi.soLanTong), ('rent', 5, 5),
          reason: 'đếm "5/5 lần" chỉ trong các khoản CHI — 6 khoản Lương cùng bậc không lẫn vào');
    });

    test('⭐ hopLe chỉ LỌC ứng viên, không dồn xác suất cho danh mục còn sống', () {
      // Mua sắm dẫn đầu bậc (6/11) nhưng hậu nghiệm thật chỉ ≈ 0,01 cho khoản ngày thường ví cash.
      final bo = BoPhanLoaiSoTien.hoc(thangNhoViVaThu());
      expect(bo.doan(chieu: 'chi', soTien: 30000, ngay: thuBa, walletId: 'cash', hopLe: {'shop'}), isNull,
          reason: 'tính hậu nghiệm trên phần còn lại là đẩy Mua sắm lên 100 %');
    });

    test('không ứng viên hợp lệ nào → im', () {
      final bo = BoPhanLoaiSoTien.hoc(muoiHai);
      expect(bo.doan(chieu: 'chi', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: const {}), isNull);
    });

    test('cặp (mã bậc, danh mục) đang tắt → im; tắt ở bậc khác không ảnh hưởng', () {
      final bo = BoPhanLoaiSoTien.hoc(muoiHai);
      expect(
        bo.doan(
            chieu: 'chi', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: moi, tatCap: {('20000-50000', 'food')}),
        isNull,
      );
      expect(
        bo.doan(chieu: 'chi', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: moi, tatCap: {('0-10000', 'food')}),
        isNotNull,
      );
    });
  });

  group('cauLyDoSoTien', () {
    test('bậc thường', () {
      final d = BoPhanLoaiSoTien.hoc(muoiHai)
          .doan(chieu: 'chi', soTien: 35000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect(cauLyDoSoTien(d, tenDanhMuc: 'Ăn uống'),
          'Khoản từ 20.000 đ đến 50.000 đ bạn thường ghi cho Ăn uống (5/5 lần).');
    });

    test('bậc thấp nhất không in "từ 0 đ"', () {
      final d = BoPhanLoaiSoTien.hoc(muoiHai)
          .doan(chieu: 'chi', soTien: 7000, ngay: thuBa, walletId: 'cash', hopLe: moi)!;
      expect(cauLyDoSoTien(d, tenDanhMuc: 'Di chuyển'), 'Khoản dưới 10.000 đ bạn thường ghi cho Di chuyển (5/5 lần).');
    });
  });

  group('tatCapSoTienTu', () {
    PhanHoiGoiY ph(int ngay, {String nguon = kNguonGoiYSoTien, String ketQua = kKetQuaGoiYBoQua}) => PhanHoiGoiY(
          nguon: nguon,
          amTietChinh: '20000-50000',
          goiYCategoryId: 'food',
          ketQua: ketQua,
          createdAt: DateTime(2026, 9, ngay),
        );
    MauSoTien m(double soTien, int ngay, {String c = 'food'}) =>
        mauSoTienTu([_gd(c, soTien, ngay: DateTime(2026, 9, ngay))]).single;

    test('một lần bỏ qua chưa tắt', () => expect(tatCapSoTienTu([ph(10)], const []), isEmpty));

    test('⭐ hai lần bỏ qua cùng (mã bậc, danh mục) → tắt', () {
      expect(tatCapSoTienTu([ph(10), ph(11)], const []), {('20000-50000', 'food')});
    });

    test('⭐ ba mẫu MỚI cùng bậc cùng danh mục sau lần bỏ qua cuối → mở lại', () {
      expect(tatCapSoTienTu([ph(10), ph(11)], [m(30000, 12), m(35000, 13), m(40000, 14)]), isEmpty);
    });

    test('hai mẫu mới chưa đủ để mở lại', () {
      expect(tatCapSoTienTu([ph(10), ph(11)], [m(30000, 12), m(35000, 13)]), {('20000-50000', 'food')});
    });

    test('mẫu KHÁC BẬC không mở lại', () {
      expect(tatCapSoTienTu([ph(10), ph(11)], [m(60000, 12), m(60000, 13), m(60000, 14)]), {('20000-50000', 'food')});
    });

    test('mẫu của danh mục KHÁC không mở lại', () {
      expect(
        tatCapSoTienTu([ph(10), ph(11)], [for (final d in [12, 13, 14]) m(30000, d, c: 'shop')]),
        {('20000-50000', 'food')},
      );
    });

    test('mẫu có TRƯỚC lần bỏ qua cuối không mở lại', () {
      expect(tatCapSoTienTu([ph(10), ph(11)], [m(30000, 7), m(30000, 8), m(30000, 9)]), {('20000-50000', 'food')});
    });

    test('⭐ phản hồi của nguồn KHÁC (B1) không tắt nguồn số tiền', () {
      expect(tatCapSoTienTu([ph(10, nguon: kNguonGoiYHoc), ph(11, nguon: kNguonGoiYHoc)], const []), isEmpty);
    });

    test('"khac" và "chon" không tính là bỏ qua', () {
      expect(tatCapSoTienTu([ph(10, ketQua: kKetQuaGoiYKhac), ph(11, ketQua: kKetQuaGoiYChon)], const []), isEmpty);
    });

    test('hai lần bỏ qua của nguồn số tiền không lọt vào tập tắt của B1', () {
      expect(tatCapTu([ph(10), ph(11)], const []), isEmpty);
    });
  });

  test('ngưỡng của nguồn số tiền CHẶT hơn B1 — số tiền là tín hiệu yếu hơn chữ', () {
    expect(kNguongXacSuatSoTien, greaterThan(kNguongXacSuat));
    expect(kToiThieuKhoanCungBac, greaterThan(kToiThieuMauDanhMuc));
  });

  test('hằng nguồn không trùng nguồn nào của B1', () {
    expect({kNguonGoiYSoTien, kNguonGoiYHoc, kNguonGoiYTuKhoa, kNguonDeXuatTuKhoa}, hasLength(4));
  });
}

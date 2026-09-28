/// Tool `tim_giao_dich` — phần CHÉP của ai_edge: hàng theo tiêu đề, trạng thái
/// nêu chiều · danh mục · ví, số tiền + NGÀY; tổng hợp theo chiều đã hỏi;
/// khoảng tiền đã hiểu dội lại; tên liên quan cho bộ kiểm.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_giao_dich.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/transaction/domain/khoang_tien.dart';
import 'package:flowmoney/features/transaction/domain/tim_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 10);
  final kq = KetQuaTimGiaoDich(
    dong: [
      DongTimThay(
        tieuDe: 'Cho vay', tenDanhMuc: 'test1', tenVi: 'Tiền mặt', tenViDich: null,
        soTien: 800000, chieu: ChieuTim.chi, ngay: DateTime(2026, 9, 19),
      ),
      DongTimThay(
        tieuDe: 'Chuyển khoản', tenDanhMuc: null, tenVi: 'Tiền mặt', tenViDich: 'Tiết kiệm',
        soTien: 900000, chieu: ChieuTim.chuyen, ngay: DateTime(2026, 9, 8),
      ),
      DongTimThay(
        tieuDe: 'Phí cũ', tenDanhMuc: null, tenVi: 'Tiền mặt', tenViDich: null,
        soTien: 20000, chieu: ChieuTim.chi, ngay: DateTime(2025, 12, 28),
      ),
    ],
    soKhop: 7,
    tongChi: 2031000,
    tongThu: 0,
    tongChuyen: 900000,
    tenViKhop: 'Tiền mặt',
  );
  Map<String, String> so(HangSoLieu h) => {for (final s in h.soLieu) s.nhan: s.chuoi};

  test('⭐ hàng: tiêu đề, trạng thái chiều · danh mục · ví, Số tiền + Ngày (mang tên hàng)', () {
    final r = hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    expect(r.hang[0].ten, 'Cho vay');
    expect(r.hang[0].trangThai, 'khoản chi · test1 · Tiền mặt');
    expect(so(r.hang[0]), {'Số tiền': '800.000 đ', 'Ngày': '19/09'});
    expect(r.hang[0].soLieu.every((s) => s.ten == 'Cho vay'), isTrue);
    expect(r.hang[1].trangThai, 'chuyển ví · Tiền mặt → Tiết kiệm');
    expect(r.hang[2].trangThai, 'khoản chi · Chưa phân loại · Tiền mặt');
    expect(so(r.hang[2])['Ngày'], '28/12/2025');
    expect(r.hang.every((h) => !h.canhBao), isTrue);
  });

  test('⭐ hàng khai nhãn XUNG ĐỘT theo chiều: chi ↔ Thu, thu ↔ Chi, chuyển không (bẫy 4.42)', () {
    final coThu = KetQuaTimGiaoDich(
      dong: [
        ...kq.dong,
        DongTimThay(
          tieuDe: 'Lương', tenDanhMuc: 'Lương', tenVi: 'Tiền mặt', tenViDich: null,
          soTien: 9000000, chieu: ChieuTim.thu, ngay: DateTime(2026, 9, 4),
        ),
      ],
      soKhop: 8, tongChi: 2031000, tongThu: 9000000, tongChuyen: 900000, tenViKhop: 'Tiền mặt',
    );
    final r = hangGiaoDich(coThu, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    // Chỉ Số tiền mang xung đột; Ngày của hàng thì không.
    List<String> xd(int i) => r.hang[i].soLieu.firstWhere((s) => s.nhan == 'Số tiền').nhanXungDot;
    expect(xd(0), ['Thu'], reason: 'Cho vay là khoản CHI — câu "khoản thu: Cho vay 800.000" phải bị chặn');
    // Nhãn thay thế theo chiều đi kèm (lần đo 7): câu nêu đúng chiều ("khoản chi") thì
    // không bị coi là gán ngược dù nhãn chính "Số tiền" không có trong câu.
    List<String> nk(int i) => r.hang[i].soLieu.firstWhere((s) => s.nhan == 'Số tiền').nhanKhac;
    expect(nk(0), ['Chi']);
    expect(nk(1), isEmpty);
    expect(nk(3), ['Thu']);
    expect(xd(1), isEmpty, reason: 'khoản chuyển: cố ý không khai xung đột');
    expect(xd(3), ['Chi'], reason: 'Lương là khoản THU');
    expect(r.hang[0].soLieu.firstWhere((s) => s.nhan == 'Ngày').nhanXungDot, isEmpty);
    for (final s in r.tongHop) {
      expect(s.nhanXungDot, isEmpty);
    }
  });

  test('tổng hợp theo CHIỀU đã hỏi; Số giao dịch là mọi khoản khớp', () {
    Map<String, String> tong(TieuChiTim t) => {
          for (final s in hangGiaoDich(kq, tieuChi: t, chuKy: 'tháng này', now: now).tongHop)
            s.nhan: s.chuoi,
        };
    expect(tong(const TieuChiTim(chieu: ChieuTim.chi)), {'Số giao dịch': '7', 'Tổng chi': '2.031.000 đ'});
    expect(tong(const TieuChiTim(chieu: ChieuTim.chuyen)), {'Số giao dịch': '7', 'Tổng chuyển': '900.000 đ'});
    expect(tong(const TieuChiTim()).keys, ['Số giao dịch', 'Tổng chi', 'Tổng thu', 'Tổng chuyển']);
  });

  test('⭐ khoảng tiền đã hiểu DỘI LẠI ở soLieuBoLoc, KHÔNG ở tongHop; json vẫn có Từ (bước 2c)', () {
    final r = hangGiaoDich(kq,
        tieuChi: const TieuChiTim(chieu: ChieuTim.chi, khoangTien: KhoangTien(tu: 500000)),
        chuKy: 'tháng này', now: now);
    expect({for (final s in r.soLieuBoLoc) s.nhan: s.chuoi}, {'Từ': '500.000 đ'});
    expect(r.tongHop.map((s) => s.nhan).toList(), ['Số giao dịch', 'Tổng chi'],
        reason: 'còn ở tongHop thì mẫu câu in "Từ: 500.000 đ" thành một vế dữ liệu');
    expect(r.json['Từ'], '500.000 đ', reason: 'JSON gửi mô hình không đổi');
    expect(r.json.containsKey('Đến'), isFalse);
  });

  test('⭐ nhãn đếm là "Số giao dịch" — chữ mô hình "Có 6 giao dịch." qua kiemNhan (bẫy 4.47)', () {
    final goi = GoiSoTraCuu()
      ..them('tim_giao_dich', hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now));
    expect(goi.tongHop.first.nhan, 'Số giao dịch');
    expect(kiemNhan('Trong tháng này bạn có 7 giao dịch.', [goi]), isTrue,
        reason: 'cổng D lần 4 C5/C17: nhãn cũ "Số khoản" đòi chữ "khoản" mà mô hình nói "giao dịch" — '
            'hai câu đúng rơi mẫu câu');
    expect(goi.tongHop.first.nhanKhac, ['Số khoản'],
        reason: 'cổng D lần 5: nhãn "Số giao dịch" một mình lại chặn "Có 2 khoản thu…" (C8)');
    expect(kiemNhan('Trong tháng này bạn có 7 khoản.', [goi]), isTrue,
        reason: 'mô hình dùng "khoản" và "giao dịch" thay nhau — cả hai phải qua');
  });

  test('⭐ rongTheoBoLoc: đúng khi soKhop == 0 (bẫy 4.44), sai khi có khoản, không đặt ở lời từ chối', () {
    const rong = KetQuaTimGiaoDich(dong: [], soKhop: 0, tongChi: 0, tongThu: 0, tongChuyen: 0);
    expect(hangGiaoDich(rong, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now).rongTheoBoLoc, isTrue,
        reason: 'C9 cổng D lần 2: tu_khoa "chi" → 0 khoản → mẫu câu "Số giao dịch: 0" trong khi có 2');
    expect(hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now).rongTheoBoLoc, isFalse);
    const loi = KetQuaTimGiaoDich.loi(LoiKhopTen(
        truong: TruongTen.vi, hoi: 'vi gia', nhieu: false, tenGoiY: ['Tiền mặt']));
    expect(hangGiaoDich(loi, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now).rongTheoBoLoc, isFalse);
  });

  test('⭐ boLoc: bảy điều kiện đúng thứ tự; tat_ca và so_tien không in; tên danh mục / ví là TÊN THẬT đã khớp', () {
    final kqKhop = KetQuaTimGiaoDich(
      dong: kq.dong, soKhop: 7, tongChi: 2031000, tongThu: 0, tongChuyen: 900000,
      tenDanhMucKhop: 'Ăn uống', tenViKhop: 'Tiết kiệm',
    );
    final r = hangGiaoDich(kqKhop,
        tieuChi: const TieuChiTim(
          chieu: ChieuTim.chi,
          khoangTien: KhoangTien(tu: 200000, den: 1000000),
          tenDanhMuc: 'an_uong',
          tenVi: 'tiet_kiem',
          tuKhoa: 'hoa don',
          sapXep: SapXepTim.moiNhat,
        ),
        chuKy: 'tháng này', now: now);
    expect(r.boLoc, [
      'khoản chi',
      'danh mục "Ăn uống"',
      'ví "Tiết kiệm"',
      'ghi chú chứa "hoa don"',
      'từ 200.000 đ',
      'đến 1.000.000 đ',
      'mới nhất trước',
    ], reason: 'tên là tên THẬT đã khớp (không phải "an_uong" mô hình gõ); thứ tự cố định để hai lượt cùng bộ lọc cho cùng tiền tố');
    // `kq` của tệp mang tenViKhop 'Tiền mặt' nên boLoc luôn có `ví "Tiền mặt"`;
    // muốn thấy "không nêu gì" thì cần kết quả KHÔNG khớp tên nào.
    final khongTen = KetQuaTimGiaoDich(dong: kq.dong, soKhop: 7, tongChi: 2031000, tongThu: 0, tongChuyen: 900000);
    expect(hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now).boLoc, ['ví "Tiền mặt"'],
        reason: 'tat_ca và so_tien là mặc định — không nêu; tên ví đã khớp thì nêu');
    expect(hangGiaoDich(khongTen, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now).boLoc, isEmpty);
    expect(hangGiaoDich(khongTen, tieuChi: const TieuChiTim(chieu: ChieuTim.thu), chuKy: 'x', now: now).boLoc, ['khoản thu']);
    expect(hangGiaoDich(khongTen, tieuChi: const TieuChiTim(chieu: ChieuTim.chuyen), chuKy: 'x', now: now).boLoc, ['chuyển ví']);
  });

  test('chuỗi tiền trong boLoc BẰNG chuoi của soLieuBoLoc — thẻ và kiemSo khớp được', () {
    final r = hangGiaoDich(kq,
        tieuChi: const TieuChiTim(khoangTien: KhoangTien(tu: 500000, den: 1234567)),
        chuKy: 'tháng này', now: now);
    expect(r.boLoc, ['ví "Tiền mặt"', 'từ ${r.soLieuBoLoc[0].chuoi}', 'đến ${r.soLieuBoLoc[1].chuoi}']);
    expect(r.soLieuBoLoc[1].chuoi, '1.234.567 đ');
  });

  test('⭐ tu_khoa vào tenLienQuan (chữ số trong "T9" không bị đọc là số); rỗng thì không thêm gì', () {
    final co = hangGiaoDich(kq, tieuChi: const TieuChiTim(tuKhoa: 'T9'), chuKy: 'tháng này', now: now);
    expect(co.tenLienQuan, contains('T9'));
    final khong = hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    expect(khong.tenLienQuan.toSet(), {'test1', 'Tiền mặt', 'Tiết kiệm'});
    expect(khong.tenLienQuan, isNot(contains('')));
  });

  test('chữ kèm: kỳ + kiểu xếp, KHÔNG có chữ số', () {
    final r = hangGiaoDich(kq,
        tieuChi: const TieuChiTim(sapXep: SapXepTim.moiNhat), chuKy: 'tuần trước', now: now);
    expect(r.chuThem, {'ky': 'tuần trước', 'sap_xep': 'mới nhất trước'});
    expect(r.chuThem.values.any((v) => RegExp(r'\d').hasMatch(v)), isFalse);
  });

  test('⭐ tenLienQuan: tên danh mục / ví trong trạng thái + tên đã khớp', () {
    final r = hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    expect(r.tenLienQuan.toSet(), {'test1', 'Tiền mặt', 'Tiết kiệm'});
  });

  test('lỗi khớp tên → lời từ chối của tool, tên gợi ý vào tenLienQuan', () {
    const loi = KetQuaTimGiaoDich.loi(LoiKhopTen(
        truong: TruongTen.vi, hoi: 'vi gia', nhieu: false, tenGoiY: ['Tiền mặt', 'test']));
    final r = hangGiaoDich(loi, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    expect(r.loi, 'vi "vi gia" không khớp tên nào. Chỉ có: Tiền mặt, test.');
    expect(r.choNguoiDung, 'không có ví nào tên "vi gia"');
    expect(r.thamSoGo, ['vi']);
    expect(r.tenLienQuan, ['Tiền mặt', 'test', 'vi gia']);
  });

  test('⭐ mẫu câu của gói tra cứu (có NGÀY) tự qua kiemSo và kiemNhan', () {
    final goi = GoiSoTraCuu()
      ..them('tim_giao_dich',
          hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now));
    final cau = goi.mauCau().cau;
    expect(kiemSo(cau, goi), isTrue, reason: cau);
    expect(kiemNhan(cau, [goi]), isTrue, reason: cau);
  });
  test('⭐ chon: hàng (đã cắt còn một) mang trạng thái "khoản lớn nhất / nhỏ nhất" và boLoc nêu phép chọn', () {
    final now = DateTime(2026, 9, 23);
    final kq = KetQuaTimGiaoDich(
      dong: [DongTimThay(tieuDe: 'Cho vay', tenDanhMuc: 'Cho vay', tenVi: 'Tiền mặt', tenViDich: null,
          soTien: 800000, chieu: ChieuTim.chi, ngay: DateTime(2026, 9, 19))],
      soKhop: 9, tongChi: 2141000, tongThu: 0, tongChuyen: 0,
    );
    final lon = hangGiaoDich(kq, tieuChi: const TieuChiTim(chieu: ChieuTim.chi), chuKy: 'tháng này', now: now, chon: 'nhieu_nhat');
    expect(lon.hang.single.trangThai, 'khoản lớn nhất · khoản chi · Cho vay · Tiền mặt');
    expect(lon.boLoc, contains('khoản lớn nhất'));
    expect(lon.json['Số giao dịch'], '9', reason: 'đếm trên trọn tập, không trên hàng hiện');
    final nho = hangGiaoDich(kq, tieuChi: const TieuChiTim(chieu: ChieuTim.chi), chuKy: 'tháng này', now: now, chon: 'it_nhat');
    expect(nho.hang.single.trangThai, startsWith('khoản nhỏ nhất'));
  });

  test('boLocTimGiaoDich / soLieuBoLocTimGiaoDich là MỘT nguồn cho cả hàng lẻ và hàng nhóm', () {
    const tc = TieuChiTim(chieu: ChieuTim.chi, tuKhoa: 'hoa don');
    const kq = KetQuaTimGiaoDich(dong: [], soKhop: 0, tongChi: 0, tongThu: 0, tongChuyen: 0, tenDanhMucKhop: 'Giải trí');
    expect(boLocTimGiaoDich(kq, tc), ['khoản chi', 'danh mục "Giải trí"', 'ghi chú chứa "hoa don"']);
    expect(soLieuBoLocTimGiaoDich(tc), isEmpty);
  });

  group('themSoSanh + kỳ tự do — câu tự nhiên qua bốn lớp chắn', () {
    final goc = hangGiaoDich(kq, tieuChi: const TieuChiTim(chieu: ChieuTim.chi), chuKy: 'tháng này', now: now);
    final coSoSanh = themSoSanh(
      goc,
      soSanh: const SoSanhKy(chuKy: 'tháng trước', chi: 1531000, thu: 0),
      chieu: ChieuTim.chi,
      tongChi: 2031000,
      tongThu: 0,
    );

    test('⭐ câu "chi 2.031.000 đ, nhiều hơn tháng trước 500.000 đ" qua kiemSo + kiemNhan', () {
      final g = GoiSoTraCuu()..them('truy_van_giao_dich', coSoSanh);
      const cau = 'Tháng này bạn chi 2.031.000 đ, nhiều hơn tháng trước 500.000 đ.';
      expect(kiemSo(cau, g), isTrue);
      expect(kiemNhan(cau, [g]), isTrue);
      expect(kiemSo('Tháng trước bạn chi 1.531.000 đ.', g), isTrue);
      expect(kiemNhan('Tháng trước bạn chi 1.531.000 đ.', [g]), isTrue);
    });

    test('⚠️ số bịa vẫn bị chặn: chênh lệch 600.000 không có trong gói', () {
      final g = GoiSoTraCuu()..them('truy_van_giao_dich', coSoSanh);
      expect(kiemSo('Bạn chi nhiều hơn tháng trước 600.000 đ.', g), isFalse);
    });

    test('mẫu câu của gói tự qua kiemSo + kiemNhan, và nêu "so với tháng trước"', () {
      final g = GoiSoTraCuu()..them('truy_van_giao_dich', coSoSanh);
      final cau = g.mauCau().cau;
      expect(cau, contains('so với tháng trước'));
      expect(cau, contains('Tổng chi tháng trước: 1.531.000 đ'));
      expect(kiemSo(cau, g), isTrue, reason: cau);
      expect(kiemNhan(cau, [g]), isTrue, reason: cau);
    });

    test('lượt bị từ chối / rỗng theo bộ lọc: themSoSanh trả NGUYÊN kết quả', () {
      final rong = hangGiaoDich(
        const KetQuaTimGiaoDich(dong: [], soKhop: 0, tongChi: 0, tongThu: 0, tongChuyen: 0),
        tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now,
      );
      final r = themSoSanh(rong,
          soSanh: const SoSanhKy(chuKy: 'tháng trước', chi: 1, thu: 1),
          chieu: ChieuTim.tatCa, tongChi: 0, tongThu: 0);
      expect(identical(r, rong), isTrue);
    });

    test('⭐ kỳ tự do: mẫu câu mở đầu bằng chữ kỳ có số, KHÔNG in "khoảng đã chọn", tự qua bộ kiểm', () {
      final r = ganKyTuyChon(
        hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'khoảng đã chọn', now: now),
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 9, 1),
        chu: 'tháng 8/2026',
        ten: const ['tháng 8', 'tháng 8/2026'],
        now: now,
      );
      final g = GoiSoTraCuu()..them('truy_van_giao_dich', r);
      final cau = g.mauCau().cau;
      expect(cau, startsWith('Tháng 8/2026'));
      expect(cau, isNot(contains('hoảng đã chọn')));
      expect(kiemSo(cau, g), isTrue, reason: cau);
      expect(kiemNhan(cau, [g]), isTrue, reason: cau);
      // Câu của mô hình nêu "tháng 8" hay hai mốc ngày đều qua.
      expect(kiemSo('Tháng 8 bạn chi tổng cộng 2.031.000 đ.', g), isTrue);
      expect(kiemNhan('Từ 01/08 đến 31/08 tổng chi là 2.031.000 đ.', [g]), isTrue);
      expect(kiemSo('Tháng 6 bạn chi tổng cộng 2.031.000 đ.', g), isFalse,
          reason: '"tháng 6" không phải tên kỳ của gói — chữ số 6 là số bịa');
    });
  });
}

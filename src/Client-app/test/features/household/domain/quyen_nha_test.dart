import 'package:flowmoney/features/household/domain/quyen_nha.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bảng vai × trạng thái × việc — `docs/Family/01_NEN_MONG.md` mục 3 (thắng đơn 50 khi lệch; server thi hành lại, client chỉ
/// khoá nút).
void main() {
  bool lam(ViecNha v, VaiNha? vai, TrangThaiNha? tt) => duocLamViecNha(v, vai: vai, trangThai: tt);

  test('nhà hoạt động: chủ làm mọi việc quản lý trừ rời; thành viên ghi + rời; chỉ xem chỉ rời', () {
    const hd = TrangThaiNha.hoatDong;
    for (final v in [
      ViecNha.taoMa,
      ViecNha.huyMa,
      ViecNha.doiVai,
      ViecNha.moiRa,
      ViecNha.chuyenChu,
      ViecNha.giaiTan,
      ViecNha.ghiKhoan
    ]) {
      expect(lam(v, VaiNha.chu, hd), isTrue, reason: v.name);
    }
    expect(lam(ViecNha.roiNha, VaiNha.chu, hd), isFalse, reason: 'chủ phải chuyển chủ hoặc giải tán trước');
    expect(lam(ViecNha.ghiKhoan, VaiNha.thanhVien, hd), isTrue);
    expect(lam(ViecNha.roiNha, VaiNha.thanhVien, hd), isTrue);
    expect(lam(ViecNha.taoMa, VaiNha.thanhVien, hd), isFalse);
    expect(lam(ViecNha.ghiKhoan, VaiNha.chiXem, hd), isFalse);
    expect(lam(ViecNha.roiNha, VaiNha.chiXem, hd), isTrue);
  });

  test('nhà hoạt động: Thành viên / Chỉ xem KHÔNG làm được việc quản lý nào (chỉ Chủ)', () {
    const hd = TrangThaiNha.hoatDong;
    for (final vai in [VaiNha.thanhVien, VaiNha.chiXem]) {
      for (final v in [ViecNha.huyMa, ViecNha.doiVai, ViecNha.moiRa, ViecNha.chuyenChu, ViecNha.giaiTan]) {
        expect(lam(v, vai, hd), isFalse, reason: '${vai.name} × ${v.name}');
      }
    }
    expect(lam(ViecNha.taoMa, VaiNha.chiXem, hd), isFalse, reason: 'tạo mã chỉ Chủ');
  });

  test('nhà chỉ xem (chủ hết Premium): không ai ghi, không tạo mã; quản lý / rời vẫn chạy', () {
    const cx = TrangThaiNha.chiXem;
    expect(lam(ViecNha.ghiKhoan, VaiNha.chu, cx), isFalse);
    expect(lam(ViecNha.ghiKhoan, VaiNha.thanhVien, cx), isFalse);
    expect(lam(ViecNha.taoMa, VaiNha.chu, cx), isFalse);
    expect(lam(ViecNha.doiVai, VaiNha.chu, cx), isTrue);
    expect(lam(ViecNha.moiRa, VaiNha.chu, cx), isTrue);
    expect(lam(ViecNha.chuyenChu, VaiNha.chu, cx), isTrue, reason: 'chuyển cho thành viên có Premium là lối thoát');
    expect(lam(ViecNha.roiNha, VaiNha.thanhVien, cx), isTrue);
  });

  test('ví chung và chuyển: chỉ Chủ nhà', () {
    for (final v in [ViecNha.quanLyViChung, ViecNha.chuyenGiuaViChung]) {
      expect(lam(v, VaiNha.chu, TrangThaiNha.hoatDong), isTrue);
      expect(lam(v, VaiNha.thanhVien, TrangThaiNha.hoatDong), isFalse,
          reason: 'Thành viên làm là HOUSEHOLD_ROLE_FORBIDDEN vĩnh viễn');
      expect(lam(v, VaiNha.chiXem, TrangThaiNha.hoatDong), isFalse);
    }
  });

  test('ghi khoản và danh mục: Chủ nhà, Thành viên', () {
    for (final v in [ViecNha.ghiKhoan, ViecNha.suaDanhMuc]) {
      expect(lam(v, VaiNha.chu, TrangThaiNha.hoatDong), isTrue);
      expect(lam(v, VaiNha.thanhVien, TrangThaiNha.hoatDong), isTrue);
      expect(lam(v, VaiNha.chiXem, TrangThaiNha.hoatDong), isFalse);
    }
  });

  test('nhà chỉ xem: không việc ghi nào', () {
    for (final v in [ViecNha.quanLyViChung, ViecNha.ghiKhoan, ViecNha.chuyenGiuaViChung, ViecNha.suaDanhMuc]) {
      for (final vai in VaiNha.values) {
        expect(lam(v, vai, TrangThaiNha.chiXem), isFalse, reason: '${vai.name} × ${v.name} khi nhà chỉ xem');
      }
    }
  });

  group('sửa / xoá khoản', () {
    bool sua(VaiNha? vai,
            {required bool cuaToi, required bool coMaCap, bool chuyen = false, TrangThaiNha? t = TrangThaiNha.hoatDong}) =>
        duocSuaKhoanNha(vai: vai, trangThai: t, cuaToi: cuaToi, coMaCap: coMaCap, laChuyen: chuyen);
    bool xoa(VaiNha? vai, {required bool cuaToi, bool chuyen = false, TrangThaiNha? t = TrangThaiNha.hoatDong}) =>
        duocXoaKhoanNha(vai: vai, trangThai: t, cuaToi: cuaToi, laChuyen: chuyen);

    test('khoản chuyển: chỉ Chủ nhà sửa, xoá (server chỉ cho Owner)', () {
      expect(sua(VaiNha.thanhVien, cuaToi: true, coMaCap: false, chuyen: true), isFalse,
          reason: 'chủ cũ bị hạ xuống Thành viên: khoản chuyển từng ghi vẫn bị server từ chối vĩnh viễn');
      expect(xoa(VaiNha.thanhVien, cuaToi: true, chuyen: true), isFalse, reason: 'Thành viên không xoá khoản chuyển của mình');
      expect(sua(VaiNha.chu, cuaToi: false, coMaCap: false, chuyen: true), isTrue, reason: 'Chủ sửa chuyển của người khác');
      expect(xoa(VaiNha.chu, cuaToi: false, chuyen: true), isTrue, reason: 'Chủ xoá chuyển của người khác');
      expect(xoa(VaiNha.chu, cuaToi: true, chuyen: true, t: TrangThaiNha.chiXem), isFalse,
          reason: 'khoản chuyển vẫn qua chốt trạng thái nhà');
    });
    test('mã cặp: Thành viên sửa nửa của mình, không sửa của người khác', () {
      expect(sua(VaiNha.thanhVien, cuaToi: true, coMaCap: true), isTrue, reason: 'bản sai bảng làm ca này lọt');
      expect(sua(VaiNha.thanhVien, cuaToi: false, coMaCap: true), isFalse, reason: 'nửa riêng của người khác');
    });

    test('khoản thường', () {
      expect(sua(VaiNha.chu, cuaToi: false, coMaCap: false), isTrue);
      expect(sua(VaiNha.thanhVien, cuaToi: true, coMaCap: false), isTrue);
      expect(sua(VaiNha.thanhVien, cuaToi: false, coMaCap: false), isFalse);
      expect(xoa(VaiNha.thanhVien, cuaToi: true), isTrue);
      expect(xoa(VaiNha.thanhVien, cuaToi: false), isFalse);
    });
    test('khoản có mã cặp: Chủ nhà không sửa được của người khác, xoá thì được', () {
      expect(sua(VaiNha.chu, cuaToi: false, coMaCap: true), isFalse,
          reason: 'nửa riêng chỉ ở máy người ghi; sửa hộ là lệch hai nửa');
      expect(sua(VaiNha.chu, cuaToi: true, coMaCap: true), isTrue);
      expect(xoa(VaiNha.chu, cuaToi: false), isTrue);
    });
    test('Chỉ xem và nhà chỉ xem không sửa không xoá', () {
      expect(xoa(VaiNha.chiXem, cuaToi: true), isFalse);
      expect(sua(VaiNha.chiXem, cuaToi: true, coMaCap: false), isFalse);
      expect(sua(VaiNha.thanhVien, cuaToi: true, coMaCap: false, t: TrangThaiNha.chiXem), isFalse);
      expect(xoa(VaiNha.chu, cuaToi: true, t: TrangThaiNha.chiXem), isFalse);
    });
    test('chưa có nhà hoặc nhà giải tán: không sửa không xoá', () {
      expect(sua(null, cuaToi: true, coMaCap: false, t: null), isFalse);
      expect(xoa(null, cuaToi: true, t: null), isFalse);
      expect(sua(VaiNha.chu, cuaToi: true, coMaCap: false, t: TrangThaiNha.daGiaiTan), isFalse);
      expect(xoa(VaiNha.chu, cuaToi: true, t: TrangThaiNha.daGiaiTan), isFalse);
    });
  });

  test('MỘT nửa null (vai null hoặc trạng thái null): từ chối mặc định — cửa của nút 1B không mở khi chưa biết đủ', () {
    for (final v in ViecNha.values) {
      expect(lam(v, null, TrangThaiNha.hoatDong), isFalse, reason: '${v.name}: chưa biết vai');
      expect(lam(v, VaiNha.chu, null), isFalse, reason: '${v.name}: chưa biết trạng thái nhà');
    }
    expect(duocSuaKhoanNha(vai: null, trangThai: TrangThaiNha.hoatDong, cuaToi: true, coMaCap: false, laChuyen: false), isFalse);
    expect(duocSuaKhoanNha(vai: VaiNha.chu, trangThai: null, cuaToi: true, coMaCap: false, laChuyen: false), isFalse);
    expect(duocXoaKhoanNha(vai: null, trangThai: TrangThaiNha.hoatDong, cuaToi: true, laChuyen: false), isFalse);
    expect(duocXoaKhoanNha(vai: VaiNha.chu, trangThai: null, cuaToi: true, laChuyen: false), isFalse);
  });

  test('nhà giải tán / chưa có nhà: không làm được gì', () {
    for (final v in ViecNha.values) {
      expect(lam(v, VaiNha.chu, TrangThaiNha.daGiaiTan), isFalse, reason: v.name);
      expect(lam(v, null, null), isFalse, reason: v.name);
    }
  });

  test('conTaoDuocViChung: null là chưa biết thì không khoá', () {
    expect(conTaoDuocViChung(10, null), isTrue, reason: 'bịa trần là khoá nhầm');
    expect(conTaoDuocViChung(9, 10), isTrue);
    expect(conTaoDuocViChung(10, 10), isFalse, reason: 'bằng trần là hết chỗ');
    expect(conTaoDuocViChung(11, 10), isFalse, reason: 'vượt trần (hạ trần sau khi đã tạo) cũng khoá');
  });
}

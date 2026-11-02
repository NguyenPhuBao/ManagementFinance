import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';

/// Hình dạng trạng thái nhà — model theo `docs/Family/01` mục 4 (LỒNG), một hình dạng duy nhất sau khi backend đóng 57.1
/// (PR #172, đo lại trên `8e3b4e48` 2026-10-31). Một bộ đọc, không bao giờ ném.
void main() {
  final luc = DateTime.utc(2026, 10, 24, 8);

  group('hình dạng LỒNG (docs/Family/01 mục 4)', () {
    test('đọc đủ trường, kể cả formerMembers và maxSharedWallets', () {
      final t = nhaCuaToiTuJson(nhaJson(), nhanLuc: luc);
      expect(t.coNha, isTrue);
      expect(t.nha!.id, 12);
      expect(t.nha!.ten, 'Nhà An – Bình');
      expect(t.nha!.trangThai, TrangThaiNha.hoatDong);
      expect(t.nha!.toiDaThanhVien, 6);
      expect(t.nha!.idChuNha, 18);
      expect(t.nha!.toiDaViChung, 10);
      expect(t.vai, VaiNha.chu);
      expect(t.thanhVien.map((m) => (m.idaccount, m.tenHienThi, m.vai)), [
        (18, 'Trần An', VaiNha.chu),
        (25, 'Nguyễn Bình', VaiNha.thanhVien),
      ]);
      expect(t.thanhVienCu.map((m) => (m.idaccount, m.tenHienThi, m.roiLuc)),
          [(31, 'Lê Bình', DateTime.utc(2026, 10, 24, 3))]);
      expect(t.nhanLuc, luc);
    });

    test('FINAL I-2: formerMembers bỏ người đang ở và khử trùng theo id (người vào lại nhà tạo hàng mới)', () {
      final j = nhaJson();
      j['formerMembers'] = [
        {'idaccount': 25, 'displayName': 'Nguyễn Bình', 'leftAt': '2026-10-20T03:00:00.000Z'}, // đang ở lại
        {'idaccount': 31, 'displayName': 'Lê Bình', 'leftAt': '2026-10-24T03:00:00.000Z'},
        {'idaccount': 31, 'displayName': 'Lê Bình', 'leftAt': '2026-10-25T03:00:00.000Z'}, // rời lần hai
      ];
      final t = nhaCuaToiTuJson(j, nhanLuc: luc);
      expect(t.thanhVienCu.map((m) => m.idaccount), [31],
          reason: 'id đang ở lại hiện "(đã rời)" cạnh tên thật và trùng Key("chon-<id>") ở bảng lọc Hoạt động');
    });

    test('{household: null} / rác → chưa có nhà', () {
      expect(nhaCuaToiTuJson(const {'household': null}, nhanLuc: luc).coNha, isFalse);
      expect(nhaCuaToiTuJson(const {}, nhanLuc: luc).coNha, isFalse);
      expect(
          nhaCuaToiTuJson(const {
            'household': {'name': 'không id'}
          }, nhanLuc: luc)
              .coNha,
          isFalse);
    });

    test('nhà Dissolved đọc là chưa có nhà (máy phải chạy đường dọn)', () {
      expect(nhaCuaToiTuJson(nhaJson(status: 'Dissolved'), nhanLuc: luc).coNha, isFalse);
    });

    test('thiếu maxMembers → 6; thiếu maxSharedWallets → null (chưa biết); thành viên thiếu idaccount bị bỏ', () {
      final j = nhaJson(members: [
        {'displayName': 'Không id', 'role': 'Member'},
        {'idaccount': 25, 'displayName': 'Nguyễn Bình', 'role': 'Member'},
      ]);
      (j['household'] as Map)
        ..remove('maxMembers')
        ..remove('maxSharedWallets');
      final t = nhaCuaToiTuJson(j, nhanLuc: luc);
      expect(t.nha!.toiDaThanhVien, kToiDaThanhVienMacDinh);
      expect(t.nha!.toiDaViChung, isNull,
          reason: 'server im về trần ví chung là CHƯA BIẾT — bịa 10 là màn 2a khoá nhầm');
      expect(t.thanhVien.map((m) => m.idaccount), [25]);
    });

    test('ghi kho rồi đọc lại giữ nguyên (kể cả thanhVienCu, toiDaViChung); kho rác → null', () {
      final t = nhaCuaToiTuJson(nhaJson(myRole: 'Viewer', status: 'ReadOnly'), nhanLuc: luc);
      final lai = NhaCuaToi.tuJsonKho(t.toJson())!;
      expect(lai.nha!.id, 12);
      expect(lai.nha!.trangThai, TrangThaiNha.chiXem);
      expect(lai.nha!.toiDaViChung, 10);
      expect(lai.vai, VaiNha.chiXem);
      expect(lai.thanhVien, hasLength(2));
      expect(lai.thanhVienCu.single.tenHienThi, 'Lê Bình');
      expect(lai.nhanLuc, luc);
      expect(NhaCuaToi.tuJsonKho('rác'), isNull);
      expect(NhaCuaToi.tuJsonKho(const {'household': null}), isNull, reason: 'thiếu nhanLuc = hàng hỏng');
      expect(NhaCuaToi.tuJsonKho(NhaCuaToi.khongCo(luc).toJson())!.coNha, isFalse);
    });

    test('hình dạng phẳng cũ không còn được đọc: chưa có nhà, không ném', () {
      expect(
          nhaCuaToiTuJson(const {'idhousehold': 12, 'name': 'Cũ', 'myRole': 'Owner'}, nhanLuc: luc).coNha, isFalse);
    });

    test('thân thật ở 8e3b4e48: không nhà có đủ bốn khoá; thành viên displayName; thừa contributionDueDay không sao',
        () {
      final khong = {'household': null, 'myRole': null, 'members': <Object?>[], 'formerMembers': <Object?>[]};
      expect(laThanTrangThaiNha(khong), isTrue);
      expect(nhaCuaToiTuJson(khong, nhanLuc: luc).coNha, isFalse);
      final j = nhaJson();
      (j['household'] as Map)['contributionDueDay'] = 5;
      final t = nhaCuaToiTuJson(j, nhanLuc: luc);
      expect(t.nha!.id, 12);
      expect(t.thanhVien.first.tenHienThi, 'Trần An');
    });
  });

  test('laThanTrangThaiNha: thân của #8 / #10 / #12 / #16 KHÔNG phải trạng thái nhà', () {
    expect(laThanTrangThaiNha(nhaJson()), isTrue);
    expect(laThanTrangThaiNha(const {'idhousehold': 12}), isFalse);
    expect(laThanTrangThaiNha(const {'household': null}), isTrue,
        reason: '#11 rời nhà — "không nhà" LÀ một trạng thái');
    expect(laThanTrangThaiNha(const {'targetIdaccount': 25, 'newRole': 'Viewer'}), isFalse, reason: '#8 đổi vai');
    expect(laThanTrangThaiNha(const {'removed': true}), isFalse, reason: '#10 mời ra');
    expect(laThanTrangThaiNha(const {'dissolved': true}), isFalse, reason: '#12 giải tán');
    expect(laThanTrangThaiNha(const {'declined': true}), isFalse, reason: '#16 từ chối lời mời');
    expect(laThanTrangThaiNha(const {'household': <String, Object?>{}}), isFalse,
        reason: 'M1: khoá có mà thân rỗng (không id) → đọc thành "không nhà" là DoiNha(nhà → null) xoá hàng nhà');
    expect(laThanTrangThaiNha(const {'household': 12}), isFalse, reason: 'M1: kiểu lạ');
    expect(laThanTrangThaiNha(const {'household': {'id': 12}}), isTrue, reason: 'có id → trạng thái nhà thật');
    expect(laThanTrangThaiNha(const {}), isFalse,
        reason: 'đọc thân rỗng là "chưa có nhà" → DoiNha(nhà → null) → máy tự xoá dữ liệu nhà sau một lần đổi vai');
  });
}

import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';

/// Hình dạng trạng thái nhà — model theo `docs/Family/01` mục 4 (LỒNG), và hai hình dạng backend `177dd0e1` đang trả (đơn
/// 57.1): `/me` PHẲNG và `POST /` hàng Prisma THÔ. Một bộ đọc, không bao giờ ném. Gỡ hai nhóm cuối khi 57.1 đóng.
void main() {
  final luc = DateTime.utc(2026, 10, 24, 8);

  group('hình dạng LỒNG (docs/Family/01 mục 4 — đích)', () {
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
  });

  group('hình dạng PHẲNG của /me, #7, #9, #15 ở backend 177dd0e1 (đơn 57.1) — gỡ nhóm này khi backend đóng 57.1', () {
    test('đọc được nhà, vai, thành viên (fullname), thành viên cũ, trần ví chung', () {
      final t = nhaCuaToiTuJson(nhaJsonPhang(), nhanLuc: luc);
      expect(t.coNha, isTrue,
          reason: '/me hiện trả PHẲNG — chỉ đọc lồng là app luôn thấy "chưa có nhà", kể cả sau khi tạo');
      expect(t.nha!.id, 12);
      expect(t.nha!.ten, 'Nhà An – Bình');
      expect(t.nha!.trangThai, TrangThaiNha.hoatDong);
      expect(t.nha!.toiDaThanhVien, 6);
      expect(t.nha!.idChuNha, 18, reason: 'khoá phẳng là ownerIdaccount');
      expect(t.nha!.toiDaViChung, 10);
      expect(t.nha!.taoLuc, DateTime.utc(2026, 10, 23, 8), reason: 'khoá phẳng là createdAt');
      expect(t.vai, VaiNha.chu);
      expect(t.thanhVien.map((m) => (m.idaccount, m.tenHienThi, m.vai)), [
        (18, 'Trần An', VaiNha.chu),
        (25, 'Nguyễn Bình', VaiNha.thanhVien),
      ]);
      expect(t.thanhVienCu.map((m) => (m.idaccount, m.tenHienThi)), [(31, 'Lê Bình')]);
    });

    test('fullname rỗng → username; ReadOnly / Dissolved đọc như lồng', () {
      final j = nhaJsonPhang(members: [
        {'idaccount': 18, 'username': 'an', 'fullname': '', 'role': 'Owner'},
      ]);
      expect(nhaCuaToiTuJson(j, nhanLuc: luc).thanhVien.single.tenHienThi, 'an');
      expect(nhaCuaToiTuJson(nhaJsonPhang(status: 'ReadOnly'), nhanLuc: luc).nha!.trangThai, TrangThaiNha.chiXem);
      expect(nhaCuaToiTuJson(nhaJsonPhang(status: 'Dissolved'), nhanLuc: luc).coNha, isFalse);
    });

    test('có CẢ household lồng lẫn idhousehold phẳng → lồng thắng', () {
      final j = nhaJson()..['idhousehold'] = 99;
      expect(nhaCuaToiTuJson(j, nhanLuc: luc).nha!.id, 12,
          reason: 'backend đóng 57.1 rồi mà còn để sót khoá phẳng thì hình dạng đích vẫn thắng');
    });
  });

  group('hàng THÔ + myRole của POST / ở backend 177dd0e1 (đơn 57.1) — gỡ khi backend đóng 57.1', () {
    test('đọc được nhà + vai từ cột snake_case; không members → thanhVien rỗng (repository hỏi lại /me)', () {
      final t = nhaCuaToiTuJson(nhaJsonThoTaoNha(), nhanLuc: luc);
      expect(t.coNha, isTrue);
      expect(t.nha!.id, 12);
      expect(t.nha!.ten, 'Nhà An');
      expect(t.nha!.idChuNha, 18, reason: 'owner_idaccount');
      expect(t.nha!.toiDaThanhVien, 6, reason: 'max_members');
      expect(t.nha!.toiDaViChung, 10, reason: 'max_shared_wallets');
      expect(t.nha!.taoLuc, DateTime.utc(2026, 10, 23, 8), reason: 'create_at');
      expect(t.vai, VaiNha.chu);
      expect(t.thanhVien, isEmpty);
      expect(t.thanhVienCu, isEmpty);
    });

    test('delete_at khác null → chưa có nhà', () {
      final j = nhaJsonThoTaoNha()..['delete_at'] = '2026-10-24T03:00:00.000Z';
      expect(nhaCuaToiTuJson(j, nhanLuc: luc).coNha, isFalse);
    });
  });

  test('laThanTrangThaiNha: thân của #8 / #10 / #12 / #16 KHÔNG phải trạng thái nhà', () {
    expect(laThanTrangThaiNha(nhaJson()), isTrue);
    expect(laThanTrangThaiNha(nhaJsonPhang()), isTrue);
    expect(laThanTrangThaiNha(nhaJsonThoTaoNha()), isTrue);
    expect(laThanTrangThaiNha(const {'household': null}), isTrue,
        reason: '#11 rời nhà — "không nhà" LÀ một trạng thái');
    expect(laThanTrangThaiNha(const {'targetIdaccount': 25, 'newRole': 'Viewer'}), isFalse, reason: '#8 đổi vai');
    expect(laThanTrangThaiNha(const {'removed': true}), isFalse, reason: '#10 mời ra');
    expect(laThanTrangThaiNha(const {'dissolved': true}), isFalse, reason: '#12 giải tán');
    expect(laThanTrangThaiNha(const {'declined': true}), isFalse, reason: '#16 từ chối lời mời');
    expect(laThanTrangThaiNha(const {}), isFalse,
        reason: 'đọc thân rỗng là "chưa có nhà" → DoiNha(nhà → null) → máy tự xoá dữ liệu nhà sau một lần đổi vai');
  });
}

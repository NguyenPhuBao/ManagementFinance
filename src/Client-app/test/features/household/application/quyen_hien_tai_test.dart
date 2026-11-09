/// FINAL I-3: MỘT định nghĩa "lúc Lưu, tôi còn làm được việc này ở nhà này không" cho cả bốn form (khoản, danh mục, góp / rút,
/// ví chung). Đọc `hienTai` lúc gọi, không chụp lúc mở form.
library;

import 'package:flowmoney/features/household/application/quyen_hien_tai.dart';
import 'package:flowmoney/features/household/domain/quyen_nha.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/household_api_gia.dart';
import '../../../helpers/nha_gia.dart';

void main() {
  test('Chủ nhà hoạt động: ghi khoản và chuyển giữa ví chung được', () async {
    final repo = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson());
    expect(conDuocLamViecNha(repo, 12, ViecNha.ghiKhoan), isTrue);
    expect(conDuocLamViecNha(repo, 12, ViecNha.chuyenGiuaViChung), isTrue);
  });

  test('id nhà khác với nhà hiện tại → false (form mở cho nhà cũ, người dùng đã sang nhà khác)', () async {
    final repo = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson());
    expect(conDuocLamViecNha(repo, 99, ViecNha.ghiKhoan), isFalse, reason: 'so id nhà, không chỉ vai');
  });

  test('Thành viên: ghi khoản được, chuyển giữa ví chung thì không', () async {
    final repo = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Member'));
    expect(conDuocLamViecNha(repo, 12, ViecNha.ghiKhoan), isTrue);
    expect(conDuocLamViecNha(repo, 12, ViecNha.chuyenGiuaViChung), isFalse);
  });

  test('Chỉ xem, và nhà không hoạt động: không ghi được', () async {
    final xem = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Viewer'));
    expect(conDuocLamViecNha(xem, 12, ViecNha.ghiKhoan), isFalse);
    final chiXem = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(status: 'ReadOnly'));
    expect(conDuocLamViecNha(chiXem, 12, ViecNha.suaDanhMuc), isFalse, reason: 'nhà chỉ xem: không ai ghi');
  });

  test('chưa có nhà → false', () async {
    final repo = await repoNhaThu(HouseholdApiGia());
    expect(conDuocLamViecNha(repo, 12, ViecNha.ghiKhoan), isFalse);
  });
}

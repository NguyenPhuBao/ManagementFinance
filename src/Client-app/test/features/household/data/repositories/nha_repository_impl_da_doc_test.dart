/// `NhaRepository.lamMoi` trả `bool` (đã đọc và áp `/me` chưa) và `daDocNha` (phát sau MỖI lần áp, kể cả nhà không đổi) —
/// gia đình 1A, Task 9: resolver cần biết "nhà hiện tại" là của server hay chỉ là bản cũ trong kho; bộ điều phối cần một
/// tín hiệu để dọn hàng nhà kẹt khi không có cặp `DoiNha` nào.
library;

import 'dart:async';

import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';
import 'nha_repository_impl_test.dart' show ApiTreoCuaToi;

Future<void> _nghi() => Future<void>.delayed(Duration.zero);

void main() {
  late HouseholdApiGia api;
  late InMemoryNhaStore kho;
  late NhaRepositoryImpl repo;
  late List<(int, int?)> daDoc;
  late List<DoiNha> doi;

  void dung(HouseholdApiGia a) {
    api = a;
    kho = InMemoryNhaStore();
    repo = NhaRepositoryImpl(api: api, kho: kho, clock: () => DateTime.utc(2026, 11, 1, 8));
    daDoc = [];
    doi = [];
    repo.daDocNha.listen((d) => daDoc.add((d.idaccount, d.idNha)));
    repo.doiNha.listen(doi.add);
  }

  setUp(() => dung(HouseholdApiGia()));
  tearDown(() => repo.dispose());

  test('đọc được /me không nhà (kho vắng): true, phát daDocNha(null) dù KHÔNG có DoiNha', () async {
    await repo.datTaiKhoan(18);
    expect(await repo.lamMoi(), isTrue);
    await _nghi();
    expect(doi, isEmpty, reason: 'kho vắng + /me không nhà: không đổi — đúng chỗ hàng nhà kẹt');
    expect(daDoc, [(18, null)]);
  });

  test('cùng nhà 12 hai lần: mỗi lần áp đều phát daDocNha (kể cả không đổi)', () async {
    api.cuaToiJson = nhaJson();
    await repo.datTaiKhoan(18);
    expect(await repo.lamMoi(), isTrue);
    expect(await repo.lamMoi(), isTrue);
    await _nghi();
    expect(daDoc, [(18, 12), (18, 12)]);
    expect(doi, hasLength(1), reason: 'DoiNha chỉ phát khi nhà đổi');
  });

  test('API hỏng: false, không phát daDocNha', () async {
    api.loi = loiServer(503, 'MAINTENANCE_MODE');
    await repo.datTaiKhoan(18);
    expect(await repo.lamMoi(), isFalse);
    await _nghi();
    expect(daDoc, isEmpty, reason: 'không đọc được thì không có gì để dọn theo');
  });

  test('thân /me không phải trạng thái nhà: false, không phát', () async {
    api.cuaToiJson = const <String, Object?>{};
    await repo.datTaiKhoan(18);
    expect(await repo.lamMoi(), isFalse);
    await _nghi();
    expect(daDoc, isEmpty);
  });

  test('chưa có phiên: false', () async {
    expect(await repo.lamMoi(), isFalse);
    expect(daDoc, isEmpty);
  });

  test('đăng xuất giữa chừng: false, không phát', () async {
    final tre = ApiTreoCuaToi()..treoCuaToi = Completer<void>();
    await repo.dispose();
    dung(tre);
    await repo.datTaiKhoan(18);
    final f = repo.lamMoi();
    await _nghi();
    repo.xoaPhien();
    tre.treoCuaToi!.complete();
    expect(await f, isFalse);
    await _nghi();
    expect(daDoc, isEmpty);
  });

  test('ảnh chụp /me trước một thao tác đã thành công bị bỏ: false (không dùng làm "nhà hiện tại")', () async {
    final tre = ApiTreoCuaToi()..treoCuaToi = Completer<void>();
    await repo.dispose();
    dung(tre);
    await repo.datTaiKhoan(18);
    final f = repo.lamMoi();
    await _nghi();
    tre.traVe = nhaJson(id: 12);
    await repo.taoNha('Nhà mới'); // thao tác thành công: thế hệ tăng, trạng thái nhà 12 đã áp
    tre.treoCuaToi!.complete();
    expect(await f, isFalse, reason: 'lượt /me gửi TRƯỚC thao tác trả ảnh chụp cũ, bị bỏ vì thế hệ');
    await _nghi();
    expect(daDoc, [(18, 12)], reason: 'chỉ lần áp của thao tác; ảnh chụp bị bỏ không phát');
  });
}

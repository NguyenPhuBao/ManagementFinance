/// `NhaRepository` — nguồn sự thật phía client về nhà của tài khoản đang đăng nhập (spec gia đình 2026-10-23 mục 5.8),
/// khuôn `GoiRepository`: kho theo tài khoản, `lamMoi` không ném (nhà rồi lời mời), năm nguồn làm mới. Thêm: phát [DoiNha] khi id nhà ĐỔI so
/// với lần biết trước (kể cả bản trong kho) — bộ điều phối dựa vào đó để dọn / kéo lại toàn bộ.
library;

import 'dart:async';

import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';

Future<void> _nghi() => Future<void>.delayed(Duration.zero);

void main() {
  var now = DateTime.utc(2026, 10, 24, 8);
  late HouseholdApiGia api;
  late InMemoryNhaStore kho;
  late NhaRepositoryImpl repo;
  late List<DoiNha> doi;

  setUp(() {
    now = DateTime.utc(2026, 10, 24, 8);
    api = HouseholdApiGia();
    kho = InMemoryNhaStore();
    repo = NhaRepositoryImpl(api: api, kho: kho, clock: () => now);
    doi = [];
    repo.doiNha.listen(doi.add);
  });
  tearDown(() => repo.dispose());

  NhaCuaToi trangThai({String status = 'Active', String role = 'Owner', int id = 12}) =>
      nhaCuaToiTuJson(nhaJson(id: id, status: status, myRole: role), nhanLuc: now);

  group('kho + làm mới', () {
    test('datTaiKhoan nạp kho, KHÔNG phát DoiNha', () async {
      kho.values[18] = trangThai();
      await repo.datTaiKhoan(18);
      expect(repo.hienTai.nha!.id, 12);
      await _nghi();
      expect(doi, isEmpty, reason: 'nạp kho không phải nhà đổi — dọn / kéo lại ở đây là việc thừa mỗi lần mở app');
    });

    test('kho trống + server có nhà → lưu kho, phát DoiNha(null → 12)', () async {
      api.cuaToiJson = nhaJson();
      await repo.datTaiKhoan(18);
      await repo.lamMoi();
      expect(repo.hienTai.vai, VaiNha.chu);
      expect((await kho.doc(18))!.nha!.id, 12);
      await _nghi();
      expect(doi.map((d) => (d.idaccount, d.tu, d.den)), [(18, null, 12)],
          reason: 'máy thứ hai của cùng tài khoản / kho mất: dữ liệu cũ của nhà chưa về — phải kéo lại toàn bộ');
    });

    test('kho có nhà 12 + server không nhà → phát DoiNha(12 → null), kho ghi "không nhà"', () async {
      kho.values[18] = trangThai();
      await repo.datTaiKhoan(18);
      await repo.lamMoi(); // cuaToiJson mặc định {household: null}
      expect(repo.hienTai.coNha, isFalse);
      expect((await kho.doc(18))!.coNha, isFalse);
      await _nghi();
      expect(doi.map((d) => (d.tu, d.den)), [(12, null)]);
    });

    test('/me trả thân KHÔNG phải trạng thái nhà ({}) khi kho có nhà 12 → giữ nhà, không phát DoiNha', () async {
      kho.values[18] = trangThai();
      api.cuaToiJson = const <String, Object?>{};
      await repo.datTaiKhoan(18);
      await repo.lamMoi();
      expect(repo.hienTai.nha!.id, 12, reason: 'thân lạ đọc thành "không nhà" là xoá dữ liệu nhà (M2)');
      expect((await kho.doc(18))!.nha!.id, 12);
      await _nghi();
      expect(doi, isEmpty);
    });

    test('cùng nhà → không phát', () async {
      kho.values[18] = trangThai();
      api.cuaToiJson = nhaJson();
      await repo.datTaiKhoan(18);
      await repo.lamMoi();
      await _nghi();
      expect(doi, isEmpty);
    });

    test('lamMoi hỏng → giữ trạng thái, không ném, không phát', () async {
      kho.values[18] = trangThai();
      api.loi = loiServer(503, 'MAINTENANCE_MODE');
      await repo.datTaiKhoan(18);
      await repo.lamMoi();
      expect(repo.hienTai.nha!.id, 12);
      await _nghi();
      expect(doi, isEmpty);
    });

    test('hai lamMoi chồng nhau dùng một lời gọi', () async {
      await repo.datTaiKhoan(18);
      api.treo = Completer<void>();
      final a = repo.lamMoi();
      final b = repo.lamMoi();
      api.treo!.complete();
      await Future.wait([a, b]);
      expect(api.goi.where((g) => g == 'cuaToi'), hasLength(1));
      expect(api.goi.where((g) => g == 'dsLoiMoiToi'), hasLength(1), reason: 'lời mời cũng đi chung một lượt');
    });

    test('phiên đổi giữa lượt làm mới → kết quả bị bỏ', () async {
      api.cuaToiJson = nhaJson();
      await repo.datTaiKhoan(18);
      api.treo = Completer<void>();
      final f = repo.lamMoi();
      repo.xoaPhien();
      api.treo!.complete();
      await f;
      expect(repo.hienTai.coNha, isFalse);
      expect(kho.values.containsKey(18), isFalse);
    });

    test('xoaPhien không phát DoiNha (đăng xuất không phải rời nhà)', () async {
      kho.values[18] = trangThai();
      await repo.datTaiKhoan(18);
      repo.xoaPhien();
      await _nghi();
      expect(doi, isEmpty, reason: 'phát ở đây là xoá dữ liệu của nhà mỗi lần đăng xuất');
      expect(repo.hienTai.coNha, isFalse);
    });

    test('nhaDaLuu đọc kho của tài khoản bất kỳ (phép dọn lúc đổi tài khoản)', () async {
      kho.values[25] = trangThai(id: 7);
      expect(await repo.nhaDaLuu(25), 7);
      expect(await repo.nhaDaLuu(99), isNull);
    });

    test('resumed giãn 5 phút', () async {
      await repo.datTaiKhoan(18);
      final vongDoi = StreamController<AppLifecycleState>();
      repo.noiVongDoi(vongDoi.stream);
      vongDoi.add(AppLifecycleState.resumed);
      await _nghi();
      expect(api.goi, isEmpty, reason: 'vừa nhận (nhanLuc = now)');
      now = now.add(const Duration(minutes: 6));
      vongDoi.add(AppLifecycleState.resumed);
      await _nghi();
      expect(api.goi, ['cuaToi', 'dsLoiMoiToi'], reason: 'lamMoi làm mới nhà RỒI lời mời — một lượt, thứ tự cố định');
      await vongDoi.close();
    });
  });

  group('thao tác', () {
    setUp(() async => repo.datTaiKhoan(18));

    test('tạo nhà thành công → trạng thái + kho + DoiNha', () async {
      api.traVe = nhaJson();
      await repo.taoNha('  Nhà An  ');
      expect(api.goi, ['taoNha:Nhà An'], reason: 'cắt khoảng trắng trước khi gửi');
      expect(repo.hienTai.nha!.id, 12);
      await _nghi();
      expect(doi.map((d) => (d.tu, d.den)), [(null, 12)]);
    });

    test('lỗi server → ném LoiNha đúng loại', () async {
      api.loi = loiServer(403, 'FEATURE_DISABLED');
      await expectLater(
          repo.taoNha('Nhà An'), throwsA(isA<LoiNha>().having((e) => e.loai, 'loai', LoaiLoiNha.tinhNangKhongMo)));
    });

    test('lỗi cho thấy nhà đã đổi nơi khác → làm mới trạng thái', () async {
      api.loi = loiServer(409, 'HOUSEHOLD_ALREADY_IN_ONE');
      await expectLater(repo.thamGia('abcd-2345'), throwsA(isA<LoiNha>()));
      api.loi = null;
      await _nghi();
      expect(api.goi, ['thamGia:ABCD2345', 'cuaToi', 'dsLoiMoiToi'],
          reason:
              'mã đã chuẩn hoá; đã ở nhà khác (máy khác) → hỏi lại; mã THẬT của backend (FORBIDDEN_NOT_OWNER…) đi cùng '
              'đường qua loaiLoiTuMa (Task 8)');
    });

    test(
        'tạo nhà nhận hàng THÔ của POST / hiện tại (đơn 57.1): nhà hiện ngay, hỏi lại /me lấy thành viên, DoiNha MỘT lần',
        () async {
      api.traVe = nhaJsonThoTaoNha();
      api.cuaToiJson = nhaJson();
      await repo.taoNha('Nhà An');
      expect(api.goi, ['taoNha:Nhà An', 'cuaToi', 'dsLoiMoiToi'],
          reason: 'hàng thô không có members — áp ngay cho nhà hiện tức thì, rồi lamMoi (người dùng chốt 2026-10-28)');
      expect(repo.hienTai.nha!.id, 12);
      expect(repo.hienTai.thanhVien, hasLength(2), reason: 'thành viên lấy từ /me');
      await _nghi();
      expect(doi.map((d) => (d.tu, d.den)), [(null, 12)],
          reason: 'hàng đợi áp trạng thái — lượt /me cùng nhà, không phát lại');
    });

    test('⚠️ đổi vai / mời ra / giải tán trả thân KHÔNG phải trạng thái nhà → hỏi lại /me, không phát DoiNha oan',
        () async {
      // Backend 177dd0e1: #8 `{targetIdaccount, newRole}`, #10 `{removed: true}`, #12 `{dissolved: true}` (04 mục 2). Bản kế
      // hoạch 2026-10-24 áp thẳng → đọc thành "chưa có nhà" → DoiNha(12 → null) → DieuPhoiDoiNha xoá sạch dữ liệu nhà trên
      // máy CHỦ NHÀ ngay sau khi đổi vai một người (preflight 2026-10-28 #2).
      kho.values[18] = trangThai();
      await repo.datTaiKhoan(18);
      api.cuaToiJson = nhaJson();

      api.traVe = const {'targetIdaccount': 25, 'newRole': 'Viewer'};
      await repo.doiVai(25, VaiNha.chiXem);
      expect(repo.hienTai.coNha, isTrue);
      expect(api.goi, ['doiVai:25:Viewer', 'cuaToi', 'dsLoiMoiToi'],
          reason: 'đổi vai gửi chữ server; thân không áp → hỏi lại');

      api.goi.clear();
      api.traVe = const {'removed': true};
      await repo.moiRa(25);
      expect(repo.hienTai.coNha, isTrue);
      expect(api.goi, ['moiRa:25', 'cuaToi', 'dsLoiMoiToi']);
      await _nghi();
      expect(doi, isEmpty, reason: 'nhà không đổi — không được dọn dữ liệu');

      api.goi.clear();
      api.traVe = const {'dissolved': true};
      api.cuaToiJson = const {'household': null};
      await repo.giaiTan();
      expect(repo.hienTai.coNha, isFalse);
      expect(api.goi, ['giaiTan', 'cuaToi', 'dsLoiMoiToi']);
      await _nghi();
      expect(doi.map((d) => (d.tu, d.den)), [(12, null)],
          reason: 'giải tán: /me nói không nhà → DoiNha từ lượt làm mới');
    });

    test('rời nhà → {household: null} → DoiNha(12 → null)', () async {
      kho.values[18] = trangThai(role: 'Member');
      await repo.datTaiKhoan(18);
      api.traVe = const {'household': null};
      await repo.roiNha();
      expect(repo.hienTai.coNha, isFalse);
      expect(api.goi, ['roiNha'], reason: '{household: null} LÀ trạng thái — áp thẳng, không hỏi lại');
      await _nghi();
      expect(doi.map((d) => (d.tu, d.den)), [(12, null)]);
    });

    test('tạo mã / danh sách mã (mọi trạng thái, conHieuLuc để lọc) / xem trước đọc model', () async {
      final m = await repo.taoMaMoi(VaiNha.thanhVien);
      expect((m.ma, m.vai), ('ABCD2345', VaiNha.thanhVien));
      api.dsMaMoiJson = const [
        {'code': 'ABCD2345', 'role': 'Member'},
        {'code': 'EMAIL123', 'role': 'Member', 'email': 'an@x.com', 'status': 'Revoked'},
        {'role': 'Member'},
      ];
      final ds = await repo.dsMaMoi();
      expect(ds.map((m) => (m.ma, m.conHieuLuc)), [('ABCD2345', true), ('EMAIL123', false)],
          reason: 'phần tử không mã bị bỏ; #4 trả cả mã chết — repository giữ, màn lọc conHieuLuc');
      final x = await repo.xemTruoc('ABCD2345');
      expect(x.tenNha, 'Nhà An – Bình');
      expect(api.goi, ['taoMaMoi:Member', 'dsMaMoi', 'xemTruoc:ABCD2345']);
    });

    test('server trả mã rỗng khi tạo mã → LoiNha(khac)', () async {
      api.maMoiJson = const {};
      await expectLater(
          repo.taoMaMoi(VaiNha.thanhVien), throwsA(isA<LoiNha>().having((e) => e.loai, 'loai', LoaiLoiNha.khac)));
    });
  });

  group('lời mời gửi tới tôi (01 mục 2; chỉ RAM — người dùng chốt 2026-10-28)', () {
    setUp(() async => repo.datTaiKhoan(18));

    test('lamMoiLoiMoi đọc #14; hỏng giữ danh sách cũ; xoaPhien xoá', () async {
      api.dsLoiMoiToiJson = const [
        {'code': 'ABCD2345', 'householdName': 'Nhà An – Bình', 'inviterName': 'Trần An', 'role': 'Member'},
        {'householdName': 'không mã'},
      ];
      await repo.lamMoiLoiMoi();
      expect(repo.loiMoiToi.map((l) => l.ma), ['ABCD2345'], reason: 'phần tử không mã bị bỏ');
      api.loi = loiServer(503, 'MAINTENANCE_MODE');
      await repo.lamMoiLoiMoi();
      expect(repo.loiMoiToi, hasLength(1), reason: 'không ném, giữ cũ');
      repo.xoaPhien();
      expect(repo.loiMoiToi, isEmpty, reason: 'lời mời là của tài khoản — đăng xuất là hết');
    });

    test('moiQuaEmail: cắt trắng + chữ thường trước khi gửi, vai là chữ server, đọc kết quả', () async {
      final k = await repo.moiQuaEmail('  An@X.com ', VaiNha.chiXem);
      expect(api.goi, ['moiQuaEmail:an@x.com:Viewer'], reason: 'server so với lower(account.Email) (01 mục 2.2)');
      expect(k.email, 'an@x.com');
    });

    test('chapNhanLoiMoi → trạng thái nhà + DoiNha; tuChoiLoiMoi → làm mới danh sách lời mời', () async {
      api.traVe = nhaJson();
      await repo.chapNhanLoiMoi('abcd-2345');
      expect(api.goi, ['chapNhanLoiMoi:ABCD2345', 'dsLoiMoiToi'],
          reason: 'spec 01 mục 2.8: sau mỗi thao tác 13–16 danh sách lời mời được làm mới');
      expect(repo.hienTai.nha!.id, 12);
      await _nghi();
      expect(doi.map((d) => (d.tu, d.den)), [(null, 12)]);

      api.goi.clear();
      await repo.tuChoiLoiMoi('ABCD2345');
      expect(api.goi, ['tuChoiLoiMoi:ABCD2345', 'dsLoiMoiToi'],
          reason: '{declined: true} không phải trạng thái — chỉ làm mới lời mời');
    });

    test('lỗi lời mời email → LoiNha đúng loại, không làm mới nhà', () async {
      api.loi = loiServer(403, 'HOUSEHOLD_INVITE_WRONG_ACCOUNT');
      await expectLater(repo.chapNhanLoiMoi('ABCD2345'),
          throwsA(isA<LoiNha>().having((e) => e.loai, 'loai', LoaiLoiNha.loiMoiKhongPhaiCuaBan)));
      api.loi = null;
      await _nghi();
      expect(api.goi, ['chapNhanLoiMoi:ABCD2345'], reason: 'thư bị chuyển tiếp không nói gì về nhà của tôi');
    });
  });

  group('nguồn làm mới', () {
    test('noiPhien: id → datTaiKhoan + lamMoi; null → xoaPhien', () async {
      api.cuaToiJson = nhaJson();
      final phien = StreamController<int?>();
      repo.noiPhien(phien.stream);
      phien.add(18);
      await _nghi();
      await _nghi();
      expect(repo.idaccount, 18);
      expect(api.goi, ['cuaToi', 'dsLoiMoiToi']);
      phien.add(18); // AuthSuccess phát lại — không phải lý do hỏi lại
      await _nghi();
      expect(api.goi, ['cuaToi', 'dsLoiMoiToi']);
      phien.add(null);
      await _nghi();
      expect(repo.idaccount, isNull);
      await phien.close();
    });

    test('noiSuKien: household.changed làm mới cả hai; household.invited chỉ làm mới lời mời; sự kiện khác im',
        () async {
      await repo.datTaiKhoan(18);
      final suKien = StreamController<RealtimeEvent>();
      repo.noiSuKien(suKien.stream);
      suKien.add(RealtimeEvent.dongBoXong);
      await _nghi();
      expect(api.goi, isEmpty);
      suKien.add(RealtimeEvent.nhaDoi);
      await _nghi();
      expect(api.goi, ['cuaToi', 'dsLoiMoiToi'],
          reason: 'chủ nhà thấy lời mời bị từ chối qua household.changed (01 mục 2.2)');
      api.goi.clear();
      suKien.add(RealtimeEvent.loiMoiNha);
      await _nghi();
      expect(api.goi, ['dsLoiMoiToi'], reason: 'được mời không đổi nhà của tôi — không hỏi /me');
      await suKien.close();
    });

    test('noiKetQuaDay: năm mã đẩy kMaDayLoiNha làm mới; NOT_OWNER / HOUSEHOLD_WALLET_LIMIT thì không', () async {
      await repo.datTaiKhoan(18);
      final kq = StreamController<SyncResult>();
      repo.noiKetQuaDay(kq.stream);
      SyncResult voi(String ma) => SyncResult(totalOps: 1, succeeded: 0, failed: 1, failures: [
            SyncOpFailure(
                localId: 'w', entity: SyncEntityType.wallet, message: ma, kind: SyncFailureKind.permanent, code: ma),
          ]);
      kq.add(voi('NOT_OWNER'));
      await _nghi();
      expect(api.goi, isEmpty, reason: 'NOT_OWNER là hàng RIÊNG của người khác — không nói gì về nhà');
      kq.add(voi('HOUSEHOLD_WALLET_LIMIT'));
      await _nghi();
      expect(api.goi, isEmpty, reason: 'trần ví chung không nói gì về vai / trạng thái nhà');
      kq.add(voi('HOUSEHOLD_READ_ONLY'));
      await _nghi();
      expect(api.goi, ['cuaToi', 'dsLoiMoiToi']);
      api.goi.clear();
      kq.add(voi('HOUSEHOLD_ROLE_FORBIDDEN'));
      await _nghi();
      expect(api.goi, ['cuaToi', 'dsLoiMoiToi'],
          reason: 'vai vừa đổi ở máy khác (01 mục 3) — trạng thái nhà trên máy đã cũ');
      await kq.close();
    });
  });

  group('lượt làm mới đang bay (cuộc đua — vòng sửa 1)', () {
    late ApiTreoCuaToi tre;
    late NhaRepositoryImpl r;
    late InMemoryNhaStore k;
    late List<DoiNha> d;

    setUp(() {
      tre = ApiTreoCuaToi();
      k = InMemoryNhaStore();
      r = NhaRepositoryImpl(api: tre, kho: k, clock: () => now);
      d = [];
      r.doiNha.listen(d.add);
    });
    tearDown(() => r.dispose());

    List<(int?, int?)> doiLa() => d.map((x) => (x.tu, x.den)).toList();

    test('A: thamGia giữa một /me cũ đang bay → DoiNha đúng một lần (null → 12), còn nhà', () async {
      await r.datTaiKhoan(18);
      tre.cuaToiJson = const {'household': null};
      tre.treoCuaToi = Completer<void>();
      final l1 = r.lamMoi();
      await _nghi();
      tre.traVe = nhaJson();
      tre.cuaToiJson = nhaJson(); // server sau khi tham gia
      await r.thamGia('ABCD2345');
      tre.treoCuaToi!.complete();
      await l1;
      await _nghi();
      expect(doiLa(), [(null, 12)], reason: 'ảnh chụp /me TRƯỚC thao tác không được đè lên kết quả của chính thao tác');
      expect(r.hienTai.coNha, isTrue);
    });

    test("A': roiNha giữa một /me cũ đang bay → DoiNha (12 → null), hết nhà", () async {
      k.values[18] = nhaCuaToiTuJson(nhaJson(myRole: 'Member'), nhanLuc: now);
      await r.datTaiKhoan(18);
      tre.cuaToiJson = nhaJson(myRole: 'Member');
      tre.treoCuaToi = Completer<void>();
      final l1 = r.lamMoi();
      await _nghi();
      tre.traVe = const {'household': null};
      tre.cuaToiJson = const {'household': null};
      await r.roiNha();
      tre.treoCuaToi!.complete();
      await l1;
      await _nghi();
      expect(doiLa(), [(12, null)]);
      expect(r.hienTai.coNha, isFalse);
    });

    test('B: giaiTan giữa một /me cũ đang bay → xong là hết nhà, DoiNha (12 → null)', () async {
      k.values[18] = nhaCuaToiTuJson(nhaJson(), nhanLuc: now);
      await r.datTaiKhoan(18);
      tre.cuaToiJson = nhaJson();
      tre.treoCuaToi = Completer<void>();
      final l1 = r.lamMoi();
      await _nghi();
      tre.traVe = const {'dissolved': true};
      tre.cuaToiJson = const {'household': null};
      final g = r.giaiTan();
      await _nghi();
      tre.treoCuaToi!.complete();
      await g;
      expect(r.hienTai.coNha, isFalse, reason: 'giaiTan() xong thì trạng thái phải là của một lượt GỬI SAU thao tác');
      await l1;
      await _nghi();
      expect(doiLa(), [(12, null)]);
    });

    test('C: household.changed tới giữa một lượt đang bay → thêm một lời gọi /me sau lượt ấy', () async {
      await r.datTaiKhoan(18);
      tre.treoCuaToi = Completer<void>();
      final l1 = r.lamMoi();
      await _nghi();
      final suKien = StreamController<RealtimeEvent>();
      r.noiSuKien(suKien.stream);
      tre.cuaToiJson = nhaJson();
      suKien.add(RealtimeEvent.nhaDoi);
      await _nghi();
      tre.treoCuaToi!.complete();
      await l1;
      await _nghi();
      expect(tre.goi.where((g) => g == 'cuaToi'), hasLength(2), reason: 'sự kiện không được bị nuốt vào lượt đã gửi');
      expect(r.hienTai.coNha, isTrue);
      await suKien.close();
    });

    test('D: đổi phiên 18 → 25 giữa /me của 18 → 25 hỏi /me riêng, trạng thái là của 25', () async {
      tre.cuaToiJson = nhaJson(id: 12);
      await r.datTaiKhoan(18);
      tre.treoCuaToi = Completer<void>();
      final l1 = r.lamMoi();
      await _nghi();
      r.xoaPhien();
      tre.cuaToiJson = nhaJson(id: 77);
      await r.datTaiKhoan(25);
      final l2 = r.lamMoi();
      tre.treoCuaToi!.complete();
      await Future.wait([l1, l2]);
      await _nghi();
      expect(tre.goi.where((g) => g == 'cuaToi'), hasLength(2));
      expect(r.idaccount, 25);
      expect(r.hienTai.nha!.id, 77);
    });

    const loiMoiA = [
      {'code': 'ABCD2345', 'householdName': 'Nhà A', 'inviterName': 'An', 'role': 'Member'},
    ];
    const loiMoiB = [
      {'code': 'EFGH2345', 'householdName': 'Nhà B', 'inviterName': 'Bình', 'role': 'Member'},
      {'code': 'JKLM2345', 'householdName': 'Nhà C', 'inviterName': 'Chi', 'role': 'Viewer'},
    ];

    test('E: đổi phiên 18 → 25 giữa /invitations của 18 → 25 hỏi RIÊNG, danh sách lời mời là của 25', () async {
      final api2 = ApiTreoLoiMoi();
      final r2 = NhaRepositoryImpl(api: api2, kho: InMemoryNhaStore(), clock: () => now);
      addTearDown(r2.dispose);
      api2.dsLoiMoiToiJson = loiMoiA;
      await r2.datTaiKhoan(18);
      api2.treoLoiMoi = Completer<void>();
      final l1 = r2.lamMoiLoiMoi();
      await _nghi();
      api2.dsLoiMoiToiJson = loiMoiB;
      await r2.datTaiKhoan(25);
      final l2 = r2.lamMoiLoiMoi();
      api2.treoLoiMoi!.complete();
      await Future.wait([l1, l2]);
      await _nghi();
      expect(api2.goi.where((g) => g == 'dsLoiMoiToi'), hasLength(2),
          reason: 'lượt của 18 không được nhận làm lượt của 25 (gỡ `_dangLamMoiLoiMoi` khi đổi phiên)');
      expect(r2.loiMoiToi.map((m) => m.ma), ['EFGH2345', 'JKLM2345']);
    });

    test('G: đăng xuất rồi đăng nhập lại CÙNG tài khoản giữa /invitations → kết quả của kỳ phiên cũ bị bỏ', () async {
      final api2 = ApiTreoLoiMoi();
      final r2 = NhaRepositoryImpl(api: api2, kho: InMemoryNhaStore(), clock: () => now);
      addTearDown(r2.dispose);
      api2.dsLoiMoiToiJson = loiMoiA;
      await r2.datTaiKhoan(18);
      api2.treoLoiMoi = Completer<void>();
      final l1 = r2.lamMoiLoiMoi();
      await _nghi();
      r2.xoaPhien();
      await r2.datTaiKhoan(18);
      api2.treoLoiMoi!.complete();
      await l1;
      await _nghi();
      expect(r2.loiMoiToi, isEmpty,
          reason: 'kết quả muộn của phiên đã đăng xuất không được hiện ở phiên mới (`_kyPhien`)');
    });

    test('đổi tài khoản xoá lời mời của tài khoản cũ', () async {
      await r.datTaiKhoan(18);
      tre.dsLoiMoiToiJson = const [
        {'code': 'ABCD2345', 'householdName': 'Nhà', 'inviterName': 'An', 'role': 'Member'},
      ];
      await r.lamMoiLoiMoi();
      expect(r.loiMoiToi, hasLength(1));
      await r.datTaiKhoan(25);
      expect(r.loiMoiToi, isEmpty);
    });

    test('F: lời mời đã chết (hết hạn / không có / đã dùng / đã từ chối) → ném LoiNha và làm mới danh sách lời mời',
        () async {
      await r.datTaiKhoan(18);
      for (final ma in [
        'HOUSEHOLD_INVITE_EXPIRED',
        'HOUSEHOLD_INVITE_USED',
        'HOUSEHOLD_INVITE_NOT_FOUND',
        'HOUSEHOLD_INVITE_DECLINED'
      ]) {
        tre.goi.clear();
        tre.loi = loiServer(400, ma);
        await expectLater(r.chapNhanLoiMoi('ABCD2345'), throwsA(isA<LoiNha>()));
        tre.loi = null; // lượt làm mới không được ném lại cùng lỗi
        await _nghi();
        await _nghi();
        expect(tre.goi, ['chapNhanLoiMoi:ABCD2345', 'dsLoiMoiToi'], reason: ma);
      }
      tre.goi.clear();
      tre.loi = loiServer(400, 'HOUSEHOLD_INVITE_EXPIRED');
      await expectLater(r.tuChoiLoiMoi('ABCD2345'), throwsA(isA<LoiNha>()));
      tre.loi = null;
      await _nghi();
      expect(tre.goi, ['tuChoiLoiMoi:ABCD2345', 'dsLoiMoiToi']);
    });
  });
}

/// Chỉ giữ `cuaToi`; thân trả về là ẢNH CHỤP lúc gửi (server xử lý yêu cầu trước thao tác khác).
class ApiTreoCuaToi extends HouseholdApiGia {
  Completer<void>? treoCuaToi;

  @override
  Future<Map<String, Object?>> cuaToi() async {
    goi.add('cuaToi');
    final anhChup = cuaToiJson;
    final t = treoCuaToi;
    if (t != null) await t.future;
    return anhChup;
  }
}

/// Chỉ giữ `dsLoiMoiToi`; thân trả về là ẢNH CHỤP lúc gửi (bản đối xứng của [ApiTreoCuaToi]).
class ApiTreoLoiMoi extends HouseholdApiGia {
  Completer<void>? treoLoiMoi;

  @override
  Future<List<Map<String, Object?>>> dsLoiMoiToi() async {
    goi.add('dsLoiMoiToi');
    final anhChup = dsLoiMoiToiJson;
    final t = treoLoiMoi;
    if (t != null) await t.future;
    return anhChup;
  }
}

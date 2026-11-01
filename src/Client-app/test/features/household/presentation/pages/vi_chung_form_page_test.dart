import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/presentation/pages/vi_chung_form_page.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/domain/rang_buoc_vi.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/o_so_du_vi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/du_lieu_nha_gia.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/goi_gia.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  setUpAll(napFontThat);
  late BatThongBao bat;
  late DuLieuNhaGia nguon;
  late DieuChinhGia dieuChinh;
  late HouseholdApiGia api;
  late NhaRepositoryImpl repoNha;

  /// Mở form trong stack thật `/` → `/dich` để ca canh `pop` về trang trước. `vai`/`status` là của NHÀ lúc mở.
  Future<void> mo(
    WidgetTester t, {
    String? idVi,
    List<WalletEntity>? vi,
    String vai = 'Owner',
    String status = 'Active',
    int? phien = 18,
    bool banPhim = false,
    Map<String, bool>? quyen,
  }) async {
    dat360(t, banPhim: banPhim);
    bat = batThongBao();
    nguon = DuLieuNhaGia(vi: vi ?? const []);
    dieuChinh = DieuChinhGia();
    api = HouseholdApiGia()..cuaToiJson = nhaJson(myRole: vai, status: status);
    repoNha = await repoNhaThu(api);
    final r = routerThu(ViChungFormPage(idVi: idVi, duLieu: nguon, dieuChinh: dieuChinh, nha: repoNha));
    await t.pumpWidget(bocRouterNha(r, idaccount: phien, goi: quyen == null ? null : goiBasic(quyen)));
    r.push('/dich');
    await t.pumpAndSettle();
  }

  Finder oTen() => find.byKey(const Key('o-ten-vi-chung'));
  Finder oSoDu() => find.descendant(of: find.byType(OSoDuVi), matching: find.byType(TextField));
  Future<void> bam(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Tạo: tiêu đề, ba nhãn, hai nút Lưu + Tạo ví chung; không công tắc Mặc định / Tính vào tổng / Cho phép âm', (t) async {
    await mo(t);
    expect(find.text('Tạo ví chung'), findsNWidgets(2), reason: 'tiêu đề + nút cuối màn (giữ cả hai như ví cá nhân)');
    expect(find.text('Lưu'), findsOneWidget);
    for (final s in ['SỐ DƯ BAN ĐẦU', 'TÊN VÍ CHUNG', 'LOẠI VÍ', 'CHỌN BIỂU TƯỢNG', 'MÀU SẮC CHỦ ĐẠO']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('Ví chung thuộc về cả nhà. Mọi thành viên thấy số dư và các khoản trong ví.'), findsOneWidget);
    expect(find.byType(Switch), findsNothing, reason: 'ví nhà không mặc định, không tính vào tổng cá nhân, không cho âm');
    expect(find.textContaining('mặc định'), findsNothing);
    expect(find.byType(OSoDuVi), findsOneWidget, reason: 'ô số dư thật, không phải chữ như Stitch');
    expect(t.takeException(), isNull);
  });

  testWidgets('Tạo: gõ đủ rồi bấm nút cuối → taoViChung đúng tham số, idaccount từ phiên, rồi pop', (t) async {
    await mo(t);
    await t.enterText(oTen(), '  Tiền chợ ');
    await t.enterText(oSoDu(), '3200000');
    await bam(t, find.byKey(const Key('loai-bank')));
    await bam(t, find.byKey(const Key('icon-home')));
    await bam(t, find.byKey(const Key('mau-#1967D2')));
    await bam(t, find.byKey(const Key('nut-tao-vi-chung')));
    expect(nguon.tao, hasLength(1));
    final l = nguon.tao.single;
    expect((l.idNha, l.idaccount, l.ten, l.loai, l.soDu, l.icon, l.mau), (12, 18, 'Tiền chợ', 'bank', 3200000.0, 'home', '#1967D2'));
    expect(find.text('GOC'), findsOneWidget, reason: 'pop về trang trước');
  });

  testWidgets('Tạo: mặc định Tiền mặt + biểu tượng payments + màu xanh lá', (t) async {
    await mo(t);
    await t.enterText(oTen(), 'Quỹ');
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    final l = nguon.tao.single;
    expect((l.loai, l.icon, l.mau, l.soDu), ('cash', 'payments', '#006E1C', 0.0));
  });

  testWidgets('Tạo: tên rỗng thì báo, không ghi', (t) async {
    await mo(t);
    await bam(t, find.byKey(const Key('nut-tao-vi-chung')));
    expect(bat.cau, ['Vui lòng nhập tên ví chung']);
    expect(nguon.tao, isEmpty);
  });

  testWidgets('Tạo: trùng tên (kể cả ví đã lưu trữ) báo thongBaoTrungTen trước khi ghi', (t) async {
    await mo(t, vi: [viChungGia('a', 'Tiền chợ', 0, status: 'inactive')]);
    await t.enterText(oTen(), 'tiền   CHỢ');
    await bam(t, find.byKey(const Key('nut-tao-vi-chung')));
    expect(bat.cau, [thongBaoTrungTen('tiền   CHỢ')], reason: 'ví lưu trữ vẫn giữ tên trên server');
    expect(nguon.tao, isEmpty);
  });

  testWidgets('Tạo: không có phiên thì báo lỗi, không ghi (quy tắc 2: không `?? 1`)', (t) async {
    await mo(t, phien: null);
    await t.enterText(oTen(), 'Quỹ');
    await bam(t, find.byKey(const Key('nut-tao-vi-chung')));
    expect(nguon.tao, isEmpty);
    expect(bat.ds, hasLength(1), reason: 'người dùng phải biết vì sao không lưu');
  });

  testWidgets('Tạo: server/kho ném CacheException → báo câu đã bóc tiền tố, ở lại form', (t) async {
    await mo(t);
    nguon.loiTao = const CacheException('Không ghi được ví.');
    await t.enterText(oTen(), 'Quỹ');
    await bam(t, find.byKey(const Key('nut-tao-vi-chung')));
    expect(bat.cau, ['Không ghi được ví.']);
    expect(find.text('GOC'), findsNothing);
  });

  for (final c in [
    (vai: 'Member', status: 'Active', ten: 'Thành viên'),
    (vai: 'Viewer', status: 'Active', ten: 'Chỉ xem'),
    (vai: 'Owner', status: 'ReadOnly', ten: 'nhà chỉ xem'),
  ]) {
    testWidgets('deeplink vai sai lúc mở (${c.ten}): form tự pop kèm câu cauLoiNha(khongPhaiChu)', (t) async {
      await mo(t, vai: c.vai, status: c.status);
      expect(find.text('GOC'), findsOneWidget, reason: 'không được ở lại một form không lưu được');
      expect(bat.cau, [cauLoiNha(LoaiLoiNha.khongPhaiChu)]);
      expect(nguon.tao, isEmpty);
    });
  }

  testWidgets('vai đổi SAU khi form đã mở (Tạo): bấm Lưu không ghi gì, tự thoát kèm câu', (t) async {
    await mo(t);
    await t.enterText(oTen(), 'Quỹ');
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repoNha.lamMoi();
    await bam(t, find.byKey(const Key('nut-tao-vi-chung')));
    expect(nguon.tao, isEmpty, reason: 'người đã mất vai không được tạo ví (server từ chối, ví biến mất sau khi báo thành công)');
    expect(bat.cau, [cauLoiNha(LoaiLoiNha.khongPhaiChu)]);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('nhà đổi id SAU khi form đã mở: bấm Lưu không ghi vào nhà mới', (t) async {
    await mo(t);
    await t.enterText(oTen(), 'Quỹ');
    api.cuaToiJson = nhaJson(id: 13);
    await repoNha.lamMoi();
    await bam(t, find.byKey(const Key('nut-tao-vi-chung')));
    expect(nguon.tao, isEmpty);
    expect(find.text('GOC'), findsOneWidget);
  });

  final tienCho = viChungGia('a', 'Tiền chợ', 3200000);
  final dienNuoc = viChungGia('b', 'Điện nước', 1250000, loai: 'bank');

  testWidgets('Sửa: dựng theo màn 9 — SỐ DƯ HIỆN TẠI, tên, loại, công tắc lưu trữ, nút Xoá; không nút Tạo', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho, dienNuoc]);
    expect(find.text('Sửa ví chung'), findsOneWidget);
    expect(find.text('SỐ DƯ HIỆN TẠI'), findsOneWidget);
    expect(find.text('Sửa số dư sẽ tạo một khoản điều chỉnh trong ví'), findsOneWidget);
    expect(t.widget<TextField>(oTen()).controller!.text, 'Tiền chợ');
    expect(t.widget<TextField>(oSoDu()).controller!.text, '3.200.000');
    expect(find.text('Lưu trữ ví chung'), findsOneWidget);
    expect(find.text('Ẩn khỏi lựa chọn khi ghi khoản. Lịch sử vẫn còn.'), findsOneWidget);
    expect(find.text('Xoá ví chung'), findsOneWidget);
    expect(find.text('Ví còn giao dịch thì chỉ lưu trữ được, không xoá được.'), findsOneWidget);
    expect(find.byKey(const Key('nut-tao-vi-chung')), findsNothing);
    expect(t.widget<Switch>(find.byKey(const Key('cong-tac-luu-tru'))).value, isFalse);
    expect(find.text('Mặc định'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Sửa: đổi tên → suaViChung giữ id và nhà; không đối soát, không lưu trữ khi không đổi', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho, dienNuoc]);
    await t.enterText(oTen(), 'Chợ tuần');
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(nguon.sua, hasLength(1));
    expect((nguon.sua.single.id, nguon.sua.single.name, nguon.sua.single.idhousehold), ('a', 'Chợ tuần', 12));
    expect(dieuChinh.goi, isEmpty, reason: 'mỗi lần gọi là một khoản trong sổ — số dư không đổi thì không gọi');
    expect(nguon.luuTru, isEmpty);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('Sửa: đổi số dư → dieuChinh(nguoiGhi: phiên), không ghi đè balance của entity', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho]);
    await t.enterText(oSoDu(), '3000000');
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(dieuChinh.goi, [(walletId: 'a', soDu: 3000000.0, nguoiGhi: 18)]);
    expect(nguon.sua.single.balance, 3200000, reason: 'số dư chỉ đổi qua đường đối soát');
  });

  testWidgets('Sửa: giữ nguyên tên thì không tự trùng với chính nó', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho, dienNuoc]);
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(bat.ds, isEmpty);
    expect(nguon.sua, hasLength(1));
  });

  testWidgets('Sửa: tên trùng ví khác thì báo, không ghi', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho, dienNuoc]);
    await t.enterText(oTen(), 'điện nước');
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(bat.cau, [thongBaoTrungTen('điện nước')]);
    expect(nguon.sua, isEmpty);
  });

  testWidgets('Sửa: gạt công tắc lưu trữ → luuTruViChung(luuTru: true) sau khi lưu', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho]);
    await bam(t, find.byKey(const Key('cong-tac-luu-tru')));
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(nguon.luuTru, [(id: 'a', luuTru: true)]);
  });

  testWidgets('Sửa ví đã lưu trữ: công tắc bật sẵn; gạt tắt → bỏ lưu trữ', (t) async {
    await mo(t, idVi: 'c', vi: [viChungGia('c', 'Cũ', 0, status: 'inactive')]);
    expect(t.widget<Switch>(find.byKey(const Key('cong-tac-luu-tru'))).value, isTrue);
    await bam(t, find.byKey(const Key('cong-tac-luu-tru')));
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(nguon.luuTru, [(id: 'c', luuTru: false)]);
  });

  testWidgets('Sửa: khoá icon / màu lạ của ví giữ nguyên khi không chọn lại', (t) async {
    await mo(t, idVi: 'a', vi: [viChungGia('a', 'Tiền chợ', 0, icon: 'wallet', mau: '#4CAF50')]);
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect((nguon.sua.single.icon, nguon.sua.single.colour), ('wallet', '#4CAF50'),
        reason: 'ví cũ mang khoá ngoài sáu ô: lưu lại không được đổi im lặng sang ô đầu');
  });

  testWidgets('Sửa: ví không còn (xoá ở máy khác) thì báo và pop, không form rỗng', (t) async {
    await mo(t, idVi: 'khong-co', vi: [tienCho]);
    expect(find.text('GOC'), findsOneWidget);
    expect(bat.cau, ['Không tìm thấy ví chung này.']);
  });

  testWidgets('vai đổi SAU khi form Sửa đã mở: Lưu không ghi (kể cả khoản bù số dư), xoá không gọi', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho]);
    await t.enterText(oSoDu(), '1');
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repoNha.lamMoi();
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(nguon.sua, isEmpty);
    expect(dieuChinh.goi, isEmpty, reason: 'khoản bù của người đã mất vai lọt vào quỹ của cả nhà');
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('vai đổi SAU khi mở: bấm Xoá và đồng ý không gọi xoaViChung', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho]);
    await bam(t, find.byKey(const Key('nut-xoa-vi-chung')));
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repoNha.lamMoi();
    await bam(t, find.byKey(const Key('xac-nhan-xoa-vi-chung')));
    expect(nguon.xoa, isEmpty);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('Sửa: xoá trắng ô số dư là KHÔNG đổi, không đưa quỹ về 0', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho]);
    await t.enterText(oSoDu(), '');
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(dieuChinh.goi, isEmpty, reason: 'chuỗi rỗng parse về 0.0 sẽ sinh khoản bù đưa quỹ về 0, tác động cả nhà');
    expect(nguon.sua, hasLength(1), reason: 'phần còn lại của form vẫn lưu');
  });

  testWidgets('Sửa ví đã lưu trữ: ô số dư chỉ đọc, Lưu không ném giữa chừng', (t) async {
    await mo(t, idVi: 'c', vi: [viChungGia('c', 'Cũ', 500, status: 'inactive')]);
    expect(t.widget<TextField>(oSoDu()).readOnly, isTrue, reason: 'đối soát từ chối ví lưu trữ: lưu dở nếu cho gõ');
    await t.enterText(oTen(), 'Cũ đổi tên');
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(dieuChinh.goi, isEmpty);
    expect(nguon.sua.single.name, 'Cũ đổi tên');
    expect(bat.ds, isEmpty);
  });

  testWidgets('Sửa: bảng quyền tắt đối soát số dư — ô chỉ đọc kèm dòng khoá, Lưu không sinh khoản bù', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho], quyen: const {'wallet_balance_adjustment': false});
    expect(find.byKey(const Key('dong-khoa-wallet_balance_adjustment')), findsOneWidget);
    expect(t.widget<TextField>(oSoDu()).readOnly, isTrue);
    await bam(t, find.byKey(const Key('nut-luu-vi-chung')));
    expect(dieuChinh.goi, isEmpty);
  });

  testWidgets('Sửa: có quyền thì ô số dư gõ được, không dòng khoá', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho], quyen: const {});
    expect(find.byKey(const Key('dong-khoa-wallet_balance_adjustment')), findsNothing);
    expect(t.widget<TextField>(oSoDu()).readOnly, isFalse);
  });

  testWidgets('Xoá: hỏi lại, đồng ý thì xoaViChung rồi pop; Huỷ thì không xoá', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho]);
    await bam(t, find.byKey(const Key('nut-xoa-vi-chung')));
    await bam(t, find.widgetWithText(OutlinedButton, 'Huỷ'));
    expect(nguon.xoa, isEmpty);
    await bam(t, find.byKey(const Key('nut-xoa-vi-chung')));
    await bam(t, find.byKey(const Key('xac-nhan-xoa-vi-chung')));
    expect(nguon.xoa, ['a']);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('Xoá ví còn tiền: câu CacheException đã bóc tiền tố, ở lại form', (t) async {
    await mo(t, idVi: 'a', vi: [tienCho]);
    nguon.loiXoa = const CacheException('Ví "Tiền chợ" đã có giao dịch. Hãy lưu trữ để cất khỏi bộ chọn mà vẫn giữ lịch sử.');
    await bam(t, find.byKey(const Key('nut-xoa-vi-chung')));
    await bam(t, find.byKey(const Key('xac-nhan-xoa-vi-chung')));
    expect(bat.cau, ['Ví "Tiền chợ" đã có giao dịch. Hãy lưu trữ để cất khỏi bộ chọn mà vẫn giữ lịch sử.']);
    expect(find.text('Sửa ví chung'), findsOneWidget);
  });

  testWidgets('360 dp, số dư 13 chữ số, bàn phím mở: không tràn (Tạo và Sửa)', (t) async {
    await mo(t, banPhim: true);
    await t.enterText(oSoDu(), '9999999999999');
    await t.pump();
    expect(t.takeException(), isNull);
    await mo(t, idVi: 'a', vi: [viChungGia('a', 'Tên ví chung rất dài ${'x' * 60}', 9999999999999)], banPhim: true);
    expect(t.takeException(), isNull);
  });
}

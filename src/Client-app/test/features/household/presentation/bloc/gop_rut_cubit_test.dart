// Cubit màn Góp vào quỹ / Rút về ví riêng (đợt 1B, Task 8).
import 'dart:async';

import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/household/presentation/bloc/gop_rut_cubit.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/du_lieu_nha_gia.dart';
import '../../../../helpers/gop_quy_gia.dart';

final _bay = DateTime(2026, 11, 2, 10);

WalletEntity _rieng(String id, String ten, double soDu, {String loai = 'bank', bool macDinh = false}) => WalletEntity(
      id: id,
      idaccount: 18,
      name: ten,
      type: loai,
      balance: soDu,
      isDefault: macDinh,
      updatedAt: DateTime(2026, 11, 1),
    );

TransactionEntity _nuaNha({String type = 'thu', String vi = 'v1', double tien = 2000000, String note = 'tiền chợ', int ai = 18}) =>
    TransactionEntity(
      id: 'n',
      walletId: vi,
      idaccount: ai,
      idhousehold: 12,
      fundPairId: 'p',
      amount: tien,
      type: type,
      note: note,
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

TransactionEntity _nuaRieng({String type = 'chi', String vi = 'r1'}) => TransactionEntity(
      id: 'r',
      walletId: vi,
      idaccount: 18,
      fundPairId: 'p',
      amount: 2000000,
      type: type,
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  late DuLieuNhaGia nguon;
  late GopQuyGia gq;
  late List<WalletEntity> riengs;

  GopRutCubit dung({
    CheDoQuy cheDo = CheDoQuy.gop,
    String? viChungId,
    String? maCap,
    int? Function()? taiKhoan,
  }) =>
      GopRutCubit(
        gopQuy: gq,
        duLieu: nguon,
        napViRieng: () async => riengs,
        idNha: 12,
        taiKhoan: taiKhoan ?? () => 18,
        cheDo: cheDo,
        viChungId: viChungId,
        maCap: maCap,
        bayGio: () => _bay,
      );

  setUp(() {
    nguon = DuLieuNhaGia(vi: [
      viChungGia('v1', 'Tiền chợ', 3200000),
      viChungGia('v2', 'Điện nước', 1250000),
      viChungGia('v3', 'Quỹ cũ', 100, status: 'inactive'),
    ]);
    gq = GopQuyGia();
    riengs = [_rieng('r1', 'Ví MB', 5420000), _rieng('r2', 'Ví mặc định', 100000, loai: 'cash', macDinh: true)];
  });

  test('mở góp: ví chung theo query, ví riêng mặc định thắng ví đầu', () async {
    final c = dung(viChungId: 'v2');
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.daNap, isTrue);
    expect(c.state.chonChung?.id, 'v2', reason: 'ví chung theo `?vi=`');
    expect(c.state.chonRieng?.id, 'r2', reason: 'isDefault thắng ví đứng đầu danh sách');
    expect(c.state.viChung.map((v) => v.id), ['v2', 'v1'], reason: 'ví lưu trữ không vào bộ chọn');
    expect(c.state.hienBanPhimSo, isTrue);
    expect(c.state.dangSua, isFalse);
    expect(c.state.ngay, _bay);
  });

  test('không có query ví: ví chung đầu danh sách; không ví mặc định thì ví riêng đầu', () async {
    riengs = [_rieng('r1', 'Ví MB', 5420000)];
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.chonChung?.id, 'v1');
    expect(c.state.chonRieng?.id, 'r1');
  });

  test('lưu góp từ ví riêng ghi đủ tham số, idaccount từ phiên', () async {
    final c = dung(viChungId: 'v1');
    addTearDown(c.close);
    await c.moTrang();
    for (final k in ['5', '0', '000']) {
      c.goPhim(k);
    }
    c.ghiChuDoi('Tiền chợ tháng 11');
    c.chonRieng(riengs[0]);
    final kq = await c.luu();
    expect(kq, isNull);
    expect(gq.gop_, hasLength(1));
    final g = gq.gop_.single;
    expect((g.idNha, g.idaccount, g.viChungId, g.tenViChung), (12, 18, 'v1', 'Tiền chợ'));
    expect((g.soTien, g.viRiengId, g.ghiChu), (50000, 'r1', 'Tiền chợ tháng 11'));
    expect(g.ngay, _bay);
    expect(c.state.dangLuu, isFalse, reason: 'xong thì mở khoá nút');
  });

  test('tiền mặt trao tay: viRiengId null', () async {
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('7');
    c.datTienMat(true);
    expect(c.state.tienMat, isTrue);
    expect(await c.luu(), isNull);
    expect(gq.gop_.single.viRiengId, isNull, reason: 'chỉ nửa của nhà, không trừ ví riêng nào');
  });

  test('rút ghi đủ tham số vào ví riêng', () async {
    final c = dung(cheDo: CheDoQuy.rut, viChungId: 'v1');
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('5');
    c.goPhim('000');
    c.chonRieng(riengs[0]);
    expect(await c.luu(), isNull);
    expect(gq.gop_, isEmpty);
    final r = gq.rut_.single;
    expect((r.viChungId, r.viRiengId, r.soTien, r.idaccount), ('v1', 'r1', 5000, 18));
  });

  test('rút không có tiền mặt, thiếu ví riêng thì báo câu và không ghi', () async {
    riengs = [];
    final c = dung(cheDo: CheDoQuy.rut);
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('5');
    expect(await c.luu(), 'Vui lòng chọn ví riêng.');
    expect(gq.rut_, isEmpty);
    c.datTienMat(true);
    expect(c.state.tienMat, isFalse, reason: 'rút không có tiền mặt trao tay');
  });

  test('góp thiếu ví riêng (không bật tiền mặt) cũng báo câu', () async {
    riengs = [];
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('5');
    expect(await c.luu(), 'Vui lòng chọn ví riêng.');
    expect(gq.gop_, isEmpty);
  });

  test('không phiên: không ghi, trả câu đăng nhập lại', () async {
    final c = dung(taiKhoan: () => null);
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('5');
    expect(await c.luu(), 'Không xác định được tài khoản. Hãy đăng nhập lại.');
    expect(gq.gop_, isEmpty, reason: 'quy tắc 2: không phiên thì không ghi, không rơi về tài khoản 1');
  });

  test('số 0 và biểu thức ra 0: báo câu, không gọi dịch vụ', () async {
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    expect(await c.luu(), 'Vui lòng nhập số tiền lớn hơn 0.');
    for (final k in ['5', '-', '5']) {
      c.goPhim(k);
    }
    expect(c.state.chuoiSoTien, '5-5');
    expect(await c.luu(), 'Vui lòng nhập số tiền lớn hơn 0.');
    expect(gq.gop_, isEmpty);
  });

  test('biểu thức được rút gọn khi lưu', () async {
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    for (final k in ['1', '0', '0', '+', '5', '0']) {
      c.goPhim(k);
    }
    expect(await c.luu(), isNull);
    expect(gq.gop_.single.soTien, 150);
  });

  test('CacheException của dịch vụ thành câu hiện được, không kèm chữ CacheException', () async {
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('5');
    gq.loi = const CacheException('Ví chung không thuộc nhà đang chọn.');
    final kq = await c.luu();
    expect(kq, 'Ví chung không thuộc nhà đang chọn.');
    expect(kq, isNot(contains('CacheException')));
    expect(c.state.dangLuu, isFalse, reason: 'lỗi cũng mở khoá nút để thử lại');
  });

  test('lỗi khác thành câu chung', () async {
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('5');
    gq.loi = StateError('hỏng nội bộ');
    final kq = await c.luu();
    expect(kq, 'Không ghi được khoản. Thử lại sau.');
    expect(kq, isNot(contains('hỏng nội bộ')), reason: 'không lộ chuỗi kỹ thuật');
  });

  test('sửa: nạp cặp, khoá ví, chiều theo nửa nhà (thu ⇒ góp), gọi sua', () async {
    gq
      ..nha = _nuaNha()
      ..rieng = _nuaRieng();
    final c = dung(cheDo: CheDoQuy.rut, maCap: 'p');
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.dangSua, isTrue);
    expect(c.state.cheDo, CheDoQuy.gop, reason: 'chiều lấy theo nửa nhà, không theo query');
    expect(c.state.tienMat, isFalse);
    expect(c.state.chonChung?.id, 'v1');
    expect(c.state.chonRieng?.id, 'r1');
    expect(c.state.chuoiSoTien, '2000000');
    expect(c.state.ghiChu, 'tiền chợ');
    expect(c.state.ngay, DateTime(2026, 11, 1));
    expect(c.state.hienBanPhimSo, isFalse, reason: 'đã có số tiền thì 16 phím ẩn, chạm khối số để mở');
    c.goPhim('backspace');
    c.chonChung(viChungGia('v2', 'Điện nước', 1)); // ví bị khoá khi sửa
    expect(c.state.chonChung?.id, 'v1', reason: 'sửa thì không đổi ví');
    c.chonNgay(DateTime(2026, 11, 2));
    c.ghiChuDoi('mới');
    expect(await c.luu(), isNull);
    expect(gq.sua_.single, (maCap: 'p', soTien: 200000, ngay: DateTime(2026, 11, 2), ghiChu: 'mới'));
    expect(gq.gop_, isEmpty);
    expect(gq.rut_, isEmpty);
  });

  test('sửa khoản rút: chi ⇒ rút; tiền mặt khi máy không có nửa riêng', () async {
    gq
      ..nha = _nuaNha(type: 'chi')
      ..rieng = null;
    final c = dung(maCap: 'p');
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.cheDo, CheDoQuy.rut);
    expect(c.state.tienMat, isTrue, reason: 'không còn nửa riêng trên máy này');
  });

  test('sửa khoản cặp của NGƯỜI KHÁC (Chủ mở deeplink): đóng kèm câu, không ghi gì', () async {
    gq.nha = _nuaNha(ai: 25); // nửa riêng nằm trên máy người ghi, máy này chỉ có nửa nhà
    final c = dung(maCap: 'p'); // phiên = 18
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.cauDong, 'Chỉ người ghi mới sửa được khoản này.');
    expect(c.state.daNap, isTrue);
    expect(await c.luu(), 'Chỉ người ghi mới sửa được khoản này.');
    expect(gq.sua_, isEmpty, reason: 'GopQuyService.sua không kiểm quyền; server sẽ trả HOUSEHOLD_ROLE_FORBIDDEN sau khi nửa nhà đã đổi');
  });

  test('sửa mã không còn lúc mở: đóng kèm câu', () async {
    final c = dung(maCap: 'p'); // docCap trả hai nửa rỗng
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.daNap, isTrue);
    expect(c.state.cauDong, 'Khoản này không còn.');
    expect(await c.luu(), 'Khoản này không còn.', reason: 'có bấm lưu cũng không ghi gì');
    expect(gq.sua_, isEmpty);
  });

  test('sửa mà mã không còn lúc lưu (sua trả false): trả câu Khoản này không còn', () async {
    gq
      ..nha = _nuaNha()
      ..suaTra = false;
    final c = dung(maCap: 'p');
    addTearDown(c.close);
    await c.moTrang();
    expect(await c.luu(), 'Khoản này không còn.');
    expect(gq.sua_, hasLength(1));
  });

  test('ví lưu trữ đang sửa vẫn nhận được (giuLai)', () async {
    gq.nha = _nuaNha(vi: 'v3');
    final c = dung(maCap: 'p');
    addTearDown(c.close);
    await c.moTrang();
    expect(nguon.goiChoForm.last.$2, contains('v3'), reason: 'bộ chọn phải giữ ví lưu trữ của khoản đang sửa');
    expect(c.state.chonChung?.id, 'v3');
  });

  test('ví riêng bỏ banking', () async {
    riengs = [_rieng('b', 'Ví liên kết', 9, loai: 'banking'), _rieng('r1', 'Ví MB', 5)];
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.viRieng.map((v) => v.id), ['r1']);
    expect(c.state.chonRieng?.id, 'r1');
  });

  test('chạm đôi không ghi hai lần', () async {
    gq.cho = Completer<void>();
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('5');
    final a = c.luu();
    await pumpEventQueue();
    expect(c.state.dangLuu, isTrue);
    final b = await c.luu();
    expect(b, isNotNull, reason: 'lượt thứ hai bị từ chối, không phải "đã lưu"');
    gq.cho!.complete();
    expect(await a, isNull);
    expect(gq.gop_, hasLength(1), reason: 'dịch vụ chỉ được gọi một lần');
  });

  test('nạp hỏng thì đóng kèm câu, không rơi vào trang trống', () async {
    nguon.loiChoForm = StateError('hỏng');
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    expect(c.state.daNap, isTrue);
    expect(c.state.cauDong, 'Không đọc được dữ liệu. Thử lại sau.');
  });

  test('chạm khối số tiền đảo 16 phím; bàn phím hệ thống đang mở thì luôn mở 16 phím', () async {
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    c.chamSoTien(banPhimHeThongMo: false);
    expect(c.state.hienBanPhimSo, isFalse);
    c.chamSoTien(banPhimHeThongMo: false);
    expect(c.state.hienBanPhimSo, isTrue);
    c.chamSoTien(banPhimHeThongMo: true);
    c.chamSoTien(banPhimHeThongMo: true);
    expect(c.state.hienBanPhimSo, isTrue, reason: 'luật G58: đảo cờ lúc bàn phím hệ thống mở là tắt phím mà không thấy gì đổi');
  });

  test('gõ quá 13 chữ số bị chặn', () async {
    final c = dung();
    addTearDown(c.close);
    await c.moTrang();
    c.goPhim('9');
    for (var i = 0; i < 6; i++) {
      c.goPhim('000');
    }
    expect(c.state.chuoiSoTien, '9${'0' * 12}', reason: 'trần 13 chữ số của numeric(15,2): cụm 000 cắt bớt cho vừa');
  });
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/presentation/bloc/tham_gia_nha_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  khoiVong1();
  Future<(ThamGiaNhaCubit, HouseholdApiGia, List<String>)> dung() async {
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    final c = ThamGiaNhaCubit(repo);
    addTearDown(c.close);
    final bao = <String>[];
    c.canBao.listen(bao.add);
    return (c, api, bao);
  }

  test('mã sai dạng: không tốn lượt server (giới hạn tần suất 30 / 15 phút)', () async {
    final (c, api, _) = await dung();
    c.doiMa('ABC');
    await c.xem();
    expect(api.goi.where((g) => g.startsWith('xemTruoc')), isEmpty);
  });

  test('xem trước đúng mã rồi tham gia', () async {
    final (c, api, _) = await dung();
    c.doiMa('abcd 2345');
    await c.xem();
    expect(api.goi, contains('xemTruoc:ABCD2345'));
    expect(c.state.xemTruoc!.tenNha, 'Nhà An – Bình');
    api.traVe = nhaJson();
    expect(await c.thamGia(), isTrue);
    expect(api.goi, contains('thamGia:ABCD2345'));
  });

  test('đổi mã sau khi xem trước: bỏ bản xem trước (đừng để Tham gia trỏ mã khác với thẻ đang hiện)', () async {
    final (c, _, _) = await dung();
    c.doiMa('ABCD2345');
    await c.xem();
    c.doiMa('ABCD2346');
    expect(c.state.xemTruoc, isNull);
  });

  test('chưa xem trước: thamGia không gọi API', () async {
    final (c, api, _) = await dung();
    c.doiMa('ABCD2345');
    expect(await c.thamGia(), isFalse);
    expect(api.goi.where((g) => g.startsWith('thamGia')), isEmpty);
  });

  test('tham gia hỏng: báo đúng câu, giữ bản xem trước để thử lại', () async {
    final (c, api, bao) = await dung();
    c.doiMa('ABCD2345');
    await c.xem();
    api.loi = loiServer(409, 'HOUSEHOLD_FULL');
    expect(await c.thamGia(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(bao, [cauLoiNha(LoaiLoiNha.nhaDu)]);
    expect(c.state.xemTruoc, isNotNull);
    expect(c.state.dangThamGia, isFalse);
  });

  test('mọi mã lỗi ra đúng câu', () async {
    const bang = {
      'HOUSEHOLD_INVITE_INVALID': LoaiLoiNha.maKhongCo,
      'HOUSEHOLD_INVITE_EXPIRED': LoaiLoiNha.maHetHan,
      'HOUSEHOLD_INVITE_USED': LoaiLoiNha.maDaDung,
      'HOUSEHOLD_INVITE_DECLINED': LoaiLoiNha.loiMoiDaTuChoi,
      'HOUSEHOLD_INVITE_WRONG_ACCOUNT': LoaiLoiNha.loiMoiKhongPhaiCuaBan,
      'HOUSEHOLD_INVITE_ATTEMPT_LIMIT': LoaiLoiNha.thuMaQuaNhieu,
      'HOUSEHOLD_READ_ONLY': LoaiLoiNha.nhaChiXem,
      'HOUSEHOLD_FULL': LoaiLoiNha.nhaDu,
      'HOUSEHOLD_ALREADY_IN_ONE': LoaiLoiNha.daONhaKhac,
      'FEATURE_DISABLED': LoaiLoiNha.tinhNangKhongMo,
    };
    for (final e in bang.entries) {
      final (c, api, bao) = await dung();
      c.doiMa('ABCD2345');
      api.loi = loiServer(409, e.key);
      await c.xem();
      await Future<void>.delayed(Duration.zero);
      expect(bao, [cauLoiNha(e.value)], reason: e.key);
    }
  });
}

void khoiVong1() {
  Future<(ThamGiaNhaCubit, HouseholdApiGia, List<String>)> dung() async {
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    final c = ThamGiaNhaCubit(repo);
    addTearDown(c.close);
    final bao = <String>[];
    c.canBao.listen(bao.add);
    return (c, api, bao);
  }

  test('đổi mã lúc đang tham gia: bỏ qua, không mất cờ, không POST thứ hai', () async {
    final (c, api, _) = await dung();
    c.doiMa('ABCD2345');
    await c.xem();
    final treo = Completer<void>();
    api.treo = treo;
    api.traVe = nhaJson();
    final f = c.thamGia();
    c.doiMa('ABCD2346');
    expect(c.state.ma, 'ABCD2345');
    expect(c.state.dangThamGia, isTrue);
    expect(c.state.xemTruoc, isNotNull);
    expect(await c.thamGia(), isFalse);
    treo.complete();
    expect(await f, isTrue);
    expect(api.goi.where((g) => g.startsWith('thamGia')), hasLength(1));
  });

  test('mã A hỏng muộn sau khi thẻ mã B đã hiện: không báo lỗi của A, không xoá thẻ B', () async {
    final (c, api, bao) = await dung();
    final treo = Completer<void>();
    api.treo = treo;
    c.doiMa('ABCD2345');
    final fa = c.xem();
    c.doiMa('ABCD2346');
    api.treo = null;
    await c.xem();
    expect(c.state.xemTruoc, isNotNull);
    api.loi = loiServer(409, 'HOUSEHOLD_INVITE_EXPIRED');
    treo.complete();
    await fa;
    await Future<void>.delayed(Duration.zero);
    expect(bao, isEmpty);
    expect(c.state.ma, 'ABCD2346');
    expect(c.state.xemTruoc, isNotNull);
  });

  test('mã đã chết: bỏ thẻ; lỗi thử lại được (mất mạng, máy chủ): giữ thẻ', () async {
    for (final ma in ['HOUSEHOLD_INVITE_EXPIRED', 'HOUSEHOLD_INVITE_USED', 'HOUSEHOLD_INVITE_INVALID', 'HOUSEHOLD_CLOSED']) {
      final (c, api, _) = await dung();
      c.doiMa('ABCD2345');
      await c.xem();
      expect(c.state.xemTruoc, isNotNull);
      api.loi = loiServer(410, ma);
      await c.xem();
      expect(c.state.xemTruoc, isNull, reason: ma);
    }
    final (c, api, _) = await dung();
    c.doiMa('ABCD2345');
    await c.xem();
    api.loi = DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
    await c.xem();
    expect(c.state.xemTruoc, isNotNull, reason: 'mất mạng');
    api.loi = loiServer(500, 'INTERNAL');
    await c.xem();
    expect(c.state.xemTruoc, isNotNull, reason: 'máy chủ');
  });

  test('HOUSEHOLD_CLOSED ra câu nhà đã giải tán', () async {
    final (c, api, bao) = await dung();
    c.doiMa('ABCD2345');
    api.loi = loiServer(409, 'HOUSEHOLD_CLOSED');
    await c.xem();
    await Future<void>.delayed(Duration.zero);
    expect(bao, [cauLoiNha(LoaiLoiNha.nhaDaGiaiTan)]);
  });
}

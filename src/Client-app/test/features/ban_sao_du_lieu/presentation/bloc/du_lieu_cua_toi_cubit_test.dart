import 'dart:async';

import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/domain/loi_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/models/yeu_cau_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/domain/trang_thai_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/presentation/bloc/du_lieu_cua_toi_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/ban_sao_repo_gia.dart';

const _dangTao = YeuCauBanSao(id: 'p', trangThai: TrangThaiBanSao.dangTao, email: 'an***@gmail.com');
const _sanSang = YeuCauBanSao(id: 'r', trangThai: TrangThaiBanSao.sanSang, files: ['json', 'csv']);

void main() {
  late BanSaoRepoGia repo;
  late StreamController<RealtimeEvent> suKien;
  late DuLieuCuaToiCubit cubit;

  setUp(() {
    repo = BanSaoRepoGia();
    suKien = StreamController<RealtimeEvent>.broadcast();
    cubit = DuLieuCuaToiCubit(repo: repo, suKien: suKien.stream);
  });
  tearDown(() async {
    await cubit.close();
    await suKien.close();
  });

  test('nap: chưa yêu cầu → daNap, yeuCau null; đọc hỏng → khongDocDuoc', () async {
    await cubit.nap();
    expect(cubit.state.daNap, isTrue);
    expect(cubit.state.yeuCau, isNull);
    repo.loiDoc = const LoiBanSao(LoaiLoiBanSao.matMang);
    await cubit.nap();
    expect(cubit.state.khongDocDuoc, isTrue);
  });

  test('yeuCau 202 → đang tạo + câu có email', () async {
    await cubit.nap();
    repo.ketQuaYeuCau = _dangTao;
    final td = await cubit.yeuCau();
    expect(cubit.state.yeuCau!.trangThai, TrangThaiBanSao.dangTao);
    expect(td!.cau, 'Đã gửi tới email an***@gmail.com, tệp sẵn sàng sau ít phút');
    expect(td.loi, isFalse);
  });

  test('đang tạo → yeuCau KHÔNG gọi POST', () async {
    repo.moiNhat = _dangTao;
    await cubit.nap();
    expect(await cubit.yeuCau(), isNull);
    expect(repo.soLanYeuCau, 0);
  });

  test('bấm hai lần liền → một POST', () async {
    await cubit.nap();
    repo
      ..ketQuaYeuCau = _dangTao
      ..khoaYeuCau = Completer<void>();
    final a = cubit.yeuCau();
    final b = cubit.yeuCau();
    repo.khoaYeuCau!.complete();
    await Future.wait([a, b]);
    expect(repo.soLanYeuCau, 1);
  });

  test('429 → câu thời gian chờ (lỗi) + đọc lại; thiếu Retry-After → câu không số', () async {
    await cubit.nap();
    final docTruoc = repo.soLanDoc;
    repo.loiYeuCau = const LoiBanSao(LoaiLoiBanSao.daGioiHan, choThem: Duration(seconds: 18720));
    final td = await cubit.yeuCau();
    expect(td!.cau, 'Bạn có thể yêu cầu lại sau 5 giờ 12 phút');
    expect(td.loi, isTrue);
    expect(repo.soLanDoc, docTruoc + 1);
    repo.loiYeuCau = const LoiBanSao(LoaiLoiBanSao.daGioiHan);
    expect((await cubit.yeuCau())!.cau, 'Bạn đã yêu cầu trong 24 giờ qua');
    expect(cubit.state.dangGui, isFalse);
  });

  test('tai: sẵn sàng → gọi đúng id/định dạng, câu "Đã lưu …"; chia sẻ (null) → không câu', () async {
    repo.moiNhat = _sanSang;
    await cubit.nap();
    expect((await cubit.tai('csv'))!.cau, 'Đã lưu Tải về/tep');
    expect(repo.daTai.single, ('r', 'csv'));
    repo.noiLuu = null;
    expect(await cubit.tai('json'), isNull);
    expect(cubit.state.dangTai, isNull);
  });

  test('tai 410 → câu hết hạn + đọc lại', () async {
    repo.moiNhat = _sanSang;
    await cubit.nap();
    final docTruoc = repo.soLanDoc;
    repo.loiTai = const LoiBanSao(LoaiLoiBanSao.hetHan);
    final td = await cubit.tai('json');
    expect(td!.cau, 'Tệp đã hết hạn, hãy yêu cầu lại');
    expect(repo.soLanDoc, docTruoc + 1);
  });

  test('tai khi chưa sẵn sàng → không gọi', () async {
    repo.moiNhat = _dangTao;
    await cubit.nap();
    expect(await cubit.tai('json'), isNull);
    expect(repo.daTai, isEmpty);
  });

  test('sự kiện banSaoDuLieuSanSang → đọc lại; sự kiện khác → không', () async {
    await cubit.nap();
    final docTruoc = repo.soLanDoc;
    suKien.add(RealtimeEvent.dongBoXong);
    await Future<void>.delayed(Duration.zero);
    expect(repo.soLanDoc, docTruoc);
    repo.moiNhat = _sanSang;
    suKien.add(RealtimeEvent.banSaoDuLieuSanSang);
    await Future<void>.delayed(Duration.zero);
    expect(repo.soLanDoc, docTruoc + 1);
    expect(cubit.state.yeuCau!.trangThai, TrangThaiBanSao.sanSang);
  });
}

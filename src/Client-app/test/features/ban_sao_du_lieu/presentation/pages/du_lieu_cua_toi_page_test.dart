import 'dart:async';

import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/domain/loi_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/models/yeu_cau_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/domain/trang_thai_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/presentation/pages/du_lieu_cua_toi_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/ban_sao_repo_gia.dart';

void main() {
  late BanSaoRepoGia repo;
  late StreamController<RealtimeEvent> suKien;

  setUp(() {
    repo = BanSaoRepoGia();
    suKien = StreamController<RealtimeEvent>.broadcast();
  });
  tearDown(() => suKien.close());

  Future<void> dung(WidgetTester t, {Size kho = const Size(411, 914)}) async {
    t.view.physicalSize = kho;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DuLieuCuaToiPage(repo: repo, suKien: suKien.stream),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  testWidgets('chưa yêu cầu: câu không khôi phục + nút Nhận bản sao', (t) async {
    await dung(t);
    expect(find.textContaining('không dùng để khôi phục'), findsOneWidget);
    expect(find.byKey(const Key('nut-yeu-cau')), findsOneWidget);
    expect(find.text('Nhận bản sao dữ liệu của tôi'), findsOneWidget);
  });

  testWidgets('đang tạo: không có nút yêu cầu bấm được', (t) async {
    repo.moiNhat = const YeuCauBanSao(id: 'p', trangThai: TrangThaiBanSao.dangTao);
    await dung(t);
    expect(find.textContaining('Đang tạo'), findsOneWidget);
    expect(find.byKey(const Key('nut-yeu-cau')), findsNothing);
  });

  testWidgets('sẵn sàng: hai nút tải; chạm CSV → tải đúng định dạng', (t) async {
    repo.moiNhat = YeuCauBanSao(
        id: 'r', trangThai: TrangThaiBanSao.sanSang, files: const ['json', 'csv'], expiresAt: DateTime(2026, 11, 17, 10));
    await dung(t);
    expect(find.textContaining('Tải được tới 10:00 17/11'), findsOneWidget);
    expect(find.text('Tải dữ liệu (JSON)'), findsOneWidget);
    await t.tap(find.byKey(const Key('nut-tai-csv')));
    await t.pump(const Duration(milliseconds: 50));
    expect(repo.daTai.single, ('r', 'csv'));
  });

  testWidgets('hết hạn và lỗi: có nút yêu cầu lại', (t) async {
    repo.moiNhat = const YeuCauBanSao(id: 'e', trangThai: TrangThaiBanSao.hetHan);
    await dung(t);
    expect(find.textContaining('Tệp đã bị xoá'), findsOneWidget);
    expect(find.byKey(const Key('nut-yeu-cau')), findsOneWidget);
  });

  testWidgets('đọc hỏng: câu cần mạng + Thử lại nạp lại', (t) async {
    repo.loiDoc = const LoiBanSao(LoaiLoiBanSao.matMang);
    await dung(t);
    expect(find.textContaining('Cần kết nối mạng'), findsOneWidget);
    repo.loiDoc = null;
    await t.tap(find.byKey(const Key('nut-thu-lai')));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('nut-yeu-cau')), findsOneWidget);
  });

  testWidgets('sự kiện socket → trang chuyển sang sẵn sàng', (t) async {
    repo.moiNhat = const YeuCauBanSao(id: 'p', trangThai: TrangThaiBanSao.dangTao);
    await dung(t);
    repo.moiNhat = const YeuCauBanSao(id: 'p', trangThai: TrangThaiBanSao.sanSang, files: ['json', 'csv']);
    suKien.add(RealtimeEvent.banSaoDuLieuSanSang);
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('nut-tai-json')), findsOneWidget);
  });

  testWidgets('320 dp, sẵn sàng, mốc ngày dài nhất: không tràn', (t) async {
    repo.moiNhat = YeuCauBanSao(
        id: 'r', trangThai: TrangThaiBanSao.sanSang, files: const ['json', 'csv'], expiresAt: DateTime(2026, 12, 31, 23, 59));
    await dung(t, kho: const Size(320, 640));
    expect(t.takeException(), isNull);
  });

  testWidgets('320 dp, đang tạo: câu dài không tràn', (t) async {
    repo.moiNhat = const YeuCauBanSao(id: 'p', trangThai: TrangThaiBanSao.dangTao);
    await dung(t, kho: const Size(320, 640));
    expect(t.takeException(), isNull, reason: 'câu "Đang tạo…" phải nằm trong Expanded, không tràn hàng');
  });
}

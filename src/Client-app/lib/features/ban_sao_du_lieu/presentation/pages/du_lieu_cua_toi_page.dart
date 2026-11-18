import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/realtime/realtime_channel.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/repositories/ban_sao_du_lieu_repository.dart';
import '../../domain/trang_thai_ban_sao.dart';
import '../bloc/du_lieu_cua_toi_cubit.dart';

/// Cài đặt → "Dữ liệu của tôi" (đơn client-app mục 52, spec 2026-11-16).
/// Đọc lại khi app quay lại (người dùng vừa xem email) và khi có `account.data_export_ready`.
class DuLieuCuaToiPage extends StatefulWidget {
  const DuLieuCuaToiPage({super.key, this.repo, this.suKien});

  /// `null` → `sl<BanSaoDuLieuRepository>()`.
  final BanSaoDuLieuRepository? repo;

  /// `null` → `sl<RealtimeChannel>().events`.
  final Stream<RealtimeEvent>? suKien;

  @override
  State<DuLieuCuaToiPage> createState() => _DuLieuCuaToiPageState();
}

class _DuLieuCuaToiPageState extends State<DuLieuCuaToiPage> {
  late final DuLieuCuaToiCubit _cubit;
  late final AppLifecycleListener _vongDoi;

  @override
  void initState() {
    super.initState();
    _cubit = DuLieuCuaToiCubit(
      repo: widget.repo ?? sl<BanSaoDuLieuRepository>(),
      suKien: widget.suKien ?? sl<RealtimeChannel>().events,
    );
    _vongDoi = AppLifecycleListener(onResume: () => unawaited(_cubit.nap()));
    unawaited(_cubit.nap());
  }

  @override
  void dispose() {
    _vongDoi.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  void _bao(ThongDiep? td) {
    if (td == null || !mounted) return;
    baoNhanh(td.cau, loai: td.loi ? LoaiThongBao.loi : LoaiThongBao.xong);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Dữ liệu của tôi')),
        body: BlocBuilder<DuLieuCuaToiCubit, DuLieuCuaToiState>(
          builder: (context, s) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Bản sao gồm toàn bộ dữ liệu máy chủ đang giữ về bạn, ở hai dạng: tệp JSON và tệp CSV giao dịch '
                '(mở bằng Excel). Tệp tải được trong 24 giờ; mỗi 24 giờ bạn yêu cầu được một lần.\n\n'
                'Tệp này để bạn giữ hoặc xem, không dùng để khôi phục. Dữ liệu của bạn đã tự đồng bộ với máy chủ.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              _the(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _the(DuLieuCuaToiState s) {
    final List<Widget> noiDung;
    if (!s.daNap && s.dangNap) {
      noiDung = [const Center(child: CircularProgressIndicator())];
    } else if (s.khongDocDuoc && !s.daNap) {
      noiDung = [
        const Text('Cần kết nối mạng để xem bản sao dữ liệu'),
        const SizedBox(height: 12),
        OutlinedButton(
            key: const Key('nut-thu-lai'), onPressed: () => unawaited(_cubit.nap()), child: const Text('Thử lại')),
      ];
    } else {
      noiDung = _theoTrangThai(s);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: noiDung),
    );
  }

  List<Widget> _theoTrangThai(DuLieuCuaToiState s) {
    final y = s.yeuCau;
    final trangThai = y?.trangThai ?? TrangThaiBanSao.chuaYeuCau;
    Widget nutYeuCau(String chu) => FilledButton(
          key: const Key('nut-yeu-cau'),
          onPressed: s.dangGui ? null : () async => _bao(await _cubit.yeuCau()),
          child: Text(chu),
        );
    switch (trangThai) {
      case TrangThaiBanSao.chuaYeuCau:
        return [
          const Text('Bạn chưa yêu cầu bản sao nào.'),
          const SizedBox(height: 12),
          nutYeuCau('Nhận bản sao dữ liệu của tôi'),
        ];
      case TrangThaiBanSao.dangTao:
        return const [
          Row(children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Expanded(child: Text('Đang tạo, bạn sẽ nhận email khi xong')),
          ]),
        ];
      case TrangThaiBanSao.sanSang:
        final han = y!.expiresAt;
        return [
          const Row(children: [
            Icon(Icons.check_circle, color: AppColors.income, size: 22),
            SizedBox(width: 10),
            Expanded(child: Text('Bản sao đã sẵn sàng', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          if (han != null) ...[
            const SizedBox(height: 4),
            Text('Tải được tới ${DateFormatter.formatTimeDayMonth(han)}',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 16),
          if (y.files.contains('json'))
            FilledButton(
              key: const Key('nut-tai-json'),
              onPressed: s.dangTai != null ? null : () async => _bao(await _cubit.tai('json')),
              child: const Text('Tải dữ liệu (JSON)'),
            ),
          if (y.files.contains('csv')) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('nut-tai-csv'),
              onPressed: s.dangTai != null ? null : () async => _bao(await _cubit.tai('csv')),
              child: const Text('Tải giao dịch (CSV)'),
            ),
          ],
        ];
      case TrangThaiBanSao.hetHan:
        return [const Text('Tệp đã bị xoá sau 24 giờ.'), const SizedBox(height: 12), nutYeuCau('Yêu cầu bản sao mới')];
      case TrangThaiBanSao.loi:
        return [const Text('Tạo bản sao không thành công.'), const SizedBox(height: 12), nutYeuCau('Yêu cầu lại')];
    }
  }
}

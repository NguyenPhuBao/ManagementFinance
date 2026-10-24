import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/luat_khoa_app.dart';
import '../../bloc/khoa_app_cubit.dart';
import '../../bloc/khoa_app_state.dart';
import '../ban_phim_pin.dart';
import '../cham_pin.dart';
import 'tam_xac_nhan_quen_pin.dart';

/// `on-surface-variant` của Stitch — KHÔNG phải `AppColors.onSurfaceVariant` (`#767872`).
const _xamChu = Color(0xFF454743);

/// Màn khoá — Stitch `2f0896e011874b4e84c8217c4f56346e` *"Màn khoá ứng dụng (2 biến thể)"*.
class ManKhoa extends StatefulWidget {
  const ManKhoa({super.key, required this.trangThai, required this.khiQuenPin, required this.dongHo});

  final KhoaAppKhoa trangThai;
  final VoidCallback khiQuenPin;
  final DateTime Function() dongHo;

  @override
  State<ManKhoa> createState() => _ManKhoaState();
}

class _ManKhoaState extends State<ManKhoa> {
  String _nhap = '';
  bool _hoiQuen = false;
  Timer? _dem;

  @override
  void initState() {
    super.initState();
    _henDem();
    _tuMoVanTay();
  }

  @override
  void didUpdateWidget(ManKhoa cu) {
    super.didUpdateWidget(cu);
    if (cu.trangThai.choDen != widget.trangThai.choDen) _henDem();
    if (cu.trangThai.lanKhoa != widget.trangThai.lanKhoa) {
      _nhap = '';
      _hoiQuen = false;
      _tuMoVanTay();
    }
    // Một lượt kiểm vừa KẾT THÚC (sai, hay bị chặn vì đang chờ) → xoá chấm. Đếm bằng `lanKiem` chứ không nhìn khung
    // trung gian `dangKiem` (có thể không bao giờ được dựng) hay câu lỗi (lượt bị chặn không có câu) — P13.
    if (cu.trangThai.lanKiem != widget.trangThai.lanKiem) _nhap = '';
  }

  /// Bật vân tay thì hộp hệ thống tự hiện MỘT lần mỗi lần khoá (sau khung đầu — activity phải đang `resumed`).
  void _tuMoVanTay() {
    if (!widget.trangThai.coVanTay) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<KhoaAppCubit>().moBangVanTay();
    });
  }

  void _henDem() {
    _dem?.cancel();
    if (_conCho() == null) return;
    _dem = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (_conCho() == null) t.cancel();
    });
  }

  Duration? _conCho() {
    final cho = widget.trangThai.choDen;
    if (cho == null) return null;
    final con = cho.difference(widget.dongHo());
    return con.isNegative || con == Duration.zero ? null : con;
  }

  @override
  void dispose() {
    _dem?.cancel();
    super.dispose();
  }

  void _go(String so) {
    if (_nhap.length >= kDoDaiPin || widget.trangThai.dangKiem) return;
    setState(() => _nhap += so);
    if (_nhap.length == kDoDaiPin) {
      final pin = _nhap;
      context.read<KhoaAppCubit>().nhapPin(pin);
    }
  }

  void _xoa() {
    if (_nhap.isEmpty) return;
    setState(() => _nhap = _nhap.substring(0, _nhap.length - 1));
  }

  String _mmss(Duration d) {
    final giay = (d.inMilliseconds / 1000).ceil();
    return '${(giay ~/ 60).toString().padLeft(2, '0')}:${(giay % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.trangThai;
    final con = _conCho();
    final loi = s.loiNhan;
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Stack(
          children: [
            // Stitch `2f0896e0…`: cả cột căn giữa dọc; khổ thấp thì bàn phím co (BanPhimPin tự tính cạnh phím).
            Column(
              children: [
                const Spacer(),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.account_balance_wallet, color: AppColors.onPrimary, size: 32),
                ),
                const SizedBox(height: 24),
                const Text('Nhập mã PIN',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  con != null ? 'Sai mã PIN quá nhiều lần' : (loi ?? 'Mở khoá FlowMoney'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: con != null || loi != null ? FontWeight.w500 : FontWeight.w400,
                      color: con != null || loi != null ? AppColors.expense : _xamChu),
                ),
                const SizedBox(height: 32),
                ChamPin(soDaNhap: con != null ? 0 : _nhap.length),
                SizedBox(
                  height: 40,
                  child: con == null
                      ? null
                      : Center(
                          child: Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'Thử lại sau '),
                              TextSpan(
                                text: _mmss(con),
                                style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                              ),
                            ]),
                            style: const TextStyle(
                                fontSize: 14, color: _xamChu, fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ),
                ),
                Flexible(
                  flex: 6,
                  child: BanPhimPin(
                    khiGo: _go,
                    khiXoa: _xoa,
                    khiVanTay: s.coVanTay ? () => context.read<KhoaAppCubit>().moBangVanTay() : null,
                    tatSo: con != null || s.dangKiem,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _hoiQuen = true),
                  child: const Text('Quên mã PIN?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
                const Spacer(),
              ],
            ),
            if (_hoiQuen)
              TamXacNhanQuenPin(
                khiDangXuat: widget.khiQuenPin,
                khiHuy: () => setState(() => _hoiQuen = false),
              ),
          ],
        ),
      ),
    );
  }
}

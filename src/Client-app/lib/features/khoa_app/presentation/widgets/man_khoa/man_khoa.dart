import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/luat_khoa_app.dart';
import '../../bloc/khoa_app_cubit.dart';
import '../../bloc/khoa_app_state.dart';
import '../ban_phim_pin.dart';
import '../cham_pin.dart';
import '../mau_khoa_app.dart';
import 'tam_xac_nhan_quen_pin.dart';

/// Màn khoá — Stitch `2f0896e011874b4e84c8217c4f56346e` *"Màn khoá ứng dụng (2 biến thể)"*.
class ManKhoa extends StatefulWidget {
  const ManKhoa({super.key, required this.trangThai, required this.khiQuenPin, required this.dongHo});

  final KhoaAppKhoa trangThai;
  final VoidCallback khiQuenPin;
  final DateTime Function() dongHo;

  @override
  State<ManKhoa> createState() => ManKhoaState();
}

/// Công khai để `LopKhoaApp` (giữ phím Back — M5) hỏi được [xuLyBackTrenTam].
class ManKhoaState extends State<ManKhoa> {
  String _nhap = '';
  bool _hoiQuen = false;

  /// Đã chạm *Đăng xuất* trên tấm Quên PIN — tấm tự khoá nút Huỷ; Back cũng không được đóng tấm (chạm "Quên mã PIN?"
  /// lần hai là hai `LogoutRequested`).
  bool _dangDangXuat = false;
  Timer? _dem;

  /// Back khi tấm *Quên mã PIN?* đang mở: như chạm Huỷ — đóng tấm, hoặc giữ nguyên nếu đã chạm Đăng xuất. `true` = Back đã
  /// được dùng ở đây; `false` = tấm không mở, lớp khoá xử lý tiếp.
  bool xuLyBackTrenTam() {
    if (!_hoiQuen) return false;
    if (!_dangDangXuat) setState(() => _hoiQuen = false);
    return true;
  }

  @override
  void initState() {
    super.initState();
    _henDem();
    _tuMoVanTay();
  }

  @override
  void didUpdateWidget(ManKhoa oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trangThai.choDen != widget.trangThai.choDen) _henDem();
    if (oldWidget.trangThai.lanKhoa != widget.trangThai.lanKhoa) {
      _nhap = '';
      _hoiQuen = false;
      _dangDangXuat = false;
      _tuMoVanTay();
    }
    // Một lượt kiểm vừa KẾT THÚC (sai, hay bị chặn vì đang chờ) → xoá chấm. Đếm bằng `lanKiem` chứ không nhìn khung
    // trung gian `dangKiem` (có thể không bao giờ được dựng) hay câu lỗi (lượt bị chặn không có câu) — P13.
    if (oldWidget.trangThai.lanKiem != widget.trangThai.lanKiem) _nhap = '';
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
    if (conCho(widget.trangThai.choDen, widget.dongHo()) == null) return;
    _dem = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (conCho(widget.trangThai.choDen, widget.dongHo()) == null) t.cancel();
    });
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

  @override
  Widget build(BuildContext context) {
    final s = widget.trangThai;
    final con = conCho(widget.trangThai.choDen, widget.dongHo());
    final loi = s.loiNhan;
    return Material(
      color: AppColors.background,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          // Stitch `2f0896e0…`: cả cột căn giữa dọc; khổ thấp thì bàn phím co (BanPhimPin tự tính cạnh phím).
          SafeArea(
            child: Column(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    con != null ? 'Sai mã PIN quá nhiều lần' : (loi ?? 'Mở khoá FlowMoney'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: con != null || loi != null ? FontWeight.w500 : FontWeight.w400,
                        color: con != null || loi != null ? AppColors.expense : kXamChuKhoaApp),
                  ),
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
                                text: chuDemNguoc(con),
                                style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                              ),
                            ]),
                            style: const TextStyle(
                                fontSize: 14, color: kXamChuKhoaApp, fontFeatures: [FontFeature.tabularFigures()]),
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
          ),
          // Tấm nằm NGOÀI SafeArea: lớp mờ của nó phủ cả vùng thanh trạng thái (trong suốt từ khi màn khoá tự đặt kiểu —
          // `lop_khoa_app.dart`); phần thụt dưới do tấm tự tránh.
          if (_hoiQuen)
            TamXacNhanQuenPin(
              khiDangXuat: () {
                _dangDangXuat = true;
                widget.khiQuenPin();
              },
              khiHuy: () => setState(() => _hoiQuen = false),
            ),
        ],
      ),
    );
  }
}

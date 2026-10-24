import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../application/khoa_app_service.dart';
import '../../domain/luat_khoa_app.dart';
import '../widgets/ban_phim_pin.dart';
import '../widgets/cham_pin.dart';

enum CheDatPin {
  dat,
  doi,
  tat;

  static CheDatPin tuTen(String? ten) => values.firstWhere((c) => c.name == ten, orElse: () => dat);
}

enum _Buoc { hienTai, moi, nhapLai }

/// Đặt / đổi / tắt mã PIN — Stitch `34c3cade…` *"Đặt mã PIN (3 bước)"*. `pop(true)` khi xong.
class DatMaPinPage extends StatefulWidget {
  const DatMaPinPage({super.key, required this.che, this.service, this.idaccount});

  final CheDatPin che;

  /// Tiêm cho test; mặc định `sl<KhoaAppService>()`.
  final KhoaAppService? service;

  /// Tiêm cho test; mặc định tài khoản phiên.
  final int? idaccount;

  @override
  State<DatMaPinPage> createState() => _DatMaPinPageState();
}

class _DatMaPinPageState extends State<DatMaPinPage> {
  late _Buoc _buoc = widget.che == CheDatPin.dat ? _Buoc.moi : _Buoc.hienTai;
  String _nhap = '';
  String? _pinMoi;
  String? _loi;
  bool _dangLam = false;

  KhoaAppService get _sv => widget.service ?? sl<KhoaAppService>();
  int? get _id => widget.idaccount ?? currentAccountIdOrNull(context);

  String get _tieuDe => switch (widget.che) {
        CheDatPin.dat => 'Đặt mã PIN',
        CheDatPin.doi => 'Đổi mã PIN',
        CheDatPin.tat => 'Tắt khoá ứng dụng',
      };

  (String, String) get _chu => switch (_buoc) {
        _Buoc.hienTai => (
            'Nhập mã PIN hiện tại',
            widget.che == CheDatPin.tat ? 'Để tắt khoá ứng dụng' : 'Để đổi sang mã mới'
          ),
        _Buoc.moi => ('Nhập mã PIN mới', 'Mã gồm 6 số, chỉ lưu trên máy này'),
        _Buoc.nhapLai => ('Nhập lại mã PIN', ''),
      };

  Future<void> _du(String pin) async {
    final id = _id;
    if (id == null) return;
    setState(() => _dangLam = true);
    try {
      switch (_buoc) {
        case _Buoc.hienTai:
          final kq = await _sv.kiemPin(id, pin);
          if (!kq.dung) {
            final cho = kq.choDen;
            final conCho = cho != null && cho.isAfter(DateTime.now());
            _loi = conCho ? 'Thử lại sau ${_mmss(cho.difference(DateTime.now()))}' : 'Mã PIN không đúng';
            break;
          }
          if (widget.che == CheDatPin.tat) {
            await _sv.tatKhoa(id);
            if (mounted) Navigator.of(context).pop(true);
            return;
          }
          _buoc = _Buoc.moi;
          _loi = null;
        case _Buoc.moi:
          _pinMoi = pin;
          _buoc = _Buoc.nhapLai;
          _loi = null;
        case _Buoc.nhapLai:
          if (pin != _pinMoi) {
            _loi = 'Hai mã PIN không khớp — nhập lại';
            break;
          }
          await _sv.datPin(id, pin);
          if (mounted) Navigator.of(context).pop(true);
          return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _nhap = '';
          _dangLam = false;
        });
      }
    }
  }

  String _mmss(Duration d) {
    final g = d.isNegative ? 0 : (d.inMilliseconds / 1000).ceil();
    return '${(g ~/ 60).toString().padLeft(2, '0')}:${(g % 60).toString().padLeft(2, '0')}';
  }

  void _go(String so) {
    if (_dangLam || _nhap.length >= kDoDaiPin) return;
    setState(() => _nhap += so);
    if (_nhap.length == kDoDaiPin) _du(_nhap);
  }

  @override
  Widget build(BuildContext context) {
    final (chinh, phu) = _chu;
    final loi = _loi;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: Text(_tieuDe)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.shield_outlined, color: AppColors.onPrimary, size: 32),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(chinh,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                loi ?? phu,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: loi != null ? AppColors.expense : const Color(0xFF454743)),
              ),
            ),
            const SizedBox(height: 32),
            ChamPin(soDaNhap: _nhap.length, loi: loi != null && _nhap.isEmpty),
            Expanded(
              child: Center(
                child: BanPhimPin(
                  khiGo: _go,
                  khiXoa: () {
                    if (_nhap.isNotEmpty) setState(() => _nhap = _nhap.substring(0, _nhap.length - 1));
                  },
                  tatSo: _dangLam,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

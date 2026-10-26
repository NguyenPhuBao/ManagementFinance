import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../application/khoa_app_service.dart';
import '../../data/models/cau_hinh_khoa_app.dart';
import '../../domain/luat_khoa_app.dart';
import '../widgets/ban_phim_pin.dart';
import '../bloc/khoa_app_state.dart';
import '../widgets/cham_pin.dart';
import '../widgets/mau_khoa_app.dart';

enum CheDatPin {
  dat,
  doi,
  tat;

  static CheDatPin tuTen(String? ten) => values.firstWhere((c) => c.name == ten, orElse: () => dat);
}

enum _Buoc { hienTai, moi, nhapLai }

/// Đặt / đổi / tắt mã PIN — Stitch `34c3cade…` *"Đặt mã PIN (3 bước)"*. `pop(true)` khi xong.
class DatMaPinPage extends StatefulWidget {
  const DatMaPinPage({super.key, required this.che, this.service, this.idaccount, this.dongHo});

  final CheDatPin che;

  /// Tiêm cho test; mặc định `sl<KhoaAppService>()`.
  final KhoaAppService? service;

  /// Tiêm cho test; mặc định tài khoản phiên.
  final int? idaccount;

  /// Tiêm cho test (đồng hồ giả); mặc định `DateTime.now`.
  final DateTime Function()? dongHo;

  @override
  State<DatMaPinPage> createState() => _DatMaPinPageState();
}

class _DatMaPinPageState extends State<DatMaPinPage> {
  /// Có thể đổi từ `dat` sang `doi` lúc mở trang (xem [_napCho]) nên không dùng thẳng `widget.che`.
  late CheDatPin _che = widget.che;
  late _Buoc _buoc = widget.che == CheDatPin.dat ? _Buoc.moi : _Buoc.hienTai;
  String _nhap = '';
  String? _pinMoi;
  String? _loi;
  bool _dangLam = false;
  DateTime? _choDen;
  Timer? _dem;

  DateTime _nay() => (widget.dongHo ?? DateTime.now)();
  Duration? get _conCho => conCho(_choDen, _nay());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _napCho());
  }

  @override
  void dispose() {
    _dem?.cancel();
    super.dispose();
  }

  /// Mở trang giữa lúc đang chờ: đọc mốc từ kho để khoá phím ngay. Chế độ `dat` mà kho ĐÃ có cấu hình (route nội bộ
  /// `?che=dat` khi khoá đang bật) thì hành xử như `doi` — hỏi PIN hiện tại trước, không ghi đè PIN không cần PIN cũ.
  /// Đọc NGHIÊM NGẶT: kho đọc hỏng là *không biết* có cấu hình không → cũng coi như đã có (hỏi PIN hiện tại; `kiemPin` gặp
  /// kho hỏng thì báo không kiểm được) — bản khoan dung đọc hỏng ra `null` và để chế độ `dat` ghi đè PIN cũ.
  Future<void> _napCho() async {
    final id = _id;
    if (id == null) return;
    CauHinhKhoaApp? c;
    var hong = false;
    try {
      c = await _sv.docNghiemNgat(id);
    } catch (_) {
      hong = true;
    }
    if (!mounted) return;
    setState(() {
      if (_che == CheDatPin.dat && (c != null || hong) && _buoc == _Buoc.moi) {
        _che = CheDatPin.doi;
        _buoc = _Buoc.hienTai;
        _nhap = '';
      }
      if (_che != CheDatPin.dat) _choDen = c?.choDen;
    });
    _henDem();
  }

  void _henDem() {
    _dem?.cancel();
    if (_conCho == null) return;
    _dem = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (_conCho == null) t.cancel();
    });
  }

  KhoaAppService get _sv => widget.service ?? sl<KhoaAppService>();
  int? get _id => widget.idaccount ?? currentAccountIdOrNull(context);

  String get _tieuDe => switch (_che) {
        CheDatPin.dat => 'Đặt mã PIN',
        CheDatPin.doi => 'Đổi mã PIN',
        CheDatPin.tat => 'Tắt khoá ứng dụng',
      };

  (String, String) get _chu => switch (_buoc) {
        _Buoc.hienTai => (
            'Nhập mã PIN hiện tại',
            _che == CheDatPin.tat ? 'Để tắt khoá ứng dụng' : 'Để đổi sang mã mới'
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
          final KetQuaKiemPin kq;
          try {
            kq = await _sv.kiemPin(id, pin);
          } catch (_) {
            _loi = kCauKhongKiemDuoc;
            break;
          }
          if (!kq.dung) {
            _choDen = kq.choDen;
            _loi = conCho(_choDen, _nay()) == null ? kCauSaiPin : null;
            _henDem();
            break;
          }
          if (_che == CheDatPin.tat) {
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
          try {
            await _sv.datPin(id, pin);
          } catch (_) {
            _loi = kCauKhongLuuPin;
            break;
          }
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

  void _go(String so) {
    if (_dangLam || _conCho != null || _nhap.length >= kDoDaiPin) return;
    setState(() => _nhap += so);
    if (_nhap.length == kDoDaiPin) _du(_nhap);
  }

  @override
  Widget build(BuildContext context) {
    final (chinh, phu) = _chu;
    final con = _conCho;
    final loi = con != null ? 'Thử lại sau ${chuDemNguoc(con)}' : _loi;
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
                style: TextStyle(fontSize: 14, color: loi != null ? AppColors.expense : kXamChuKhoaApp),
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
                  tatSo: _dangLam || con != null,
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

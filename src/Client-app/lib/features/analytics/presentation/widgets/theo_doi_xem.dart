import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../domain/bo_dem_giay.dart';
import '../../domain/thu_tu_khoi.dart';

/// Bọc thân trang Phân tích để đo **giây đứng yên** trên từng cụm khối (spec
/// 3.1). Chỉ đo khi [dangDo] **và** trang đang hiện thật.
///
/// ⚠️ "Đang hiện" có BA vế — thiếu vế nào là giây cứ cộng khi người dùng đã
/// đi chỗ khác, và cụm nằm trên màn lúc rời đi thắng mọi ngày, **im lặng**:
/// 1. `TickerMode` — tab khác của `StatefulShellRoute` (State vẫn sống) và
///    route mở chồng qua navigator gốc (Overlay tắt ticker của route bị che);
/// 2. `ModalRoute.isCurrent` — bottom sheet / route mở trong navigator của
///    nhánh; hỏi mỗi nhịp vì nó không có bộ báo;
/// 3. vòng đời app `resumed`.
class TheoDoiXem extends StatefulWidget {
  const TheoDoiXem({
    super.key,
    required this.dangDo,
    required this.onHienLai,
    required this.onGhi,
    required this.builder,
    this.clock,
  });

  final bool dangDo;

  /// Trang vừa hiện **lại** (không gọi ở lần hiện đầu) — để tính lại đề xuất.
  final VoidCallback onHienLai;
  final void Function(DateTime ngay, Map<CumKhoi, int> giay) onGhi;
  final Widget Function(
      BuildContext context, ScrollController scroll, GlobalKey Function(CumKhoi) khoaCua) builder;
  final DateTime Function()? clock;

  @override
  State<TheoDoiXem> createState() => _TheoDoiXemState();
}

class _TheoDoiXemState extends State<TheoDoiXem> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _khoa = <CumKhoi, GlobalKey>{};
  final _bo = BoDemGiay();
  ValueListenable<TickerModeData>? _ticker;
  ModalRoute<Object?>? _route;
  AppLifecycleState _vongDoi =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  Timer? _dongHo;
  bool _daHien = false;
  bool _biChe = false;

  DateTime _bay() => (widget.clock ?? DateTime.now)();

  GlobalKey _khoaCua(CumKhoi c) =>
      _khoa.putIfAbsent(c, () => GlobalKey(debugLabel: 'cum-${c.ma}'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = TickerMode.getValuesNotifier(context);
    if (!identical(t, _ticker)) {
      _ticker?.removeListener(_xet);
      _ticker = t..addListener(_xet);
    }
    _route = ModalRoute.of(context);
    _xet();
  }

  @override
  void didUpdateWidget(covariant TheoDoiXem old) {
    super.didUpdateWidget(old);
    if (old.dangDo != widget.dangDo) _xet();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _vongDoi = state;
    _xet();
  }

  bool get _hien =>
      widget.dangDo && (_ticker?.value.enabled ?? true) && _vongDoi == AppLifecycleState.resumed;

  void _xet() {
    if (_hien) {
      if (_dongHo != null) return;
      _bo.batDau(_bay());
      _biChe = false;
      _dongHo = Timer.periodic(const Duration(seconds: 1), (_) => _nhip());
      if (_daHien) widget.onHienLai();
      _daHien = true;
    } else if (_dongHo != null) {
      _dongHo!.cancel();
      _dongHo = null;
      _ghi(_bo.xa());
    }
  }

  void _nhip() {
    if (!mounted) return;
    final route = _route;
    if (route != null && !route.isCurrent) {
      if (!_biChe) {
        _biChe = true;
        _ghi(_bo.xa());
      }
      return;
    }
    if (_biChe) {
      _biChe = false;
      _bo.batDau(_bay());
      widget.onHienLai();
      return;
    }
    _ghi(_bo.nhip(
      luc: _bay(),
      viTri: _scroll.hasClients ? _scroll.offset : 0,
      cum: _cumDangXem(),
    ));
  }

  CumKhoi? _cumDangXem() {
    final hop = context.findRenderObject();
    if (hop is! RenderBox || !hop.attached || !hop.hasSize) return null;
    final dinh = hop.localToGlobal(Offset.zero).dy;
    final khung = <KhungCum>[];
    for (final e in _khoa.entries) {
      final r = e.value.currentContext?.findRenderObject();
      if (r is! RenderBox || !r.attached || !r.hasSize) continue;
      final t = r.localToGlobal(Offset.zero).dy;
      khung.add(KhungCum(e.key, t, t + r.size.height));
    }
    return cumDangXem(khung, dinh, dinh + hop.size.height);
  }

  void _ghi(LuotGhi? l) {
    if (l != null) widget.onGhi(l.ngay, l.giay);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.removeListener(_xet);
    _dongHo?.cancel();
    _ghi(_bo.xa());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _bo.tuongTac(_bay()),
      child: widget.builder(context, _scroll, _khoaCua),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../bloc/goal_cubit.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';
import '../../domain/goal_auto_deposit.dart';
import '../../domain/goal_deposit_wallets.dart';
import '../../domain/goal_edit_form.dart';
import '../widgets/goal_appearance.dart';
import '../../domain/chu_ky_muc_tieu.dart';
import '../widgets/them_muc_tieu/anh_dau_muc_tieu.dart';
import '../widgets/them_muc_tieu/bang_chon_vi_muc_tieu.dart';
import '../widgets/them_muc_tieu/dai_du_doan_muc_tieu.dart';
import '../widgets/them_muc_tieu/the_lap_lai.dart';
import '../widgets/them_muc_tieu/the_thong_tin_muc_tieu.dart';
import '../widgets/them_muc_tieu/the_trich_tu_dong.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../domain/dien_san_muc_tieu.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';

/// Trang tạo mục tiêu, và — khi có [goalId] — cũng là trang **sửa**.
///
/// Một biểu mẫu cho cả hai chế độ, theo đúng lối mà thiết kế Stitch đặt ra cho
/// danh mục ("Thêm / Chỉnh sửa danh mục con"). Tách thành hai trang thì hai bản
/// sao của cùng một biểu mẫu sẽ trôi xa nhau: sửa nhãn ở một bên, quên bên kia.
///
/// Chế độ sửa **không** động tới ví tích luỹ. Ô ấy hiện ở dạng chỉ đọc và trỏ
/// người dùng về nút đổi ví ở trang chi tiết, nơi đặt phép khoá sau khoản nạp
/// đầu tiên. Nhân đôi luật khoá sang đây là tự chuốc hai luật lệch nhau.
class GoalAddPage extends StatelessWidget {
  const GoalAddPage({super.key, this.goalId, this.dienSan});

  /// `null` là tạo mới; khác `null` là sửa mục tiêu đó.
  final String? goalId;

  /// Điền sẵn từ `/goals/add?name&target&deadline` (C3 — lệnh tạo ở màn Trợ lý AI). Chỉ dùng ở đường TẠO MỚI: sửa một
  /// mục tiêu có sẵn không được bị query ghi đè.
  final DienSanMucTieu? dienSan;

  @override
  Widget build(BuildContext context) {
    final idaccount = currentAccountIdOrNull(context) ?? 0;

    return MultiBlocProvider(
      providers: [
        BlocProvider<GoalCubit>(
          create: (_) => sl<GoalCubit>(),
        ),
        BlocProvider<WalletCubit>(
          create: (_) => sl<WalletCubit>()..loadWallets(idaccount),
        ),
      ],
      child: _GoalAddPageContent(goalId: goalId, dienSan: dienSan),
    );
  }
}

class _GoalAddPageContent extends StatefulWidget {
  const _GoalAddPageContent({this.goalId, this.dienSan});

  final String? goalId;
  final DienSanMucTieu? dienSan;

  @override
  State<_GoalAddPageContent> createState() => _GoalAddPageContentState();
}

class _GoalAddPageContentState extends State<_GoalAddPageContent> {
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _depositAmountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  bool _autoDeposit = true;

  /// Lặp lại mặc định TẮT, ngược với trích tự động.
  ///
  /// Phần lớn mục tiêu tiết kiệm là việc làm một lần ("mua laptop"), nên bật
  /// sẵn là đoán sai ý người dùng ở đa số ca.
  bool _lapLai = false;
  String _chuKyLap = 'Month';
  DepositFrequency _frequency = DepositFrequency.monthly;

  bool _isRecalculatingFromDeposit = false;
  bool _isRecalculatingFromDate = false;

  WalletEntity? _selectedSavingsWallet;
  WalletEntity? _selectedSourceWallet;

  /// Mặc định của CSDL là `'flag'`, nhưng bảng chọn cố ý không có lá cờ (nó là
  /// giá trị dự phòng của `bieuTuongMucTieu`). Mục tiêu mới vì thế mở ra với
  /// con heo đất — một lựa chọn hợp lệ, nằm trong bảng, và người dùng thấy
  /// ngay là đổi được.
  String _icon = 'savings';
  String _colour = kMauMucTieu.first;

  /// Ngày trong chu kỳ: 1–7 (thứ Hai → chủ nhật) khi hàng tuần, 1–31 khi hàng
  /// tháng, bỏ qua khi hàng ngày. `null` = chưa chọn, `mocNeoTu` lấy ngày hôm
  /// nay làm mặc định.
  int? _ngayTrich;
  TimeOfDay _gioTrich = const TimeOfDay(hour: 8, minute: 0);

  bool get _isEdit => widget.goalId != null;

  String get _chuKyHienTai => switch (_frequency) {
        DepositFrequency.daily => 'Day',
        DepositFrequency.weekly => 'Week',
        DepositFrequency.monthly => 'Month',
      };

  /// Mốc neo dựng từ lựa chọn đang hiển thị. Dùng cho **cả nhãn lẫn lúc lưu**,
  /// để thứ người dùng đọc được đúng là thứ được ghi xuống.
  DateTime get _mocNeo => mocNeoTu(
        chuKy: _chuKyHienTai,
        ngay: _ngayTrich,
        gio: _gioTrich.hour,
        phut: _gioTrich.minute,
        now: DateTime.now(),
      );

  /// Mục tiêu đang sửa. `null` cho tới khi nạp xong, và ở chế độ tạo thì luôn
  /// `null`.
  GoalEntity? _goalDangSua;
  bool _dangNapGoal = false;
  String? _loiNapGoal;

  bool _daXetQuyenTrich = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mục tiêu MỚI mà không có quyền trích tự động → công tắc tắt sẵn (mặc định của form là bật). Mục tiêu đang sửa
    // giữ giá trị đã lưu (`_napGoalDeSua`). Xét một lần — đọc trong `didChangeDependencies` vì `initState` chưa có
    // `context` để đọc `GoiCubit`.
    if (_daXetQuyenTrich) return;
    _daXetQuyenTrich = true;
    if (!_isEdit && !context.coQuyenDoc(MaQuyen.goalAutoDeposit)) {
      _autoDeposit = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _targetAmountController.addListener(_onTargetAmountOrDateChanged);
    _depositAmountController.addListener(_onDepositAmountChanged);
    if (_isEdit) {
      _dangNapGoal = true;
      _napGoalDeSua();
    } else if (widget.dienSan case final d?) {
      // Cùng thứ tự với `_napGoalDeSua` (hạn trước số tiền). Ở đây chưa ô trích nào có số nên listener tính chéo không
      // đổi hạn — bản sai gán tiền trước vẫn xanh (đo 2026-09-30); giữ thứ tự để hai đường điền đọc như nhau.
      if (d.han case final han?) _targetDate = han;
      if (d.ten case final ten?) _nameController.text = ten;
      if (d.soTienDich case final tien?) {
        _targetAmountController.text = CurrencyFormatter.formatSoThoi(tien).trim();
      }
    }
  }

  /// Đọc mục tiêu và điền sẵn biểu mẫu.
  ///
  /// Thứ tự ở đây quan trọng: `_targetDate` và `_frequency` phải được đặt
  /// **trước** khi gán `_targetAmountController.text`. Hai ô số tiền và hạn
  /// định nối với nhau bằng một cặp listener tính chéo — gán tiền trước thì
  /// listener sẽ tính ra một hạn định mới từ hạn mặc định "một năm nữa" và ghi
  /// đè lên hạn thật của mục tiêu, ngay trước mắt người dùng.
  Future<void> _napGoalDeSua() async {
    try {
      final goal = await sl<GoalRepository>().getGoalById(widget.goalId!);
      if (!mounted) return;
      if (goal == null) {
        setState(() {
          _dangNapGoal = false;
          _loiNapGoal = 'Không tìm thấy mục tiêu này. Có thể nó vừa bị xoá.';
        });
        return;
      }

      _targetDate = goal.targetDate;
      _frequency = switch (goal.cycleTakeMoney) {
        'Day' => DepositFrequency.daily,
        'Week' => DepositFrequency.weekly,
        _ => DepositFrequency.monthly,
      };
      // Chu kỳ trống nghĩa là mục tiêu này chưa từng đặt kế hoạch trích tiền —
      // để công tắc tắt thay vì bịa ra "hàng tháng".
      _autoDeposit = goal.cycleTakeMoney != null;
      _icon = goal.icon;
      _colour = goal.colour;
      final mocCu = goal.timeCycleTakeMoney;
      if (mocCu != null) {
        _gioTrich = TimeOfDay(hour: mocCu.hour, minute: mocCu.minute);
        _ngayTrich = goal.cycleTakeMoney == 'Week' ? mocCu.weekday : mocCu.day;
      }
      _lapLai = goal.recurrence;
      _chuKyLap = kChuKyLapLai.containsKey(goal.timeRecurrence)
          ? goal.timeRecurrence!
          // Giá trị lạ (`'Day'`, `'Quarter'` từ Admin-web) không có ô nào để
          // hiện. Rơi về hàng tháng để bảng chọn luôn có đúng một ô sáng —
          // ba ô cùng tối trông như biểu mẫu hỏng.
          : 'Month';
      _nameController.text = goal.name;
      _noteController.text = goal.note;

      _targetAmountController.text =
          CurrencyFormatter.formatSoThoi(goal.targetAmount).trim();

      // Gán SAU số tiền mục tiêu, và phải chặn cặp listener tính chéo lại.
      // Dòng trên vừa kích hoạt `_onTargetAmountOrDateChanged`, thứ đã ghi một
      // con số GỢI Ý vào ô này; đè lại bằng số thật mà không chặn thì
      // `_onDepositAmountChanged` sẽ tính ngược ra một hạn định mới và xoá mất
      // hạn thật của mục tiêu.
      if (goal.autoDepositAmount != null) {
        _isRecalculatingFromDate = true;
        _depositAmountController.text =
            CurrencyFormatter.formatSoThoi(goal.autoDepositAmount!).trim();
        _isRecalculatingFromDate = false;
      }

      setState(() {
        _goalDangSua = goal;
        _dangNapGoal = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangNapGoal = false;
        _loiNapGoal = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _depositAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _cycleDays {
    switch (_frequency) {
      case DepositFrequency.daily:
        return 1;
      case DepositFrequency.weekly:
        return 7;
      case DepositFrequency.monthly:
        return 30;
    }
  }

  void _onTargetAmountOrDateChanged() {
    if (_isRecalculatingFromDeposit) return;
    _isRecalculatingFromDate = true;

    final rawAmount = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(rawAmount) ?? 0.0;
    if (targetAmount <= 0) {
      _isRecalculatingFromDate = false;
      return;
    }

    final totalDays = _targetDate.difference(DateTime.now()).inDays;
    final validDays = totalDays <= 0 ? _cycleDays : totalDays;
    final periods = (validDays / _cycleDays.toDouble()).ceil();
    if (periods <= 0) {
      _isRecalculatingFromDate = false;
      return;
    }

    final suggested = (targetAmount / periods).ceilToDouble();
    final formattedStr = CurrencyFormatter.formatSoThoi(suggested).trim();
    if (_depositAmountController.text != formattedStr) {
      _depositAmountController.value = TextEditingValue(
        text: formattedStr,
        selection: TextSelection.collapsed(offset: formattedStr.length),
      );
    }

    _isRecalculatingFromDate = false;
    setState(() {});
  }

  void _onDepositAmountChanged() {
    if (_isRecalculatingFromDate) return;

    final rawTarget = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(rawTarget) ?? 0.0;

    final rawDeposit = _depositAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final depositAmount = double.tryParse(rawDeposit) ?? 0.0;

    if (targetAmount <= 0 || depositAmount <= 0) return;

    _isRecalculatingFromDeposit = true;
    final periodsNeeded = (targetAmount / depositAmount).ceil();
    final daysNeeded = (periodsNeeded * _cycleDays).clamp(1, 36500);

    try {
      _targetDate = DateTime.now().add(Duration(days: daysNeeded));
    } catch (_) {}

    _isRecalculatingFromDeposit = false;
    setState(() {});
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      // Mục tiêu đang sửa có thể đã quá hạn, và `showDatePicker` ném assertion
      // — MÀN ĐỎ, không phải thông báo lỗi — khi `initialDate` nằm trước
      // `firstDate`. Xem `ngayNhoNhatChoLich`.
      firstDate: ngayNhoNhatChoLich(_targetDate, DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
      _onTargetAmountOrDateChanged();
    }
  }

  void _submitForm() {
    final name = _nameController.text.trim();
    final rawAmount = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final targetAmount = double.tryParse(rawAmount) ?? 0.0;

    if (name.isEmpty) {
      baoNhanh('Vui lòng nhập tên mục tiêu', loai: LoaiThongBao.loi);
      return;
    }
    if (targetAmount <= 0) {
      baoNhanh('Vui lòng nhập số tiền mục tiêu hợp lệ', loai: LoaiThongBao.loi);
      return;
    }

    // Hai ô này trước đây chỉ dùng để tính ngược ra hạn định rồi bị vứt —
    // khối "Tự động trích tiền định kỳ" thu ba thông tin và lưu đúng một.
    final rawTrich =
        _depositAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final soTienTrich = double.tryParse(rawTrich) ?? 0.0;

    if (_autoDeposit) {
      if (soTienTrich <= 0) {
        baoNhanh('Nhập số tiền trích mỗi kỳ, hoặc tắt công tắc '
                '"Tự động trích tiền định kỳ".', loai: LoaiThongBao.loi);
        return;
      }
      if (_selectedSourceWallet == null) {
        baoNhanh('Chọn ví nguồn để app biết trích tiền từ đâu.', loai: LoaiThongBao.loi);
        return;
      }
      // Ví nguồn trùng ví tích luỹ thì tiền không đi đâu cả trong khi tiến độ
      // vẫn tăng. `depositToGoal` cũng chặn, nhưng ở đó nó ném ra giữa một kỳ
      // trích chạy nền — chặn ngay tại form thì người dùng còn sửa được.
      final viNhanId = _idViTichLuy;
      if (viNhanId != null && _selectedSourceWallet!.id == viNhanId) {
        baoNhanh('Ví nguồn phải khác ví tích lũy — chuyển tiền sang '
                'chính nó không làm số dư đổi mà tiến độ vẫn tăng.', loai: LoaiThongBao.loi);
        return;
      }
    }

    final chuKy = _autoDeposit
        ? switch (_frequency) {
            DepositFrequency.daily => 'Day',
            DepositFrequency.weekly => 'Week',
            DepositFrequency.monthly => 'Month',
          }
        : null;

    if (_isEdit) {
      // Đường sửa dừng ở đây: không đụng ví tích luỹ (ô ấy chỉ đọc), không
      // đụng tiến độ. Cũng không cần `idaccount` — mục tiêu đã có chủ rồi.
      context
          .read<GoalCubit>()
          .updateGoal(
            id: widget.goalId!,
            name: name,
            targetAmount: targetAmount,
            targetDate: _targetDate,
            cycleTakeMoney: chuKy,
            icon: _icon,
            colour: _colour,
            note: _noteController.text.trim(),
            recurrence: _lapLai,
            timeRecurrence: _lapLai ? _chuKyLap : null,
            autoDepositAmount: _autoDeposit ? soTienTrich : null,
            autoDepositWalletId:
                _autoDeposit ? _selectedSourceWallet?.id : null,
            autoDepositAnchor: _autoDeposit ? _mocNeo : null,
          )
          .then((loi) {
        if (!mounted) return;
        if (loi != null) {
          baoNhanh(loi, loai: LoaiThongBao.loi);
          return;
        }
        baoNhanh('Đã cập nhật mục tiêu.', loai: LoaiThongBao.xong);
        context.pop();
      });
      return;
    }

    // Ví nhận là BẮT BUỘC: mỗi lần nạp tiền sau này sẽ chuyển thẳng vào ví
    // này, nên mục tiêu không có ví thì phiếu nạp không biết đưa tiền đi đâu.
    if (_selectedSavingsWallet == null) {
      baoNhanh('Vui lòng chọn ví tích lũy — tiền gửi vào mục tiêu '
              'sẽ được chuyển vào ví này.', loai: LoaiThongBao.loi);
      return;
    }

    // Đây là đường GHI: `?? 0` không dùng được ở đây (mục tiêu sẽ thuộc về
    // "không ai"), và `?? 1` thì còn tệ hơn — ghi vào tài khoản admin thật.
    final idaccount = currentAccountIdOrNull(context);
    if (idaccount == null) {
      baoNhanh('Chưa xác định được tài khoản đăng nhập. '
              'Vui lòng đăng nhập lại trước khi tạo mục tiêu.', loai: LoaiThongBao.loi);
      return;
    }

    context.read<GoalCubit>().addGoal(
          idaccount: idaccount,
          name: name,
          targetAmount: targetAmount,
          targetDate: _targetDate,
          walletId: _selectedSavingsWallet!.id,
          // Lưu nhịp người dùng vừa chọn. Trước đây lựa chọn này chỉ dùng để
          // tính ngược ra ngày hạn rồi bị vứt bỏ; giữ lại thì trang chi tiết
          // hiển thị được kế hoạch cạnh thực tế theo cùng một đơn vị.
          cycleTakeMoney: chuKy,
          icon: _icon,
          colour: _colour,
          note: _noteController.text.trim(),
          recurrence: _lapLai,
          timeRecurrence: _lapLai ? _chuKyLap : null,
          autoDepositAmount: _autoDeposit ? soTienTrich : null,
          autoDepositWalletId: _autoDeposit ? _selectedSourceWallet?.id : null,
          autoDepositAnchor: _autoDeposit ? _mocNeo : null,
        ).then((loi) {
      if (!mounted) return;
      // Đối xứng với đường sửa ở trên: có lỗi thì GIỮ trang mở để người dùng
      // sửa lại chỗ sai. Bản trước đóng trang và báo "thành công" bất kể kết
      // quả, nên một mục tiêu bị từ chối biến mất cùng mọi thứ vừa gõ.
      if (loi != null) {
        baoNhanh(loi, loai: LoaiThongBao.loi);
        return;
      }
      baoNhanh('Tạo mục tiêu tiết kiệm thành công!', loai: LoaiThongBao.xong);
      context.pop();
    });
  }

  DateTime _calculateEstimatedCompletionDate() {
    return _targetDate;
  }

  /// Ví tích luỹ hiện hành, tức ví mà mọi khoản nạp sẽ chảy VÀO.
  ///
  /// Ở chế độ sửa nó là thuộc tính cố định của mục tiêu — ô ấy chỉ đọc, nên
  /// đọc từ `_selectedSavingsWallet` sẽ ra `null` ở những khung dựng đầu tiên.
  /// Ở chế độ tạo nó là ví người dùng vừa chọn, và **có quyền còn null**.
  String? get _idViTichLuy =>
      _isEdit ? _goalDangSua?.walletId : _selectedSavingsWallet?.id;

  void _chonViTichLuy(List<WalletEntity> wallets) {
    moBangChonViMucTieu(
      mainContext: context,
      title: 'Chọn Ví Tích Lũy Liên Kết',
      wallets: wallets,
      selectedWallet: _selectedSavingsWallet,
      onWalletSelected: (w) {
        setState(() {
          _selectedSavingsWallet = w;
          // Ví vừa chọn làm ví tích luỹ mà đang là
          // ví nguồn trích thì cặp ấy không còn lưu
          // được. Nhả ô nguồn ra để nó được điền
          // lại bằng một ví hợp lệ ở khung dựng kế
          // tiếp, thay vì giữ một lựa chọn đã hỏng
          // cho tới lúc bấm Lưu.
          if (_selectedSourceWallet?.id == w.id) {
            _selectedSourceWallet = null;
          }
        });
      },
    );
  }

  void _chonViNguon(List<WalletEntity> wallets) {
    moBangChonViMucTieu(
      mainContext: context,
      title: 'Chọn Ví Nguồn Trích Tiền',
      wallets: wallets,
      loaiTruViId: _idViTichLuy,
      thongDiepRong: 'Cần thêm một ví khác ví tích '
          'luỹ để làm ví nguồn trích tiền.',
      selectedWallet: _selectedSourceWallet,
      onWalletSelected: (w) {
        setState(() => _selectedSourceWallet = w);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estimatedCompletionDate = _calculateEstimatedCompletionDate();

    return BlocListener<GoalCubit, GoalState>(
      listener: (context, state) {
        if (state is GoalError) {
          baoNhanh('Lỗi: ${state.message}', loai: LoaiThongBao.loi);
        }
      },
      child: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, walletState) {
          final wallets = (walletState is WalletLoaded) ? walletState.wallets : <WalletEntity>[];

          if (_isEdit) {
            // Chế độ sửa chỉ HIỂN THỊ ví tích luỹ, không cho đổi ở đây — nên
            // nó được tra ra từ chính mục tiêu chứ không phải từ lựa chọn nào.
            final viId = _goalDangSua?.walletId;
            _selectedSavingsWallet = viId == null
                ? null
                : wallets.where((w) => w.id == viId).firstOrNull;
          }
          if (_isEdit && _goalDangSua?.autoDepositWalletId != null) {
            // Ví nguồn đã lưu thắng ví mặc định. Không có nhánh này thì mở
            // trang sửa rồi bấm Lưu là âm thầm đổi ví trích sang ví mặc định —
            // tiền kỳ sau ra khỏi một ví khác hẳn.
            _selectedSourceWallet ??= wallets
                .where((w) => w.id == _goalDangSua!.autoDepositWalletId)
                .firstOrNull;
          }
          if (wallets.isNotEmpty && _selectedSourceWallet == null) {
            // Phép chọn sẵn PHẢI biết ví tích luỹ là ví nào. Trước đây nó lấy
            // thẳng ví mặc định của tài khoản mà không đối chiếu, nên người
            // dùng chọn đúng ví ấy làm ví tích luỹ — việc rất dễ xảy ra vì đó
            // là ví họ dùng nhiều nhất — thì biểu mẫu mở ra đã ở trạng thái
            // không lưu được, và họ chỉ biết sau khi bấm Lưu.
            //
            // Ví mặc định vẫn là phỏng đoán đầu tiên; nó chỉ bị bỏ qua khi
            // trùng ví tích luỹ. `viNguonTrichMacDinh` giữ MỘT định nghĩa duy
            // nhất của "ví nguồn hợp lệ", dùng chung với phiếu nạp tay ở trang
            // chi tiết.
            final idNguon = viNguonTrichMacDinh(
              viCoSan: wallets.map((w) => w.id).toList(),
              viNhan: _idViTichLuy,
              viUuTien: wallets.where((w) => w.isDefault).firstOrNull?.id,
            );
            // `null` ở đây là thật: tài khoản chỉ có đúng ví tích luỹ. Để ô
            // trống và để bảng chọn nói ra lý do, thay vì gán bừa một ví.
            _selectedSourceWallet = idNguon == null
                ? null
                : wallets.where((w) => w.id == idNguon).firstOrNull;
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => context.pop(),
              ),
              title: Text(
                _isEdit ? 'Chỉnh sửa mục tiêu' : 'Thêm Mục Tiêu Tiết Kiệm',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _dangNapGoal ? null : _submitForm,
                  child: const Text(
                    'Lưu',
                    style: TextStyle(
                      color: AppColors.income,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            body: _dangNapGoal
                ? const Center(child: CircularProgressIndicator())
                : _loiNapGoal != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _loiNapGoal!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Image
                    const AnhDauMucTieu(),
                    const SizedBox(height: 16),

                    // Goal Information Card
                    TheThongTinMucTieu(
                      isEdit: _isEdit,
                      nameController: _nameController,
                      targetAmountController: _targetAmountController,
                      noteController: _noteController,
                      targetDate: _targetDate,
                      onChonHan: _selectDate,
                      icon: _icon,
                      colour: _colour,
                      onChonIcon: (v) => setState(() => _icon = v),
                      onChonMau: (v) => setState(() => _colour = v),
                      selectedSavingsWallet: _selectedSavingsWallet,
                      onChonViTichLuy:
                          _isEdit ? null : () => _chonViTichLuy(wallets),
                    ),
                    const SizedBox(height: 16),

                    // Auto-Deposit Schedule Card
                    TheTrichTuDong(
                      autoDeposit: _autoDeposit,
                      onDoiTrich: (val) {
                        setState(() => _autoDeposit = val);
                      },
                      depositAmountController: _depositAmountController,
                      frequency: _frequency,
                      onDoiChuKy: (freq) {
                        setState(() => _frequency = freq);
                        _onTargetAmountOrDateChanged();
                      },
                      chuKyHienTai: _chuKyHienTai,
                      mocNeo: _mocNeo,
                      gioTrich: _gioTrich,
                      onChonNgayTrich: _chonNgayTrich,
                      onChonGioTrich: _chonGioTrich,
                      selectedSourceWallet: _selectedSourceWallet,
                      onChonViNguon: () => _chonViNguon(wallets),
                    ),
                    const SizedBox(height: 16),

                    // Thẻ LẶP LẠI — thẻ riêng, không nhét chung với trích tự
                    // động. Hai thứ khác hẳn nhau: trích tự động là nhịp bỏ
                    // tiền vào TRONG một vòng, lặp lại là chuyện xảy ra SAU khi
                    // vòng ấy kết thúc. Gộp một thẻ thì người dùng đọc "chu kỳ"
                    // hai lần trong cùng một khối và không phân biệt được.
                    TheLapLai(
                      lapLai: _lapLai,
                      onDoiLapLai: (val) => setState(() => _lapLai = val),
                      chuKyLap: _chuKyLap,
                      onDoiChuKy: (v) => setState(() => _chuKyLap = v),
                    ),
                    const SizedBox(height: 16),

                    // AI Prediction Insight Banner
                    DaiDuDoanMucTieu(
                      estimatedCompletionDate: estimatedCompletionDate,
                      depositAmountController: _depositAmountController,
                      frequency: _frequency,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        _isEdit
                            ? 'Lưu thay đổi'
                            : _autoDeposit
                                ? 'Tạo Mục Tiêu & Bật Trích Tự Động'
                                : 'Tạo Mục Tiêu',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _chonGioTrich() async {
    final chon = await showTimePicker(context: context, initialTime: _gioTrich);
    if (chon != null && mounted) setState(() => _gioTrich = chon);
  }

  /// Bảng chọn ngày trong chu kỳ — bảy thứ khi hàng tuần, 1–31 khi hàng tháng.
  void _chonNgayTrich() {
    final laTuan = _frequency == DepositFrequency.weekly;
    final soLuaChon = laTuan ? 7 : 31;
    final dangChon =
        _ngayTrich ?? (laTuan ? DateTime.now().weekday : DateTime.now().day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              laTuan ? 'Trích vào thứ mấy?' : 'Trích vào ngày nào trong tháng?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            if (!laTuan)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  // Nói trước để không ai bất ngờ. Phép kẹp nằm ở `mocNeoTu`
                  // và `mocKeTiep`.
                  'Chọn ngày 29–31 thì tháng ngắn hơn sẽ trích vào ngày cuối '
                  'tháng.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: soLuaChon,
                itemBuilder: (_, i) {
                  final gt = i + 1;
                  return ListTile(
                    title: Text(laTuan ? tenThuTrongTuan(gt) : 'Ngày $gt'),
                    trailing: gt == dangChon
                        ? const Icon(Icons.check_circle,
                            color: AppColors.income)
                        : null,
                    onTap: () {
                      setState(() => _ngayTrich = gt);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

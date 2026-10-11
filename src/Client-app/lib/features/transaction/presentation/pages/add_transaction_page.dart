import 'dart:async';
import '../../../../core/utils/currency_formatter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../category/domain/category_classify.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/notification/kho_bien_lai.dart';
import '../../../../core/ocr/kho_anh_quet.dart';
import '../../../budget/data/models/budget_entity.dart';
import '../../domain/ban_phim_so_tien.dart';
import '../../domain/dien_san_bien_dong.dart';
import '../../domain/tach_giao_dich.dart';
import '../../data/doc_cau_bang_ai.dart';
import '../../data/them_giao_dich_nguon.dart';
import '../../data/vi_theo_nguon_store.dart';
import '../bloc/them_giao_dich_cubit.dart';
import '../bloc/them_giao_dich_state.dart';
import '../widgets/khoi_tach.dart';
import '../widgets/sheet_them_phan.dart';
import '../widgets/them_giao_dich/ban_phim_so.dart';
import '../widgets/them_giao_dich/bang_chon_vi.dart';
import '../widgets/them_giao_dich/dai_nguon_bien_dong.dart';
import '../widgets/them_giao_dich/khoi_so_tien.dart';
import '../widgets/them_giao_dich/o_nhap_nhanh.dart';
import '../widgets/them_giao_dich/the_form.dart';
import '../widgets/them_giao_dich/the_goi_y.dart';
import '../../../budget/domain/budget_impact.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/category/data/goi_y_phan_hoi_store.dart';
import '../../../../features/category/data/repositories/category_management_repository.dart';
import '../../../../features/category/data/services/category_suggestion_engine.dart';
import '../../../../features/category/domain/phan_loai_ghi_chu.dart';
import '../../../../features/category/domain/phan_loai_so_tien.dart';
import '../../../../features/premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/goi_cubit.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import '../../../../core/ui/bao_che_day_toast.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

// `BudgetLookup` dời sang lớp nguồn; trang export lại để nơi gọi cũ (`widget.budgetLookup`, test) không đổi import.
export '../../data/them_giao_dich_nguon.dart' show BudgetLookup;

/// Dữ liệu mở trang ở chế độ SỬA: giao dịch gốc và danh mục của nó (đã tra
/// sẵn ở nơi gọi, vì entity chỉ giữ `categoryId`). Đi qua `extra` của route
/// `/add`.
class EditTransactionArgs {
  const EditTransactionArgs({required this.transaction, this.category});

  final TransactionEntity transaction;
  final Category? category;
}

class AddTransactionPage extends StatefulWidget {
  /// Mã tài khoản **tiêm vào** — chỉ widget test dùng. Đường chạy thật để
  /// `null` và suy từ phiên đăng nhập; xem [_AddTransactionPageState._accountId].
  final int? idaccount;
  final CategoryManagementRepository? categoryRepository;
  final List<Wallet>? wallets;
  /// Bảng `categoryId → walletId` học từ lịch sử (`domain/vi_hay_dung.dart`).
  ///
  /// `null` → trang tự đọc từ SQLite. Ca test tiêm thẳng bảng để khỏi dựng CSDL,
  /// đúng khuôn [wallets].
  final Map<String, String>? viHayDung;

  /// Mô hình gợi ý danh mục học từ ghi chú (B1, `category/domain/phan_loai_ghi_chu.dart`).
  ///
  /// `null` → trang tự học từ SQLite trong CÙNG lượt đọc sổ của [viHayDung]. Ca test tiêm thẳng mô hình để khỏi
  /// dựng CSDL, đúng khuôn [viHayDung].
  final BoPhanLoaiGhiChu? boPhanLoai;

  /// Mô hình gợi ý danh mục theo SỐ TIỀN (dự án C, `category/domain/phan_loai_so_tien.dart`) — nguồn thứ ba của thẻ gợi
  /// ý, CHỈ dùng khi ô ghi chú trống (ghi chú có chữ thì thẻ thuộc về B1 / từ khoá, kể cả khi hai nguồn ấy im).
  ///
  /// `null` → trang tự học từ SQLite trong CÙNG lượt đọc sổ của [viHayDung]. Ca test tiêm thẳng, đúng khuôn [boPhanLoai].
  final BoPhanLoaiSoTien? boSoTien;

  /// Nơi ghi phản hồi thẻ gợi ý (B1). `null` → `sl<GoiYPhanHoiStore>()` nếu đã đăng ký; ca test tiêm bản trong bộ
  /// nhớ. Không có store nào thì trang vẫn gợi ý, chỉ không ghi và không thôi gợi ý.
  final GoiYPhanHoiStore? phanHoiGoiY;

  final CategorySuggestionEngine suggestionEngine;
  final TransactionBloc? transactionBloc;

  /// Có giá trị → trang là "Sửa giao dịch": điền sẵn, lưu bằng
  /// `UpdateTransactionEvent` (cùng `id`), không tạo hàng mới.
  final EditTransactionArgs? initial;

  /// Tra ngân sách đang chạy của một danh mục, để hỏi/báo trước khi ghi khoản
  /// chi. `null` = lấy từ `sl<BudgetRepository>()`; test tiêm thẳng để không
  /// phải dựng DI.
  final BudgetLookup? budgetLookup;

  /// Đoạn chọn sẵn khi mở trang: `'chi'` | `'thu'` | `'transfer'`. Ba nút tắt
  /// ở Trang chủ đi qua đây (UX 2026-09-19, C4); `null` = Chi tiêu. Bị bỏ qua
  /// ở chế độ sửa vì khi ấy đoạn lấy từ `type` của giao dịch.
  final String? huongBanDau;

  /// Đọc câu ở ô Nhập nhanh bằng mô hình trên máy (C2 §2.8). `null` → `sl<DocCauBangAi>()` nếu đã đăng ký; không có
  /// thì chỉ luật. Widget test tiêm bản dựng trên runtime giả.
  final DocCauBangAi? docAi;

  /// D1 — mở từ một hàng biến động số dư (`/add?…&khoa=bienDong:…`, spec D1 §3.3, Stitch `52d9d2ef…`): form điền
  /// sẵn tiền / chiều / ngày giờ / ghi chú / danh mục, ví theo nguồn + đuôi TK; không ô Nhập nhanh; thanh tiêu đề có
  /// **Bỏ qua**; Lưu hoặc Bỏ qua thì xoá cứng hàng ấy. `null` = mở thường. Bị bỏ qua ở chế độ sửa.
  final DienSanBienDong? bienDong;

  /// Bảng *"nguồn + đuôi TK → ví"* (D1). `null` → `sl<ViTheoNguonStore>()` nếu đã đăng ký.
  final ViTheoNguonStore? viTheoNguon;

  /// Xoá cứng hàng loại 20 theo `dedupeKey` (D1). `null` → `ThongBaoNguon.xoaCung`.
  final Future<void> Function(int idaccount, String khoa)? xoaBienDong;

  /// Sổ giao dịch để nhắc *"có thể bạn đã ghi khoản này"* (D1). `null` → `TransactionRepository.getAllRows`.
  final Future<List<KhoanSo>> Function(int idaccount)? khoanTrongSo;

  /// Các hàng biến động đang chờ của tài khoản — căn cứ luật cặp của gợi ý Chuyển khoản (spec 2026-09-30). `null` →
  /// `ThongBaoNguon.getAll`.
  final Future<List<DienSanBienDong>> Function(int idaccount)? hangBienDongCho;

  /// Chia sẻ biên lai (2026-10-02): thư mục ảnh biên lai — form hiện ảnh nhỏ của hàng đang mở ([DienSanBienDong.anh])
  /// để đối chiếu, và xoá tệp khi Lưu / Bỏ qua. `null` → `sl<KhoBienLai>()` nếu đã đăng ký.
  final KhoBienLai? khoBienLai;

  /// A5 — kho ảnh QUÉT (`filesDir/anh_quet/`): form mở từ khoá `quet:` hiện ảnh + đọc danh sách món từ đây, và xoá ảnh
  /// khi đóng. `null` → `sl<KhoAnhQuet>()` nếu đã đăng ký.
  final KhoAnhQuet? khoAnhQuet;

  /// A5 11.2b — sheet *Thêm phần* cho tick món của ảnh quét. Mặc định [kChonMonTuAnhQuet] (đang TẮT); test bật để giữ
  /// đường mã ấy sống.
  final bool choTickMon;

  /// Ô Nhập nhanh là đặc quyền Premium — Basic khoá CẢ ô (spec Premium 2026-10-06 mục 8.2, người dùng chốt; màn Stitch
  /// *"Thêm giao dịch - Nhập nhanh khoá (Basic)"* `21790848a0dc4e98970c0a591b88f44e`). `null` =
  /// đọc `GoiCubit` qua `context`; **không có provider thì không khoá** — chỉ test cũ gặp ca ấy. Chỉ khoá giao diện:
  /// `DocCauBangAi`, `docCauGiaoDich` không đổi; điền sẵn từ D1 / biên lai / C3 không đi qua ô này.
  final bool? laPremium;

  const AddTransactionPage({
    super.key,
    this.idaccount,
    this.categoryRepository,
    this.wallets,
    this.suggestionEngine = const CategorySuggestionEngine(),
    this.transactionBloc,
    this.initial,
    this.budgetLookup,
    this.huongBanDau,
    this.viHayDung,
    this.boPhanLoai,
    this.boSoTien,
    this.phanHoiGoiY,
    this.docAi,
    this.bienDong,
    this.viTheoNguon,
    this.xoaBienDong,
    this.khoanTrongSo,
    this.hangBienDongCho,
    this.khoBienLai,
    this.khoAnhQuet,
    this.choTickMon = kChonMonTuAnhQuet,
    this.laPremium,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  /// Premium? Tiêm cho test, hoặc đọc `GoiCubit` (`context.read` — `BlocProvider.of` bọc lỗi thiếu provider thành
  /// `FlutterError`, không bắt được). Xem [AddTransactionPage.laPremium].
  bool get _laPremium {
    final t = widget.laPremium;
    if (t != null) return t;
    try {
      return context.read<GoiCubit>().coQuyen(MaQuyen.aiQuickInput);
    } on ProviderNotFoundException {
      return true;
    }
  }

  /// Lõi form (số tiền, 16 phím, chiều, ví, danh mục, chiều nợ, ngày, phần tách) nằm ở [ThemGiaoDichCubit] — spec
  /// `2026-10-11-tach-trang-them-giao-dich-cubit-design.md`. ⚠️ Đoạn `huong` là LỐI VÀO, không phải sự thật: `type` ghi
  /// xuống SQLite suy từ danh mục (`loaiGhi`, luật 2026-09-05).
  late final ThemGiaoDichCubit _cubit = ThemGiaoDichCubit(
    nguon: _nguon,
    taiKhoan: _accountId,
    boGoiY: widget.suggestionEngine,
    dangSua: widget.initial?.transaction,
    danhMucDangSua: widget.initial?.category,
    huongBanDau: widget.huongBanDau,
    bienDong: widget.bienDong,
    choTickMon: widget.choTickMon,
  );

  ThemGiaoDichState get _s => _cubit.state;

  // ⏳ Bí danh TẠM (trang lai, Task 2–4): mã chưa dời vẫn đọc tên cũ. Task 5 thay bằng `_s.…` rồi xoá khối này.
  String get _huong => _s.huong;
  String get _amountString => _s.chuoiSoTien;
  bool get _hienBanPhimSo => _s.hienBanPhimSo;
  List<Wallet> get _wallets => _s.vi;
  Wallet? get _selectedWallet => _s.viNguon;
  Wallet? get _destinationWallet => _s.viDich;
  Category? get _selectedCategory => _s.danhMuc;
  String? get _debtDirection => _s.chieuNo;
  DateTime get _selectedDate => _s.ngay;
  bool get _isLoadingWallets => _s.dangNapVi;
  List<PhanTach> get _phanTach => _s.phanTach;
  Map<String, Category> get _dmTheoId => _s.dmTheoId;

  /// Khoá của thẻ gợi ý — để [_cuonToiTheGoiY] đưa thẻ nguồn số tiền vào khung nhìn.
  final GlobalKey _khoaTheGoiY = GlobalKey();

  /// Mọi đọc / ghi dữ liệu của form (spec 2026-10-11 mục 4.3). Dựng một lần từ tham số khởi tạo.
  late final ThemGiaoDichNguon _nguon = ThemGiaoDichNguonThat(
    danhMuc: widget.categoryRepository,
    viTiem: widget.wallets,
    viHayDungTiem: widget.viHayDung,
    boPhanLoaiTiem: widget.boPhanLoai,
    boSoTienTiem: widget.boSoTien,
    phanHoi: widget.phanHoiGoiY,
    docAi: widget.docAi,
    viTheoNguon: widget.viTheoNguon,
    xoaBienDong: widget.xoaBienDong,
    khoanTrongSo: widget.khoanTrongSo,
    hangBienDongCho: widget.hangBienDongCho,
    khoBienLai: widget.khoBienLai,
    khoAnhQuet: widget.khoAnhQuet,
    traNganSach: widget.budgetLookup,
  );

  final TextEditingController _noteController = TextEditingController();

  /// Ô *Nhập nhanh* (C2) — chỉ ở đường tạo mới.
  final TextEditingController _nhapNhanhController = TextEditingController();

  /// Ô Nhập nhanh có focus → nạp mô hình ngầm (người dùng chốt 2026-09-30).
  final FocusNode _nhapNhanhFocus = FocusNode();

  /// D1: form đang mở từ một hàng biến động số dư (đường tạo mới).
  DienSanBienDong? get _bienDong => _isEditing ? null : widget.bienDong;

  /// Tác động lên ngân sách của khoản vừa gửi đi, để listener chọn lời nhắn
  /// sau khi lưu xong. Đặt ngay trước khi gửi event, xoá ngay khi đã dùng.
  BudgetImpact? _pendingImpact;

  TransactionEntity? get _editing => widget.initial?.transaction;
  bool get _isEditing => _editing != null;

  @override
  void initState() {
    super.initState();
    // Điền sẵn TRƯỚC khi gắn listener ghi chú, để lần gán text đầu không kích hoạt tra cứu gợi ý. (Phần còn lại của
    // đường sửa do Cubit dựng sẵn; ảnh biên lai / ảnh quét và D1 do `moTrang` nạp.)
    _noteController.text = _s.ghiChu;
    _noteController.addListener(_onNoteChanged);
    _nhapNhanhFocus.addListener(() {
      if (_nhapNhanhFocus.hasFocus) _cubit.chuanBiAi();
    });
    unawaited(_cubit.moTrang());
  }

  /// Số giao dịch của lần Lưu đang chờ `actionSuccess` — toast *"Đã lưu N giao dịch"*.
  int _soGiaoDichVuaLuu = 1;

  /// C2 — đọc câu ô *Nhập nhanh* rồi điền sẵn (Cubit lo toàn bộ); trang chỉ đóng bàn phím trước.
  Future<void> _dienTuCau() async {
    final cau = _nhapNhanhController.text.trim();
    if (cau.isEmpty || _cubit.dangDien) return;
    FocusScope.of(context).unfocus();
    await _cubit.dienTuCau(cau);
  }

  /// Huỷ lượt đọc bằng AI: điền ngay bằng luật, mô hình thôi giải mã.
  Future<void> _huyDocAi() => _cubit.huyDocAi(_nhapNhanhController.text.trim());

  Future<void> _boQuaBienDong() async {
    await _cubit.boQuaBienDong();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _nhapNhanhController.dispose();
    _nhapNhanhFocus.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  /// Mã tài khoản của phiên, hoặc `null` khi CHƯA có phiên dùng được.
  ///
  /// ⚠️ Trước 2026-09-14 hàm này rơi về `widget.idaccount`, vốn mặc định `1` —
  /// **tài khoản admin thật**. Đây là đường **GHI** giao dịch, nên hậu quả
  /// nặng nhất trong ba trang cùng lỗi: giao dịch ghi dưới danh nghĩa admin
  /// rồi đẩy lên và vỡ "Ownership mismatch" — đúng kịch bản mà docstring
  /// `features/auth/presentation/bloc/current_account.dart` mô tả khi G4 được đóng. Nó lọt lưới quét
  /// `?? 1` vì biểu thức viết là `?? widget.idaccount`.
  int? _accountId() {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess) {
        final parsed = int.tryParse(authState.user?.id ?? '');
        if (parsed != null && parsed > 0) return parsed;
      }
    } catch (_) {
      // Ca test bộ chọn ví chạy riêng không dựng AuthBloc.
    }
    return widget.idaccount;
  }

  /// Đường DUY NHẤT để đặt danh mục — cả bảng chọn lẫn thẻ gợi ý đều qua đây (Cubit lo chiều vay/nợ, đoạn đầu màn, ví hay
  /// dùng, phần tách, gỡ thẻ gợi ý và tính lại đề xuất từ khoá).
  void _chonDanhMuc(Category category) => _cubit.chonDanhMuc(category);

  /// Chạm một đoạn Chi tiêu / Thu nhập / Chuyển khoản.
  void _chonHuong(String huong) => _cubit.chonHuong(huong);

  /// Chữ ô ghi chú → Cubit (state.ghiChu, hẹn gợi ý, đề xuất từ khoá). Controller phát cả khi chỉ đổi con trỏ — Cubit so
  /// CHỮ, trùng thì thoát.
  void _onNoteChanged() => _cubit.ghiChuDoi(_noteController.text);

  /// Đưa thẻ gợi ý theo số tiền vào khung nhìn (người dùng chọn 2026-10-02).
  ///
  /// Nghiệm thu Realme RMX2205 (360 dp): thẻ nằm dưới hàng *Danh mục*, mà ngay dưới hàng ấy là 16 phím số — thẻ đã
  /// dựng nhưng khuất hẳn, gõ số tiền xong người dùng không thấy gì đổi. `keepVisibleAtEnd`: chỉ cuộn khi đáy thẻ
  /// đang khuất, và cuộn vừa đủ; thẻ đã nằm trong khung (màn cao, 16 phím đang ẩn) thì không động gì.
  ///
  /// ⚠️ KHÔNG gọi cho thẻ B1 / từ khoá: hai thẻ ấy hiện lúc người dùng đang gõ GHI CHÚ, và ô ghi chú nằm DƯỚI thẻ —
  /// kéo đáy thẻ về sát bàn phím là đẩy chính ô đang gõ ra sau bàn phím.
  void _cuonToiTheGoiY() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _khoaTheGoiY.currentContext;
      if (!mounted || ctx == null) return;
      unawaited(Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ));
    });
  }

  void _moChonVi(BuildContext context, {required bool isDestination}) => moBangChonVi(
        context,
        isDestination: isDestination,
        wallets: _wallets,
        idDangChon: isDestination ? _destinationWallet?.id : _selectedWallet?.id,
        onChon: (w) {
          if (isDestination) {
            _cubit.chonViDich(w);
          } else {
            _cubit.chonVi(w);
          }
        },
      );

  /// Phép gõ nằm ở `domain/ban_phim_so_tien.dart` — hàm thuần, có test riêng.
  ///
  /// Tách ra vì màn này **tự vẽ bàn phím** thay vì dùng `TextField`, nên
  /// `inputFormatters` không với tới đây và trần số chữ số phải chặn ngay trong
  /// phép gõ. `transaction."Amount"` là `numeric(15,2)`: chữ số thứ 14 làm giao
  /// dịch **kẹt hàng đợi đẩy vĩnh viễn**, im lặng.
  void _onKeyPress(String key) {
    _cubit.goPhim(key);
  }

  String _getFormattedAmount() {
    // Đang gõ một phép tính thì dòng số là BIỂU THỨC, không kèm ký hiệu tiền
    // — một biểu thức chưa phải một số tiền. Tổng hiện ở dòng ngay dưới.
    if (coToanTu(_amountString)) return nhanBieuThuc(_amountString);
    if (_amountString == "0") return CurrencyFormatter.format(0);
    // Chuỗi có dấu chấm chỉ tới từ chế độ sửa (`initState` đọc
    // `editing.amount.toString()`); bàn phím hết phím `.` từ 2026-09-19.
    // ⚠️ In thẳng chuỗi thô là hiện "12.5 đ", mà khắp app dấu chấm là dấu
    // NGĂN NGHÌN — người dùng đọc ra một con số khác, ngay cạnh nút lưu.
    // `formatCoLe` ngăn phần lẻ bằng dấu phẩy, đúng thông lệ Việt Nam.
    final coLe = double.tryParse(_amountString);
    if (_amountString.contains('.') && coLe != null) {
      return CurrencyFormatter.formatCoLe(coLe);
    }
    try {
      final number = int.parse(_amountString);
      return CurrencyFormatter.format(number);
    } catch (_) {
      return '$_amountString ${CurrencyFormatter.kyHieu}';
    }
  }

  Color _getAmountColor() =>
      _s.loaiGhi == 'thu' ? AppColors.income : AppColors.primary;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _cubit.chonNgay(picked);
    }
  }

  Future<void> _saveTransaction(BuildContext context) async {
    // ⚠️ KHÔNG `replaceAll('.', '')` (A12, 2026-09-19). `_amountString` là
    // chuỗi **thô** đang gõ, không phải chuỗi đã ngăn nghìn — phép ngăn nghìn
    // chỉ áp ở `_getFormattedAmount`. Coi dấu chấm là dấu ngăn nghìn thì một
    // số lẻ bị mất dấu rồi đọc tiếp: `12.5` lưu thành **125**, sai gấp mười,
    // không exception, không log. Bàn phím nay hết phím `.`, nhưng chuỗi có
    // dấu chấm vẫn vào được qua chế độ sửa (`initState` đọc
    // `editing.amount.toString()`) — và số lẻ có thật, `transaction."Amount"`
    // là `numeric(15,2)`. Nên chốt phải nằm ở ĐÂY, không chỉ ở bàn phím.
    // ⚠️ Phải RÚT GỌN, không `double.tryParse` thẳng: từ 2026-09-19 bàn phím
    // dựng được biểu thức (`"50000+30000"`), mà parse thẳng chuỗi ấy trả
    // `null` rồi rơi về 0 — chốt `amount <= 0` ngay dưới sẽ báo "Vui lòng nhập
    // số tiền hợp lệ" cho một con số người dùng vừa gõ đúng.
    final amount = ketQuaBieuThuc(_amountString);
    if (amount <= 0) {
      baoNhanh('Vui lòng nhập số tiền hợp lệ', loai: LoaiThongBao.loi);
      return;
    }
    if (_selectedWallet == null) {
      baoNhanh('Vui lòng chọn ví thanh toán', loai: LoaiThongBao.loi);
      return;
    }
    if (!_s.laChuyen && _selectedCategory == null) {
      baoNhanh('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      return;
    }
    if (_s.laChuyen && _destinationWallet == null) {
      baoNhanh('Vui lòng chọn ví đích', loai: LoaiThongBao.loi);
      return;
    }
    final type = _s.loaiGhi;
    if (type == null) {
      baoNhanh('Vui lòng chọn chiều tiền', loai: LoaiThongBao.loi);
      return;
    }
    // ⚠️ Chốt cuối, và là chốt quan trọng nhất trong chuỗi này: KHÔNG ghi
    // giao dịch khi chưa biết nó thuộc về ai. Trước 2026-09-14 nhánh này rơi
    // về mã `1` — tài khoản admin thật — nên giao dịch ghi trong lúc phiên
    // chưa sẵn sàng sẽ mang chủ sở hữu sai, rồi đẩy lên và vỡ "Ownership
    // mismatch" mà không ai lần được từ đâu. Sửa giao dịch cũ thì `editing`
    // đã mang sẵn chủ sở hữu, nên đường ấy không cần chốt.
    final accountId = _editing?.idaccount ?? _accountId();
    if (accountId == null) {
      baoNhanh('Chưa xác định được tài khoản đăng nhập', loai: LoaiThongBao.loi);
      return;
    }

    final editing = _editing;
    final tx = TransactionEntity(
      // Sửa thì giữ nguyên id (và những gì form không đụng tới) — tạo id mới
      // là nhân đôi giao dịch.
      id: editing?.id ?? const Uuid().v4(),
      walletId: _selectedWallet!.id,
      idaccount: accountId,
      // Khoản chuyển KHÔNG có danh mục. Trước đây chỗ này gán 'cat_transfer' —
      // một id chưa từng được seed — và SyncEngine hoãn đẩy hàng ấy vĩnh viễn
      // vì không phân giải được danh mục.
      categoryId: _s.laChuyen ? null : _selectedCategory!.id,
      walletTransfer: _s.laChuyen ? _destinationWallet!.id : null,
      goalId: editing?.goalId,
      amount: amount,
      type: type,
      note: _noteController.text.trim(),
      date: _selectedDate,
      images: editing?.images ?? const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    final bloc = context.read<TransactionBloc>();

    // A5 mục 11 — khoản chi đã TÁCH: N giao dịch, ghi hết hoặc không gì, một toast.
    if (_phanTach.isNotEmpty && editing == null && type == 'chi') {
      await _luuTach(context, tx, amount);
      return;
    }

    // Ngân sách của danh mục: "Chặn" thì hỏi trước khi ghi khoản làm vượt,
    // "Cảnh báo" thì ghi luôn rồi báo. Đây là nơi DUY NHẤT đọc `OverSpending`.
    final impact = await _budgetImpactFor(tx, editing);
    if (!context.mounted) return;
    if (impact != null && impact.requiresConfirmation) {
      final ok = await _confirmOverBudget(context, impact);
      if (ok != true || !context.mounted) return;
    }
    _pendingImpact = impact;

    if (editing != null) {
      bloc.add(UpdateTransactionEvent(before: editing, after: tx));
      return;
    }
    _cubit.ghiPhanHoiKhiLuu();
    bloc.add(AddTransactionEvent(
      transaction: tx,
      destinationWalletId: tx.walletTransfer,
    ));
  }

  /// A5 mục 11.4–11.5 — lưu khoản đã tách: kiểm hợp lệ, ngân sách TỪNG phần (một hộp cho cả lô nếu có ngân sách
  /// *Chặn* bị vượt), rồi MỘT `AddTransactionsEvent`.
  Future<void> _luuTach(BuildContext context, TransactionEntity tx, double tong) async {
    final loi = kiemTach(tong: tong, chinh: tx.categoryId, phan: _phanTach);
    if (loi != null) {
      baoNhanh(
        switch (loi) {
          LoiTach.conLaiKhongDuong => 'Phần còn lại phải lớn hơn 0',
          LoiTach.phanKhongDuong => 'Mỗi phần phải lớn hơn 0',
          LoiTach.trungDanhMuc => 'Mỗi danh mục chỉ một phần',
          LoiTach.monHaiPhan => 'Một món chỉ thuộc một phần',
        },
        loai: LoaiThongBao.loi,
      );
      return;
    }
    final ds = dungGiaoDichTach(mau: tx, phan: _phanTach);
    final impacts = <BudgetImpact>[];
    for (final t in ds) {
      final i = await _budgetImpactFor(t, null);
      if (i != null) impacts.add(i);
    }
    if (!context.mounted) return;
    final chan = [for (final i in impacts) if (i.requiresConfirmation) i];
    if (chan.isNotEmpty) {
      final ok = await _xacNhanVuotNhieu(context, chan);
      if (ok != true || !context.mounted) return;
    }
    _pendingImpact = impacts.where((i) => i.exceeds || i.nearLimitAfter).firstOrNull;
    _soGiaoDichVuaLuu = ds.length;
    _cubit.ghiPhanHoiKhiLuu();
    context.read<TransactionBloc>().add(AddTransactionsEvent(transactions: ds));
  }

  Future<bool?> _xacNhanVuotNhieu(BuildContext context, List<BudgetImpact> chan) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vượt ngân sách'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in chan)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(budgetImpactDialogText(i))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Vẫn ghi')),
          ],
        ),
      );

  /// Mở sheet *Thêm phần* (thêm mới, hoặc sửa [sua]). Danh mục chọn được: danh mục CHI hợp lệ; sheet bỏ danh mục chính
  /// và danh mục của phần khác.
  Future<void> _themPhan([PhanTach? sua]) async {
    final chi = await _cubit.danhMucChoTach();
    if (!mounted) return;
    final p = await moSheetThemPhan(
      context,
      chonDuoc: chi,
      daDung: {
        if (_selectedCategory != null) _selectedCategory!.id,
        for (final x in _phanTach) x.categoryId,
      },
      dangSua: sua,
      mon: _s.monQuet,
      // Món đã thuộc phần KHÁC (không phải phần đang sửa) → mờ, không tick được.
      monCuaPhanKhac: {
        for (final x in _phanTach)
          if (x != sua)
            for (final id in x.monIds) id: _dmTheoId[x.categoryId]?.name ?? 'Phần khác',
      },
    );
    if (p == null || !mounted) return;
    _cubit.luuPhan(p, thay: sua);
  }

  Future<BudgetImpact?> _budgetImpactFor(
    TransactionEntity tx,
    TransactionEntity? editing,
  ) async {
    final categoryId = tx.categoryId;
    if (tx.type != 'chi' || categoryId == null) return null;

    BudgetView? view;
    try {
      view = await _nguon.traNganSach(tx.idaccount, categoryId);
    } catch (_) {
      // Tra ngân sách hỏng không được chặn việc ghi giao dịch.
      return null;
    }
    if (view == null) return null;

    final now = DateTime.now();
    // Sửa: số cũ đã nằm trong "đã chi" nếu nó cùng danh mục và cùng kỳ —
    // phải trừ ra, không thì báo vượt oan.
    var previous = 0.0;
    if (editing != null &&
        editing.type == 'chi' &&
        editing.categoryId == categoryId &&
        budgetPeriodContains(view.budget, editing.date, now)) {
      previous = editing.amount;
    }
    return budgetImpactOf(
      view: view,
      amount: tx.amount,
      previousAmount: previous,
      date: tx.date,
      now: now,
    );
  }

  Future<bool?> _confirmOverBudget(BuildContext context, BudgetImpact impact) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vượt ngân sách'),
        content: Text(budgetImpactDialogText(impact)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Vẫn ghi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nghe GoiCubit để gói đổi giữa lúc form mở (lên Premium qua socket) là ô Nhập nhanh mở ngay. Không provider
    // (test cũ) thì bỏ qua — xem [AddTransactionPage.laPremium].
    if (widget.laPremium == null) {
      try {
        context.watch<GoiCubit>();
      } on ProviderNotFoundException {
        // Không có GoiCubit trong cây.
      }
    }
    final content = BlocConsumer<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionLoadedState) {
          if (state.actionSuccess == true) {
            // Lời nhắn về ngân sách thay lời nhắn mặc định — chung chung,
            // không con số (banner tạm thời tối giản theo ý người dùng).
            final soGd = _soGiaoDichVuaLuu;
            _soGiaoDichVuaLuu = 1;
            final impactGoc = budgetImpactSnackText(_pendingImpact);
            final impactText = soGd > 1 ? impactGoc?.replaceFirst('Đã lưu.', 'Đã lưu $soGd giao dịch.') : impactGoc;
            _pendingImpact = null;
            // Lưu kèm cảnh báo ngân sách ("Đã lưu. Ngân sách X đã vượt hạn mức.") là
            // THÔNG TIN, không phải xong trơn.
            baoNhanh(
              impactText ??
                  (_isEditing ? 'Đã lưu thay đổi' : (soGd > 1 ? 'Đã lưu $soGd giao dịch' : 'Thêm giao dịch thành công!')),
              loai: impactText == null ? LoaiThongBao.xong : LoaiThongBao.thongTin,
            );
            unawaited(_cubit.dongSauLuu());
            context.pop(true);
          } else if (state.actionSuccess == false &&
              state.errorMessage != null) {
            baoNhanh('Lỗi: ${state.errorMessage}', loai: LoaiThongBao.loi);
          }
        }
      },
      builder: (context, state) => BlocBuilder<ThemGiaoDichCubit, ThemGiaoDichState>(
        bloc: _cubit,
        builder: (context, _) {
        final isSubmitting = state is TransactionLoadedState && state.isSubmitting;
        final coBanPhimSo = _coBanPhimSo(context);
        // MỘT luật cho nút lưu: 16 phím (mang phím ✓) không trên màn thì ✓ ở thanh tiêu đề — cả khi ẩn theo cờ lẫn
        // khi bàn phím hệ thống đang mở (G58; trước 2026-09-30 lúc gõ ghi chú là không có nút lưu nào).
        final luuTieuDe = coBanPhimSo
            ? null
            : IconButton(
                key: const Key('luu-thanh-tieu-de'),
                tooltip: _phanTach.isEmpty ? 'Lưu giao dịch' : 'Lưu ${_phanTach.length + 1} giao dịch',
                icon: const Icon(Icons.check, color: AppColors.primary),
                onPressed: isSubmitting ? null : () => _saveTransaction(context),
              );
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Quay lại',
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.primary, size: 28),
              onPressed: () => context.pop(),
            ),
            // Co chữ khi chật (G80): ở 320 dp, ✓ và ⋮ (thêm "Bỏ qua" khi mở
            // từ biến động) chiếm chỗ và tiêu đề từng bị cắt "Thêm giao dị…".
            // Màn rộng thì FittedBox ôm khít chữ — cỡ gốc không đổi.
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ),
            actions: [
              if (_bienDong != null) ...[
                // D1 (Stitch `52d9d2ef…`): bỏ qua hàng biến động — xoá nó, không tạo giao dịch.
                TextButton(
                  onPressed: _boQuaBienDong,
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (luuTieuDe != null) luuTieuDe,
              ] else ...[
                if (luuTieuDe != null) luuTieuDe,
                IconButton(
                  tooltip: 'Thêm tuỳ chọn',
                  icon: const Icon(Icons.more_vert, color: AppColors.primary),
                  onPressed: () {},
                ),
              ],
            ],
          ),
          // Thanh chọn và con số CỐ ĐỊNH ở trên, bàn phím NEO ĐÁY, chỉ thẻ form
          // ở giữa cuộn — theo màn Stitch "Thêm giao dịch - Bàn phím neo đáy"
          // (`acf6f17e…`, 2026-09-19; UX C1/C2). Bản trước đặt cả bàn phím
          // trong vùng cuộn: ở 411dp phải cuộn mới thấy 1-2-3 / 0 / 000 / ✓, và
          // cuộn tới thì con số đang gõ trôi khỏi màn. Phím ✓ là nút lưu; nút
          // "Lưu giao dịch" riêng đã bỏ.
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ThanhChonChieu(huong: _huong, onChon: _chonHuong),
                ),
                const SizedBox(height: 16),
                KhoiSoTien(
                  chuoiSoTien: _amountString,
                  chuHienThi: _getFormattedAmount(),
                  mau: _getAmountColor(),
                  hienBanPhimSo: _hienBanPhimSo,
                  onCham: _chamSoTien,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('vung-cuon-form'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    // C2: ô Nhập nhanh ở ĐẦU vùng cuộn, không cố định — ở 360 × 640 vùng giữa đã chật, một ô cố định
                    // nữa là thẻ form còn chưa tới 70 dp. Chỉ ở đường tạo mới (spec §3).
                    child: Column(
                      children: [
                        // D1: form đã điền từ tin — không có ô Nhập nhanh (đường điền thứ hai), thay bằng dải nguồn.
                        if (_bienDong case final d?) ...[
                          DaiNguonBienDong(d: d, duongDanAnh: _s.duongDanAnh),
                          const SizedBox(height: 12),
                          if (d.luaChonTien.isNotEmpty) ...[
                            KhoiChonSoTien(
                              ds: d.luaChonTien,
                              dangChon: ketQuaBieuThuc(_amountString),
                              onChon: _cubit.chonSoTien,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_s.goiYChuyen case final gy? when !_s.laChuyen) ...[
                            TheGoiYChuyen(gy: gy, onApDung: _cubit.apGoiYChuyen),
                            const SizedBox(height: 12),
                          ],
                        ] else if (!_isEditing) ...[
                          ONhapNhanh(
                            controller: _nhapNhanhController,
                            focusNode: _nhapNhanhFocus,
                            laPremium: _laPremium,
                            dangDocAi: _s.dangDocAi,
                            ketQua: _s.ketQuaDien,
                            onDien: _dienTuCau,
                            onHuy: _huyDocAi,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _theForm(context),
                        if (_s.choTach && _phanTach.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          KhoiTach(
                            chinh: _selectedCategory,
                            tong: ketQuaBieuThuc(_amountString),
                            phan: _phanTach,
                            danhMuc: _dmTheoId,
                            onSua: _themPhan,
                            onBo: _cubit.boPhan,
                            onThem: _themPhan,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // G58 (2026-09-29): bàn phím HỆ THỐNG mở — người dùng đang gõ
                // ghi chú — thì không dựng 16 phím số. Ở 360 dp, thân còn ~400
                // dp; giữ 16 phím (~240 dp) là ép thẻ form về 0, tức ô đang gõ
                // biến mất, và hàng phím cuối tràn. Đóng bàn phím hệ thống thì
                // phím số và ✓ (nút lưu) quay lại. Người dùng chọn lối này; màn
                // Stitch `acf6f17e…` chỉ vẽ trạng thái không có bàn phím hệ thống.
                // Từ 2026-09-30 còn ẩn khi màn đã có số tiền ([_hienBanPhimSo]); ✓ khi ấy ở thanh tiêu đề.
                // 2026-10-06 (Stitch `fb68baba…`): 16 phím do app tự vẽ, hệ điều hành
                // không báo `viewInsets` — báo chiều cao cho AppToast để viên lỗi lúc
                // bấm ✓ nổi TRÊN bàn phím thay vì đè hai hàng phím dưới.
                if (coBanPhimSo)
                  BaoCheDayToast(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: BanPhimSo(
                        isSubmitting: isSubmitting,
                        onKey: _onKeyPress,
                        onLuu: () => _saveTransaction(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        },
      ),
    );
    // Thẻ nguồn số tiền vừa hiện / đổi danh mục → cuộn thẻ vào khung nhìn (Cubit tăng `soLanCuonGoiY`).
    final coCuon = BlocListener<ThemGiaoDichCubit, ThemGiaoDichState>(
      bloc: _cubit,
      listenWhen: (a, b) => a.soLanCuonGoiY != b.soLanCuonGoiY,
      listener: (_, __) => _cuonToiTheGoiY(),
      child: content,
    );
    final coGhiChu = BlocListener<ThemGiaoDichCubit, ThemGiaoDichState>(
      bloc: _cubit,
      // CHỈ khi Cubit tự đặt ghi chú (bộ đếm) — nghe mọi lần `ghiChu` đổi thì một state về muộn đè chữ vừa gõ.
      listenWhen: (a, b) => a.soLanDatGhiChu != b.soLanDatGhiChu,
      listener: (_, s) {
        if (_noteController.text != s.ghiChu) _noteController.text = s.ghiChu;
      },
      child: coCuon,
    );
    final transactionBloc = widget.transactionBloc;
    return transactionBloc == null
        ? BlocProvider<TransactionBloc>(
            create: (context) => sl<TransactionBloc>(),
            child: coGhiChu,
          )
        : BlocProvider<TransactionBloc>.value(
            value: transactionBloc,
            child: coGhiChu,
          );
  }

  /// 16 phím có trên màn không: cờ [_hienBanPhimSo] **và** bàn phím hệ thống đang đóng (G58).
  bool _coBanPhimSo(BuildContext context) => _hienBanPhimSo && MediaQuery.viewInsetsOf(context).bottom == 0;

  /// Chạm khối số tiền. Bàn phím hệ thống đang mở (gõ ghi chú) thì 16 phím bị G58 giấu dù cờ bật — đảo cờ lúc ấy
  /// là tắt phím đi mà người dùng không thấy gì đổi; nên đóng bàn phím hệ thống và MỞ 16 phím.
  void _chamSoTien() {
    final banPhimHeThong = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (banPhimHeThong) FocusScope.of(context).unfocus();
    _cubit.chamSoTien(banPhimHeThongMo: banPhimHeThong);
  }

  /// Lắp [TheForm] từ trạng thái của trang: chuỗi hiển thị, các khối phụ (slot) và những lời gọi đổi trạng thái.
  Widget _theForm(BuildContext context) {
    final s = _s.goiY; // bắt một lần lúc dựng — callback không đọc lại `goiY` lúc chạm
    final selectedCategory = _selectedCategory;
    final showDebtDirection = selectedCategory != null && isDebtClassify(selectedCategory.classify);
    final walletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_selectedWallet != null
            ? '${_selectedWallet!.name} • ${CurrencyFormatter.formatLienKhoi(_selectedWallet!.balance)}'
            : 'Chọn ví');

    final destWalletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_destinationWallet != null
            ? '${_destinationWallet!.name} • ${CurrencyFormatter.formatLienKhoi(_destinationWallet!.balance)}'
            : 'Chọn ví đích');

    return TheForm(
      isTransfer: _s.laChuyen,
      walletDisplay: walletDisplay,
      destWalletDisplay: destWalletDisplay,
      tenDanhMuc: selectedCategory?.name,
      nhanDanhMuc: _phanTach.isEmpty ? 'Danh mục' : 'Danh mục chính',
      noteController: _noteController,
      // D1: giờ trong tin là giờ giao dịch — hiện ra để người dùng thấy nó được giữ.
      ngayHienThi: DateFormat(_bienDong != null ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy').format(_selectedDate),
      onChonVi: () => _moChonVi(context, isDestination: false),
      onChonViDich: () => _moChonVi(context, isDestination: true),
      onChonDanhMuc: () async {
        // Mở đúng tab của danh mục đang chọn; lần đầu thì tab chi.
        final selected = await context.push<Category>(
          '/add/category',
          // Chưa có danh mục thì mở tab của đoạn đang chọn (C3).
          extra: selectedCategory?.classify ?? (_huong == 'thu' ? 'thu' : kCategoryClassifies.first),
        );
        if (selected != null) _chonDanhMuc(selected);
      },
      onPickDate: _pickDate,
      hienDongTach: _s.choTach && _phanTach.isEmpty,
      onThemPhan: _themPhan,
      nhacTrung:
          _bienDong != null && _s.trungTrongSo.isNotEmpty ? NhacTrung(d: _bienDong!, trung: _s.trungTrongSo) : null,
      deXuatTuKhoa: _s.deXuat != null || _s.daThemTuKhoa != null
          ? DongDeXuatTuKhoa(
              daThem: _s.daThemTuKhoa,
              deXuat: _s.deXuat,
              onChapNhan: _cubit.chapNhanDeXuat,
              onBoQua: _cubit.boQuaDeXuat,
            )
          : null,
      hangChieuTien: showDebtDirection
          ? HangChieuTien(
              chieu: _debtDirection,
              onChon: _cubit.chonChieuNo,
            )
          : null,
      theGoiY: s == null
          ? null
          : TheGoiYDanhMuc(
              key: _khoaTheGoiY,
              suggestion: s,
              onBoQua: () => _cubit.boQuaGoiY(s),
              onChon: () => _cubit.chonGoiY(s),
            ),
    );
  }
}

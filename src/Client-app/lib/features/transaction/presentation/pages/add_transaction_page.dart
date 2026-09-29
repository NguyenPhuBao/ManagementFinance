import 'dart:async';
import '../../../../core/utils/currency_formatter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/category/category_classify.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../budget/data/models/budget_entity.dart';
import '../../../budget/data/repositories/budget_repository.dart';
import '../../domain/ban_phim_so_tien.dart';
import '../../domain/doc_cau_giao_dich.dart';
import '../../data/doc_cau_bang_ai.dart';
import '../widgets/so_tien_lon.dart';
import '../../../budget/domain/budget_impact.dart';
import '../../../wallet/domain/wallet_type.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/category/data/goi_y_phan_hoi_store.dart';
import '../../../../features/category/data/models/category_suggestion.dart';
import '../../../../features/category/data/repositories/category_management_repository.dart';
import '../../../../features/category/data/services/category_suggestion_engine.dart';
import '../../../../features/category/domain/phan_loai_ghi_chu.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/vi_chon_san.dart';
import '../../domain/vi_hay_dung.dart';
import '../../data/models/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

/// Dữ liệu mở trang ở chế độ SỬA: giao dịch gốc và danh mục của nó (đã tra
/// sẵn ở nơi gọi, vì entity chỉ giữ `categoryId`). Đi qua `extra` của route
/// `/add`.
/// Xem [AddTransactionPage.budgetLookup].
typedef BudgetLookup = Future<BudgetView?> Function(
  int idaccount,
  String categoryId,
);

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
    this.phanHoiGoiY,
    this.docAi,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  /// Đoạn đang chọn trên thanh đầu màn: `'chi'` | `'thu'` | `'transfer'` —
  /// theo màn Stitch "Chi tiêu · Thu nhập · Chuyển khoản" (UX 2026-09-19, C3).
  ///
  /// ⚠️ Đây là **lối vào**, không phải sự thật. `type` ghi xuống SQLite vẫn suy
  /// từ danh mục ([_resolvedType], luật 2026-09-05): chọn Chi/Thu chỉ đặt tab
  /// mà bảng danh mục mở và bỏ danh mục đang chọn nếu nó thuộc chiều kia; chọn
  /// một danh mục thì đoạn **nhảy theo** danh mục. Với danh mục vay/nợ (gom cả
  /// hai chiều), đoạn Chi/Thu chính là công tắc "Chiều tiền" — hai chỗ ấy luôn
  /// cùng một giá trị. Từ 2026-09-05 tới 2026-09-19 thanh này chỉ có "Giao
  /// dịch / Chuyển khoản" — đi lệch Stitch.
  String _huong = 'chi';
  String _amountString = "0";

  List<Wallet> _wallets = [];
  /// Bảng ví hay dùng, rỗng khi chưa đủ căn cứ hoặc chưa nạp xong.
  Map<String, String> _viHayDung = const {};

  /// Mô hình học từ ghi chú; `null` khi chưa nạp xong hoặc học lỗi — khi ấy thẻ gợi ý rơi về bảng từ khoá.
  BoPhanLoaiGhiChu? _boPhanLoai;

  /// Cặp (cụm, danh mục) đang bị thôi gợi ý (`tatCapTu`) — nạp một lần sau khi có mô hình.
  Set<(String, String)> _tatCap = const {};

  /// Gợi ý đã HIỆN mà người dùng chưa phân xử, kèm ghi chú lúc nó hiện.
  ///
  /// ⚠️ Tách khỏi [_suggestion]: [_chonDanhMuc] xoá thẻ ngay khi người dùng chọn qua bảng, nhưng lựa chọn ấy CHÍNH
  /// LÀ phán xét (`khac`) — ghi lúc lưu. Ghi chú đổi / đổi đoạn thì bỏ, không ghi (không phải phán xét).
  ({CategorySuggestion goiY, String ghiChu})? _choPhanXu;

  GoiYPhanHoiStore? get _phanHoiStore =>
      widget.phanHoiGoiY ?? (sl.isRegistered<GoiYPhanHoiStore>() ? sl<GoiYPhanHoiStore>() : null);

  /// Người dùng đã tự tay đặt ví nguồn trong lượt này chưa.
  ///
  /// ⚠️ Chốt quan trọng nhất của chặng 1.2: một phép đoán từ lịch sử **không
  /// bao giờ** được đè lên lựa chọn người dùng vừa làm. Thiếu cờ này thì chọn
  /// ví rồi chọn danh mục sẽ thấy ví tự nhảy về chỗ khác — và người dùng thôi
  /// tin ô chọn ví, phải kiểm nó mỗi lần ghi.
  bool _nguoiDungDaChonVi = false;

  Wallet? _selectedWallet;
  Wallet? _destinationWallet;
  Category? _selectedCategory;
  CategorySuggestion? _suggestion;

  /// Chiều tiền người dùng chọn khi danh mục là vay/nợ: `'chi'` (tiền ra) hoặc
  /// `'thu'` (tiền vào). `null` với mọi danh mục khác. Được gợi sẵn theo tên
  /// danh mục lúc chọn ([_chonDanhMuc]) và đổi bằng công tắc trên form.
  String? _debtDirection;

  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoadingWallets = true;

  /// Ô *Nhập nhanh* (C2) — chỉ ở đường tạo mới.
  final TextEditingController _nhapNhanhController = TextEditingController();

  /// Kết quả lần *Điền* gần nhất, để dựng dòng tóm tắt dưới ô; `null` khi chưa điền lần nào.
  ({String tomTat, bool docDuoc, bool quaAi, List<String> canhBao, String? lyDo})? _ketQuaDien;
  bool _dangDien = false;

  /// Đang chờ mô hình đọc câu (C2 §2.8) — ô hiện *"Đang đọc bằng AI…"* kèm Huỷ.
  bool _dangDocAi = false;

  /// Mỗi lần Điền / Huỷ một số mới: kết quả AI về muộn của lượt đã huỷ thì bỏ.
  var _luotDien = 0;

  /// Ô Nhập nhanh có focus → nạp mô hình ngầm (người dùng chốt 2026-09-30).
  final FocusNode _nhapNhanhFocus = FocusNode();

  DocCauBangAi? get _docAi =>
      widget.docAi ?? (sl.isRegistered<DocCauBangAi>() ? sl<DocCauBangAi>() : null);

  /// Tác động lên ngân sách của khoản vừa gửi đi, để listener chọn lời nhắn
  /// sau khi lưu xong. Đặt ngay trước khi gửi event, xoá ngay khi đã dùng.
  BudgetImpact? _pendingImpact;

  CategoryManagementRepository get _categoryRepository =>
      widget.categoryRepository ?? sl<CategoryManagementRepository>();

  TransactionEntity? get _editing => widget.initial?.transaction;
  bool get _isEditing => _editing != null;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    if (editing != null) {
      // Điền sẵn TRƯỚC khi gắn listener ghi chú, để lần gán text đầu không
      // kích hoạt tra cứu gợi ý.
      _huong = editing.type;
      _amountString = editing.amount == editing.amount.roundToDouble()
          ? editing.amount.toInt().toString()
          : editing.amount.toString();
      _selectedDate = editing.date;
      _noteController.text = editing.note;
      final category = widget.initial?.category;
      if (category != null) {
        _selectedCategory = category;
        // Chiều tiền đã chọn lúc tạo nằm ở `type`; không gợi lại theo tên.
        _debtDirection =
            isDebtClassify(category.classify) ? editing.type : null;
      }
    } else if (const {'chi', 'thu', 'transfer'}.contains(widget.huongBanDau)) {
      _huong = widget.huongBanDau!;
    }
    _noteController.addListener(_onNoteChanged);
    _nhapNhanhFocus.addListener(() {
      if (_nhapNhanhFocus.hasFocus) unawaited(_docAi?.chuanBi());
    });
    _loadWallets();
    _loadViHayDung().then((_) => _napTatCap());
  }

  /// Đọc phản hồi cũ → cặp đang bị thôi gợi ý. Lỗi thì bỏ qua: thẻ vẫn gợi ý như chưa ai từng bỏ qua.
  Future<void> _napTatCap() async {
    final bo = _boPhanLoai;
    final store = _phanHoiStore;
    final id = _accountId();
    if (bo == null || store == null || id == null) return;
    try {
      final tat = tatCapTu(await store.doc(id), bo.mau);
      if (mounted) setState(() => _tatCap = tat);
    } catch (e) {
      debugPrint('[GoiYDanhMuc] đọc phản hồi lỗi: $e');
    }
  }

  /// Ghi một phản hồi. `unawaited` + `catchError`: phản hồi hỏng KHÔNG được chặn việc chọn hay lưu giao dịch.
  void _ghiPhanHoi(CategorySuggestion goiY, String ketQua, {String? chon}) {
    final store = _phanHoiStore;
    final id = _accountId();
    if (store == null || id == null) return;
    unawaited(store
        .ghi(idaccount: id, goiY: goiY, ketQua: ketQua, chonCategoryId: chon)
        .catchError((Object e) => debugPrint('[GoiYDanhMuc] ghi phản hồi lỗi: $e')));
  }

  /// Chọn sẵn ví nguồn và ví đích theo cờ "Ví mặc định".
  ///
  /// Luật nằm ở `vi_chon_san.dart` để test được không cần dựng cả trang này.
  void _apDungViChonSan() {
    final chon = chonViChonSan<Wallet>(
      _wallets,
      laMacDinh: (w) => w.isDefault,
    );
    _selectedWallet = chon.nguon;
    _destinationWallet = chon.dich;
  }

  /// Ở chế độ sửa, ví của giao dịch phải thắng ví đầu danh sách.
  void _apDungViDangSua() {
    final editing = _editing;
    if (editing == null) return;
    Wallet? find(String? id) {
      if (id == null) return null;
      for (final w in _wallets) {
        if (w.id == id) return w;
      }
      return null;
    }

    _selectedWallet = find(editing.walletId) ?? _selectedWallet;
    _destinationWallet = find(editing.walletTransfer) ?? _destinationWallet;
  }

  @override
  void dispose() {
    _hoanGoiY?.cancel();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _nhapNhanhController.dispose();
    _nhapNhanhFocus.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    final configuredWallets = widget.wallets;
    if (configuredWallets != null) {
      setState(() {
        _wallets = configuredWallets;
        _apDungViChonSan();
        _apDungViDangSua();
        _isLoadingWallets = false;
      });
      return;
    }
    final userIdAccount = _accountId();
    if (userIdAccount == null) {
      // Chưa có phiên: không đọc ví của ai cả. Danh sách rỗng làm chốt
      // "Vui lòng chọn ví thanh toán" chặn lưu, nên không có đường nào ghi
      // giao dịch dưới danh nghĩa admin qua ngả này.
      if (mounted) setState(() => _isLoadingWallets = false);
      return;
    }

    final db = sl<AppDatabase>();
    final list = await db.walletDao.getActive(userIdAccount);

    if (mounted) {
      setState(() {
        _wallets = list;
        _apDungViChonSan();
        _apDungViDangSua();
        _isLoadingWallets = false;
      });
    }
  }

  /// Mã tài khoản của phiên, hoặc `null` khi CHƯA có phiên dùng được.
  ///
  /// ⚠️ Trước 2026-09-14 hàm này rơi về `widget.idaccount`, vốn mặc định `1` —
  /// **tài khoản admin thật**. Đây là đường **GHI** giao dịch, nên hậu quả
  /// nặng nhất trong ba trang cùng lỗi: giao dịch ghi dưới danh nghĩa admin
  /// rồi đẩy lên và vỡ "Ownership mismatch" — đúng kịch bản mà docstring
  /// `core/auth/current_account.dart` mô tả khi G4 được đóng. Nó lọt lưới quét
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

  bool get _isTransfer => _huong == 'transfer';

  /// Giá trị `type` sẽ ghi xuống SQLite (`chi` | `thu` | `transfer`), suy từ
  /// loại giao dịch và danh mục đã chọn. `null` khi chưa đủ dữ kiện.
  ///
  /// Backend chỉ có hai loại (`Transaction` ± amount, `Transfer`); bộ giá trị
  /// nội bộ này được `SyncPayloadNormalizer` quy đổi, nên giữ nguyên nó là
  /// giữ nguyên hợp đồng đồng bộ, DAO và mọi chỗ thống kê đọc `type`.
  String? get _resolvedType {
    if (_isTransfer) return 'transfer';
    final category = _selectedCategory;
    if (category == null) return null;
    if (isDebtClassify(category.classify)) return _debtDirection;
    return category.classify == 'thu' ? 'thu' : 'chi';
  }

  /// Đường DUY NHẤT để đặt danh mục — cả bảng chọn lẫn thẻ gợi ý đều qua đây,
  /// để chiều tiền vay/nợ luôn được gợi sẵn kèm theo.
  void _chonDanhMuc(Category category) {
    setState(() {
      _selectedCategory = category;
      _apDungViHayDung(category);
      _suggestion = null;
      final laVayNo = isDebtClassify(category.classify);
      _debtDirection = laVayNo ? suggestDebtDirection(category.name) : null;
      // Danh mục là sự thật, đoạn đầu màn phản ánh nó — không được nói ngược.
      _huong = laVayNo
          ? (_debtDirection ?? 'chi')
          : (category.classify == 'thu' ? 'thu' : 'chi');
    });
  }

  /// Đổi ví chọn sẵn sang ví người dùng **hay dùng** cho [category].
  ///
  /// Ba cửa chặn, thiếu cửa nào cũng hỏng theo một kiểu riêng:
  /// - **đang sửa** → ví của giao dịch đã ghi là sự thật, phép đoán không có
  ///   quyền chen vào;
  /// - **người dùng đã tự đặt ví** → lựa chọn cố ý thắng phép đoán;
  /// - **tra không thấy** → `null` nghĩa là *chưa biết*, phải **giữ nguyên** ví
  ///   đang có chứ không đổi sang ví mặc định hay ví đầu danh sách.
  ///
  /// Gọi trong `setState` của [_chonDanhMuc] nên tự nó không `setState`.
  void _apDungViHayDung(Category category) {
    if (_editing != null || _nguoiDungDaChonVi) return;
    final viId = _viHayDung[category.id];
    if (viId == null) return;
    for (final w in _wallets) {
      if (w.id == viId) {
        _selectedWallet = w;
        return;
      }
    }
  }

  /// Dựng bảng ví hay dùng từ lịch sử giao dịch của chính tài khoản này.
  ///
  /// Một lượt đọc lúc mở trang, rồi [_chonDanhMuc] chỉ tra bảng — nó chạy trong
  /// `setState` nên không chờ được `await`.
  ///
  /// Cùng lượt đọc ấy học luôn mô hình gợi ý danh mục (B1) — MỘT lần đọc sổ cho hai bảng.
  Future<void> _loadViHayDung() async {
    // Đặt TRƯỚC mọi nhánh thoát sớm: ca test tiêm mô hình cùng lúc tiêm `wallets`.
    if (widget.boPhanLoai != null) _boPhanLoai = widget.boPhanLoai;
    final tiem = widget.viHayDung;
    if (tiem != null) {
      _viHayDung = tiem;
      return;
    }
    // Ca test tiêm sẵn `wallets`; khi ấy không đụng SQLite, đúng như đường ví.
    if (widget.wallets != null) return;
    final userIdAccount = _accountId();
    if (userIdAccount == null) return;
    final txs = await sl<AppDatabase>().transactionDao.getAll(userIdAccount);
    final bang = viHayDungTheoDanhMuc(demViTheoDanhMuc([
      for (final t in txs) (categoryId: t.categoryId, walletId: t.walletId),
    ]));
    BoPhanLoaiGhiChu? bo = widget.boPhanLoai;
    if (bo == null) {
      try {
        bo = BoPhanLoaiGhiChu.hoc(mauHocTu([
          for (final t in txs) (loai: t.type, categoryId: t.categoryId, ghiChu: t.note, ngay: t.date),
        ]));
      } catch (e) {
        // Học lỗi → rơi về bảng từ khoá, không toast (spec B1 mục 6).
        debugPrint('[GoiYDanhMuc] học mô hình lỗi: $e');
        bo = null;
      }
    }
    if (mounted) {
      setState(() {
        _viHayDung = bang;
        _boPhanLoai = bo;
      });
    }
  }

  /// Chạm một đoạn Chi tiêu / Thu nhập / Chuyển khoản.
  void _chonHuong(String huong) {
    setState(() {
      _huong = huong;
      _suggestion = null;
      _choPhanXu = null;
      final cat = _selectedCategory;
      if (huong == 'transfer' || cat == null) return;
      if (isDebtClassify(cat.classify)) {
        // Vay/nợ gom cả hai chiều: đoạn chính là công tắc chiều tiền.
        _debtDirection = huong;
      } else if ((cat.classify == 'thu' ? 'thu' : 'chi') != huong) {
        // Giữ danh mục chi dưới đoạn Thu là hai sự thật trái nhau.
        _selectedCategory = null;
      }
    });
  }

  /// C2 — đọc câu ở ô *Nhập nhanh* (`docCauGiaoDich`) rồi ĐIỀN SẴN những ô đọc được; ô không đọc được giữ nguyên.
  /// Bất biến ④ nhóm C: không lưu — người dùng xem lại rồi bấm ✓.
  ///
  /// Mỗi ô đi qua ĐÚNG đường người dùng vẫn đi, để mọi hệ quả chạy như khi chạm tay:
  /// - chiều qua [_chonHuong] (bỏ danh mục thuộc chiều kia) — gán thẳng `_huong` là để danh mục chi dưới đoạn Thu;
  /// - số tiền qua `themPhimSoTien` từng chữ số (cùng trần 13 chữ số, không để biểu thức dở);
  /// - ví đọc từ câu đặt [_nguoiDungDaChonVi] — luật ví hay dùng theo danh mục không được đè lựa chọn trong câu;
  /// - danh mục qua [_chonDanhMuc] (chiều vay/nợ, đoạn Chi/Thu, xoá thẻ gợi ý);
  /// - ghi chú đặt SAU danh mục: [_onNoteChanged] thấy đã có danh mục thì không hẹn gợi ý;
  /// - danh mục đến từ B1 thì đặt [_choPhanXu] như thẻ gợi ý, để lúc lưu ghi phản hồi `chon` / `khac`.
  Future<void> _dienTuCau() async {
    final cau = _nhapNhanhController.text.trim();
    if (cau.isEmpty || _dangDien) return;
    _dangDien = true;
    final luot = ++_luotDien;
    FocusScope.of(context).unfocus();
    final id = _accountId();
    var chonDuoc = const <Category>[];
    if (id != null) {
      try {
        chonDuoc = await _categoryRepository.selectableChildrenAll(accountId: id);
      } catch (e) {
        debugPrint('[NhapNhanh] đọc danh mục lỗi: $e');
      }
    }
    // C2 §2.8 — "AI đọc mọi câu": máy dùng được AI thì hỏi mô hình trước, rồi luật kiểm từng ô của nó.
    KetQuaAi? ai;
    final docAi = _docAi;
    if (docAi != null && mounted && await docAi.sanSang()) {
      if (!mounted || luot != _luotDien) return;
      setState(() => _dangDocAi = true);
      ai = await docAi.doc(
        cau,
        now: DateTime.now(),
        tenVi: [for (final w in _wallets) w.name],
        tenDanhMuc: [for (final c in chonDuoc) if (!c.isDeleted && !c.isGroup) c.name],
      );
    }
    // Người dùng đã bấm Huỷ — lượt ấy đã điền bằng luật.
    if (!mounted || luot != _luotDien) return;
    _dangDien = false;
    if (_dangDocAi) setState(() => _dangDocAi = false);
    _apDungKetQua(cau, chonDuoc, ai: ai);
  }

  /// Huỷ lượt đọc bằng AI: điền ngay bằng luật, mô hình thôi giải mã.
  Future<void> _huyDocAi() async {
    _luotDien++;
    unawaited(_docAi?.huy());
    final cau = _nhapNhanhController.text.trim();
    final id = _accountId();
    var chonDuoc = const <Category>[];
    if (id != null) {
      try {
        chonDuoc = await _categoryRepository.selectableChildrenAll(accountId: id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _dangDien = false;
      _dangDocAi = false;
    });
    if (cau.isNotEmpty) _apDungKetQua(cau, chonDuoc);
  }

  /// Điền những ô đọc được vào form (xem [_dienTuCau]).
  void _apDungKetQua(String cau, List<Category> chonDuoc, {KetQuaAi? ai}) {
    final now = DateTime.now();
    final kq = docCauGiaoDich(cau, now: now, vi: _wallets, chonDuoc: chonDuoc, mo: _boPhanLoai, tatCap: _tatCap, ai: ai);
    if (kq.khongDocDuocGi) {
      setState(() => _ketQuaDien =
          (tomTat: kCauChuaDocDuoc, docDuoc: false, quaAi: kq.quaAi, canhBao: kq.canhBao, lyDo: null));
      return;
    }

    final loai = kq.loai;
    if (loai != null && loai != _huong) _chonHuong(loai);
    Wallet? vi;
    for (final w in _wallets) {
      if (w.id == kq.walletId) vi = w;
    }
    setState(() {
      final soTien = kq.soTien;
      if (soTien != null) {
        var a = '0';
        for (final c in soTien.toInt().toString().split('')) {
          a = themPhimSoTien(a, c);
        }
        _amountString = a;
      }
      final ngay = kq.ngay;
      if (ngay != null) {
        _selectedDate = DateTime(ngay.year, ngay.month, ngay.day, _selectedDate.hour, _selectedDate.minute);
      }
      if (vi != null) {
        _selectedWallet = vi;
        _nguoiDungDaChonVi = true;
      }
    });
    Category? danhMuc;
    if (!_isTransfer && kq.categoryId != null) {
      for (final c in chonDuoc) {
        if (c.id == kq.categoryId) danhMuc = c;
      }
      if (danhMuc != null) _chonDanhMuc(danhMuc);
    }
    // Rỗng = câu chỉ có số / ngày / ví: ghi chú người dùng đã gõ giữ nguyên.
    if (kq.ghiChu.isNotEmpty) _noteController.text = kq.ghiChu;
    final doan = kq.doan;
    final lyDo = danhMuc != null ? kq.lyDoDanhMuc : null;
    setState(() {
      if (doan != null && danhMuc != null && lyDo != null) {
        _choPhanXu = (
          goiY: CategorySuggestion(
            category: danhMuc,
            matchedKeyword: doan.cumBoDau,
            nguon: kNguonGoiYHoc,
            amTietChinh: doan.cumBoDau,
            lyDo: lyDo,
          ),
          ghiChu: _noteController.text.trim(),
        );
      }
      _ketQuaDien = (
        tomTat: cauDaDien(kq, tenVi: vi?.name, tenDanhMuc: danhMuc?.name, now: now),
        docDuoc: true,
        quaAi: kq.quaAi,
        canhBao: kq.canhBao,
        lyDo: lyDo,
      );
    });
  }

  /// Hoãn việc tra cứu gợi ý cho tới khi người dùng ngừng gõ.
  ///
  /// `TextEditingController` phát tín hiệu ở MỖI ký tự. Không hoãn thì một ghi
  /// chú 30 ký tự sinh 30 lượt đọc CSDL, mỗi lượt lại đọc thêm từ khoá — và
  /// mọi kết quả trừ cái cuối đều bị vứt đi.
  Timer? _hoanGoiY;
  static const Duration _doTreGoiY = Duration(milliseconds: 300);

  void _onNoteChanged() {
    _hoanGoiY?.cancel();
    final note = _noteController.text.trim();
    // Controller phát cả khi chỉ đổi con trỏ — so CHỮ, không coi mỗi lần phát là "đổi ghi chú".
    if (_choPhanXu != null && note != _choPhanXu!.ghiChu) _choPhanXu = null;
    if (note.isEmpty || _isTransfer || _selectedCategory != null) {
      if (_suggestion != null && mounted) {
        setState(() => _suggestion = null);
      }
      return;
    }
    _hoanGoiY = Timer(_doTreGoiY, () {
      if (!mounted) return;
      // Đọc lại từ controller thay vì dùng `note` đã bắt ở trên: trong lúc chờ
      // người dùng có thể đã gõ tiếp, và thứ đáng gợi ý là văn bản HIỆN TẠI.
      final hienTai = _noteController.text.trim();
      if (hienTai.isEmpty) return;
      _loadSuggestion(hienTai);
    });
  }

  Future<void> _loadSuggestion(String note) async {
    final accountId = _accountId();
    // Chưa có phiên thì không gợi ý gì — đọc danh mục bằng mã admin là gợi ý
    // danh mục của người khác.
    if (accountId == null) return;
    final requestedHuong = _huong;
    // Đoạn Chi/Thu chỉ là lối vào, không khoanh vùng gợi ý: tìm trên cả ba
    // phân loại vì chiều tiền suy từ danh mục được chọn, không phải ngược lại.
    final categories = await _categoryRepository.selectableChildrenAll(
      accountId: accountId,
    );
    // B1: mô hình HỌC đi trước — nó nói từ chính các lần người dùng tự chốt danh mục. `null` = chưa đủ để nói
    // (sổ mỏng, ghi chú lạ, hậu nghiệm thấp, cặp đang bị thôi gợi ý) → bảng từ khoá như trước B1.
    // `hopLe` = mọi danh mục chọn được, cả ba phân loại — cùng nếp "đoạn Chi/Thu không khoanh vùng gợi ý" bên dưới.
    final doan = _boPhanLoai?.doan(
      note,
      hopLe: {for (final c in categories) c.id},
      tatCap: _tatCap,
    );
    CategorySuggestion? suggestion;
    if (doan != null) {
      final cat = categories.firstWhere((c) => c.id == doan.categoryId);
      suggestion = CategorySuggestion(
        category: cat,
        matchedKeyword: doan.cumBoDau,
        nguon: kNguonGoiYHoc,
        amTietChinh: doan.cumBoDau,
        lyDo: cauLyDoHoc(doan, ghiChuGoc: note, tenDanhMuc: cat.name),
      );
    } else {
      // MỘT truy vấn cho cả tài khoản. Trước đây chỗ này gọi `loadKeywords` một
      // lần cho mỗi danh mục, nên tài khoản có 20 danh mục là 20 truy vấn — nhân
      // với mỗi lần ghi chú thay đổi.
      final keywordsByCategory = await _categoryRepository.loadAllKeywords(
        accountId: accountId,
      );
      final candidates = <CategoryKeywordCandidate>[];
      for (final category in categories) {
        for (final keyword in keywordsByCategory[category.id] ?? const <String>[]) {
          candidates.add(
            CategoryKeywordCandidate(category: category, keyword: keyword),
          );
        }
      }
      suggestion = widget.suggestionEngine.suggest(
        rawText: note,
        candidates: candidates,
      );
    }
    if (!mounted ||
        _huong != requestedHuong ||
        _isTransfer ||
        _selectedCategory != null ||
        _noteController.text.trim() != note) {
      return;
    }
    setState(() {
      _suggestion = suggestion;
      if (suggestion != null) _choPhanXu = (goiY: suggestion, ghiChu: note);
    });
  }

  void _showWalletPickerBottomSheet(BuildContext context,
      {required bool isDestination}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDestination ? 'Chọn ví đích' : 'Chọn ví thanh toán',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon:
                        const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_wallets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Chưa có ví nào',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ..._wallets.map((wallet) {
                  final isSelected = isDestination
                      ? _destinationWallet?.id == wallet.id
                      : _selectedWallet?.id == wallet.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isDestination) {
                          _destinationWallet = wallet;
                        } else {
                          _selectedWallet = wallet;
                          _nguoiDungDaChonVi = true;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.surfaceContainerHigh
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wallet.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  WalletType.tuKhoa(wallet.type).nhan,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(wallet.balance),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle,
                                color: AppColors.secondary, size: 20),
                          ]
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  /// Phép gõ nằm ở `domain/ban_phim_so_tien.dart` — hàm thuần, có test riêng.
  ///
  /// Tách ra vì màn này **tự vẽ bàn phím** thay vì dùng `TextField`, nên
  /// `inputFormatters` không với tới đây và trần số chữ số phải chặn ngay trong
  /// phép gõ. `transaction."Amount"` là `numeric(15,2)`: chữ số thứ 14 làm giao
  /// dịch **kẹt hàng đợi đẩy vĩnh viễn**, im lặng.
  void _onKeyPress(String key) {
    setState(() => _amountString = themPhimSoTien(_amountString, key));
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
      _resolvedType == 'thu' ? AppColors.income : AppColors.primary;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }
    if (_selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví thanh toán')),
      );
      return;
    }
    if (!_isTransfer && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }
    if (_isTransfer && _destinationWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví đích')),
      );
      return;
    }
    final type = _resolvedType;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn chiều tiền')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chưa xác định được tài khoản đăng nhập')),
      );
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
      categoryId: _isTransfer ? null : _selectedCategory!.id,
      walletTransfer: _isTransfer ? _destinationWallet!.id : null,
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
    // B1: thẻ gợi ý đã hiện mà người dùng chọn qua bảng rồi lưu — chọn đúng danh mục gợi ý là `chon`, khác là `khac`.
    final choPhanXu = _choPhanXu;
    final daChon = _selectedCategory;
    if (choPhanXu != null && daChon != null && !_isTransfer) {
      _ghiPhanHoi(
        choPhanXu.goiY,
        daChon.id == choPhanXu.goiY.categoryId ? kKetQuaGoiYChon : kKetQuaGoiYKhac,
        chon: daChon.id,
      );
      _choPhanXu = null;
    }
    bloc.add(AddTransactionEvent(
      transaction: tx,
      destinationWalletId: tx.walletTransfer,
    ));
  }

  Future<BudgetImpact?> _budgetImpactFor(
    TransactionEntity tx,
    TransactionEntity? editing,
  ) async {
    final categoryId = tx.categoryId;
    if (tx.type != 'chi' || categoryId == null) return null;

    BudgetView? view;
    try {
      view = await _lookupBudget(tx.idaccount, categoryId);
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

  Future<BudgetView?> _lookupBudget(int idaccount, String categoryId) {
    final custom = widget.budgetLookup;
    if (custom != null) return custom(idaccount, categoryId);
    if (!sl.isRegistered<BudgetRepository>()) return Future.value(null);
    return sl<BudgetRepository>().activeBudgetForCategory(idaccount, categoryId);
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
    final content = BlocConsumer<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionLoadedState) {
          if (state.actionSuccess == true) {
            // Lời nhắn về ngân sách thay lời nhắn mặc định — chung chung,
            // không con số (banner tạm thời tối giản theo ý người dùng).
            final impactText = budgetImpactSnackText(_pendingImpact);
            _pendingImpact = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(impactText ??
                    (_isEditing
                        ? 'Đã lưu thay đổi'
                        : 'Thêm giao dịch thành công!')),
              ),
            );
            context.pop(true);
          } else if (state.actionSuccess == false &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: ${state.errorMessage}')),
            );
          }
        }
      },
      builder: (context, state) {
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
            title: Text(
              _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Thêm tuỳ chọn',
                icon: const Icon(Icons.more_vert, color: AppColors.primary),
                onPressed: () {},
              ),
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
                  child: _buildSegmentControl(),
                ),
                const SizedBox(height: 16),
                _buildAmountDisplay(),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    // C2: ô Nhập nhanh ở ĐẦU vùng cuộn, không cố định — ở 360 × 640 vùng giữa đã chật, một ô cố định
                    // nữa là thẻ form còn chưa tới 70 dp. Chỉ ở đường tạo mới (spec §3).
                    child: Column(
                      children: [
                        if (!_isEditing) ...[
                          _buildNhapNhanh(),
                          const SizedBox(height: 12),
                        ],
                        _buildFormCard(context),
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
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _buildNumericKeyboard(
                      context,
                      isSubmitting: state is TransactionLoadedState &&
                          state.isSubmitting,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    final transactionBloc = widget.transactionBloc;
    return transactionBloc == null
        ? BlocProvider<TransactionBloc>(
            create: (context) => sl<TransactionBloc>(),
            child: content,
          )
        : BlocProvider<TransactionBloc>.value(
            value: transactionBloc,
            child: content,
          );
  }

  Widget _buildSegmentControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildSegmentButton('chi', 'Chi tiêu', AppColors.expense)),
          Expanded(
              child: _buildSegmentButton('thu', 'Thu nhập', AppColors.income)),
          Expanded(
              child: _buildSegmentButton(
                  'transfer', 'Chuyển khoản', AppColors.primary)),
        ],
      ),
    );
  }

  /// Màu đoạn đang chọn theo màn Stitch: Chi tiêu đỏ, Thu nhập xanh, Chuyển
  /// khoản đen.
  Widget _buildSegmentButton(String huong, String title, Color mau) {
    final isSelected = _huong == huong;
    final bgColor = isSelected ? mau : Colors.transparent;
    final textColor = isSelected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      key: Key('transaction-type-$huong'),
      onTap: () => _chonHuong(huong),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Column(
      children: [
        // ⚠️ Không dựng `Text` trần ở đây. Ở cỡ 48 trên 411dp, con số dài nhất
        // mà bàn phím cho gõ (`9.999.999.999.999đ`) NGẮT THÀNH HAI DÒNG và đẩy
        // cả màn xuống — không sọc vàng, không exception, chỉ là bố cục xấu
        // mà widget test dựng-ở-1280px không thấy. Xem `SoTienLon`.
        SoTienLon(chu: _getFormattedAmount(), mau: _getAmountColor()),
        const SizedBox(height: 8),
        // ⚠️ Lưới Stitch KHÔNG có phím `=`, nên ✓ vừa rút gọn vừa lưu trong
        // một nhịp. Dòng này là chỗ DUY NHẤT tổng hiện ra được trước khi giao
        // dịch được ghi — thiếu nó là người dùng bấm lưu một con số chưa từng
        // nhìn thấy. Toán tử lẻ ở cuối thì chưa có gì để rút gọn, giữ nhãn cũ.
        Text(
          coPhepToanDangCho(_amountString)
              ? '= ${CurrencyFormatter.format(ketQuaBieuThuc(_amountString))}'
              : 'VNĐ - VIỆT NAM ĐỒNG',
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final isTransfer = _isTransfer;
    final selectedCategory = _selectedCategory;
    final showDebtDirection =
        selectedCategory != null && isDebtClassify(selectedCategory.classify);
    final walletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_selectedWallet != null
            ? '${_selectedWallet!.name} • ${CurrencyFormatter.format(_selectedWallet!.balance)}'
            : 'Chọn ví');

    final destWalletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_destinationWallet != null
            ? '${_destinationWallet!.name} • ${CurrencyFormatter.format(_destinationWallet!.balance)}'
            : 'Chọn ví đích');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!isTransfer) ...[
            _buildFormRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví thanh toán',
              valueWidget: Text(
                walletDisplay,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () =>
                  _showWalletPickerBottomSheet(context, isDestination: false),
            ),
            Divider(
                height: 1,
                indent: 64,
                color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            _buildFormRow(
              icon: Icons.category,
              label: 'Danh mục',
              valueWidget: Text(
                _selectedCategory != null
                    ? _selectedCategory!.name
                    : 'Chọn danh mục',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedCategory != null
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                  fontWeight: _selectedCategory != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
              showArrow: true,
              onTap: () async {
                // Mở đúng tab của danh mục đang chọn; lần đầu thì tab chi.
                final selected = await context.push<Category>(
                  '/add/category',
                  // Chưa có danh mục thì mở tab của đoạn đang chọn (C3).
                  extra: selectedCategory?.classify ??
                      (_huong == 'thu' ? 'thu' : kCategoryClassifies.first),
                );
                if (selected != null) _chonDanhMuc(selected);
              },
            ),
            if (showDebtDirection) ...[
              Divider(
                  height: 1,
                  indent: 64,
                  color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              _buildDebtDirectionRow(),
            ],
            if (_suggestion != null) ...[
              Divider(
                  height: 1,
                  indent: 64,
                  color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              _buildSuggestionCard(_suggestion!),
            ],
          ] else ...[
            _buildFormRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví nguồn (Từ ví)',
              valueWidget: Text(
                walletDisplay,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () =>
                  _showWalletPickerBottomSheet(context, isDestination: false),
            ),
            Divider(
                height: 1,
                indent: 64,
                color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            _buildFormRow(
              icon: Icons.account_balance_wallet,
              label: 'Ví đích (Đến ví)',
              valueWidget: Text(
                destWalletDisplay,
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: () =>
                  _showWalletPickerBottomSheet(context, isDestination: true),
            ),
          ],
          Divider(
              height: 1,
              indent: 64,
              color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notes,
                      color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    key: const Key('ghi-chu-giao-dich'),
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Thêm ghi chú cho giao dịch...',
                      hintStyle: TextStyle(
                          fontSize: 14, color: AppColors.outlineVariant),
                      border: InputBorder.none,
                    ),
                    style:
                        const TextStyle(fontSize: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              indent: 64,
              color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          _buildFormRow(
            icon: Icons.calendar_today,
            label: 'Ngày',
            valueWidget: Text(
              DateFormat('dd/MM/yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 16, color: AppColors.primary),
            ),
            trailingIcon: Icons.calendar_month,
            onTap: _pickDate,
          ),
        ],
      ),
    );
  }

  /// Thẻ *Nhập nhanh* (C2, spec §3): ô một dòng + nút **Điền**; dưới là dòng tóm tắt những ô đã điền, cảnh báo, và câu lý
  /// do khi danh mục đến từ B1.
  Widget _buildNhapNhanh() {
    final kq = _ketQuaDien;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, size: 16, color: AppColors.expense),
              SizedBox(width: 4),
              Text(
                'NHẬP NHANH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Nút Điền nằm TRONG khung ô, mép phải — màn Stitch `8afdfe11…` (C2 T5). Khung tự vẽ, nút đứng ngoài
          // `TextField`. ⚠️ Bản dựng bằng `suffixIcon` làm ca Huỷ của `nhap_nhanh_test` trượt tay (cú chạm rơi vào lúc
          // vùng cuộn không nhận chạm); hai phép đo tối giản (ô chưa / đã focus, chạm nút trong `suffixIcon`) không tái
          // hiện được nên chưa lần ra nguyên nhân — đừng đổi lại khi chưa đo trên máy thật.
          ListenableBuilder(
            listenable: _nhapNhanhFocus,
            builder: (context, child) => Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: _nhapNhanhFocus.hasFocus
                    ? Border.all(color: AppColors.primary, width: 2)
                    : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: child,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('nhap-nhanh-o'),
                    controller: _nhapNhanhController,
                    focusNode: _nhapNhanhFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _dienTuCau(),
                    style: const TextStyle(fontSize: 15, color: AppColors.primary),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'VD: hôm qua ăn phở 45k tiền mặt',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.outlineVariant),
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // `minimumSize` hữu hạn: theme của app ép mọi ElevatedButton rộng vô hạn (bẫy 4.11).
                ElevatedButton(
                  key: const Key('nhap-nhanh-dien'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _dangDocAi ? null : _dienTuCau,
                  child: const Text('Điền'),
                ),
              ],
            ),
          ),
          if (_dangDocAi)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Đang đọc bằng AI…',
                      key: Key('nhap-nhanh-dang-doc'),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    key: const Key('nhap-nhanh-huy'),
                    onPressed: _huyDocAi,
                    child: const Text('Huỷ'),
                  ),
                ],
              ),
            )
          else if (kq != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  kq.docDuoc ? Icons.check_circle : Icons.info_outline,
                  size: 16,
                  color: kq.docDuoc ? AppColors.income : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kq.tomTat,
                    key: const Key('nhap-nhanh-tom-tat'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kq.docDuoc ? AppColors.income : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 22),
              child: Row(
                children: [
                  Icon(
                    kq.quaAi ? Icons.auto_awesome : Icons.rule,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    kq.quaAi ? 'Đọc bằng AI' : 'Đọc bằng luật',
                    key: const Key('nhap-nhanh-nguon'),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            for (final cb in kq.canhBao)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(cb, style: const TextStyle(fontSize: 12, color: AppColors.expense)),
              ),
            if (kq.lyDo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  kq.lyDo!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(CategorySuggestion suggestion) => Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gợi ý danh mục',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              suggestion.category.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            // Lý do theo NGUỒN: học → "Bạn thường ghi “grab” cho Di chuyển (6/7 lần)."; từ khoá → câu cũ.
            Text(
              suggestion.lyDo,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    _ghiPhanHoi(suggestion, kKetQuaGoiYBoQua);
                    setState(() {
                      _suggestion = null;
                      _choPhanXu = null;
                    });
                  },
                  child: const Text('Bỏ qua'),
                ),
                const Spacer(),
                // ⚠️ `minimumSize` hữu hạn BẮT BUỘC: theme của app ép mọi ElevatedButton rộng vô hạn, nút trần trong
                // `Row` làm trắng cả vùng form mà không một dòng log nào (bẫy 4.11). Lỗi có từ trước B1 — nghiệm thu
                // máy ảo 2026-09-29 mới lộ, vì mọi widget test cũ dựng MaterialApp trần.
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () {
                    _ghiPhanHoi(suggestion, kKetQuaGoiYChon, chon: suggestion.categoryId);
                    _choPhanXu = null;
                    _chonDanhMuc(suggestion.category);
                  },
                  child: const Text('Chọn danh mục này'),
                ),
              ],
            ),
          ],
        ),
      );

  /// Công tắc chiều tiền — chỉ hiện khi danh mục là vay/nợ, vì đó là phân loại
  /// duy nhất gom cả tiền vào lẫn tiền ra (Cho vay/Trả nợ ↔ Đi vay/Thu nợ).
  Widget _buildDebtDirectionRow() => _buildFormRow(
        icon: Icons.swap_vert,
        label: 'Chiều tiền',
        valueWidget: Wrap(
          spacing: 8,
          children: [
            _directionChip('chi', 'Tiền ra'),
            _directionChip('thu', 'Tiền vào'),
          ],
        ),
      );

  Widget _directionChip(String direction, String label) {
    final selected = _debtDirection == direction;
    return ChoiceChip(
      key: Key('debt-direction-$direction'),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.outlineVariant),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.primary,
      ),
      // Cùng giá trị với đoạn đầu màn — xem chú thích ở `_huong`.
      onSelected: (_) => setState(() {
        _debtDirection = direction;
        _huong = direction;
      }),
    );
  }

  Widget _buildFormRow({
    required IconData icon,
    required String label,
    required Widget valueWidget,
    bool showArrow = false,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueWidget,
                ],
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: AppColors.outline)
            else if (showArrow)
              const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericKeyboard(BuildContext context,
      {required bool isSubmitting}) {
    final keys = [
      '7',
      '8',
      '9',
      'backspace',
      '4',
      '5',
      '6',
      '+',
      '1',
      '2',
      '3',
      '-',
      // Ô này từng là phím `.` — bỏ vì nó sinh số lẻ mà đường lưu đọc sai gấp
      // mười, và app làm tròn về đồng chẵn ở mọi chỗ hiển thị. Thay bằng `00`
      // chứ không để trống: lưới là 4×4, thiếu một ô thì hàng cuối lệch cột.
      '00',
      '0',
      '000',
      'done'
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 16,
      // `mainAxisExtent` CỐ ĐỊNH thay vì `childAspectRatio`: bàn phím neo đáy
      // phải cao như nhau ở mọi bề rộng — tỉ lệ ở khung test 800dp cho phím
      // cao gấp đôi và nuốt hết chỗ của thẻ form.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 50,
      ),
      itemBuilder: (context, index) {
        final keyStr = keys[index];
        bool isOperator =
            keyStr == 'backspace' || keyStr == '+' || keyStr == '-';
        bool isDone = keyStr == 'done';

        return Material(
          color: isDone
              ? AppColors.primary
              : isOperator
                  ? AppColors.surfaceContainer
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            // ✓ là nút lưu (từng là phím chết: `themPhimSoTien` trả nguyên
            // chuỗi với 'done').
            onTap: isDone
                ? (isSubmitting ? null : () => _saveTransaction(context))
                : () => _onKeyPress(keyStr),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!isOperator && !isDone)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: _buildKeyContent(keyStr, isDone),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyContent(String keyStr, bool isDone) {
    if (keyStr == 'backspace') {
      return const Icon(Icons.backspace_outlined,
          size: 24, color: AppColors.primary);
    }
    if (keyStr == 'done') {
      return const Icon(Icons.check, size: 28, color: Colors.white);
    }
    if (keyStr == kToanTuCong || keyStr == kToanTuTru) {
      return Text(
        // Dấu trừ THẬT (U+2212), cùng ký hiệu với dòng số; gạch nối ASCII ở
        // ngay trước một con số đọc như dấu âm. Giá trị nội bộ vẫn là '-'.
        keyStr == kToanTuTru ? '−' : keyStr,
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.normal,
            color: AppColors.primary),
      );
    }
    return Text(
      keyStr,
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
    );
  }
}

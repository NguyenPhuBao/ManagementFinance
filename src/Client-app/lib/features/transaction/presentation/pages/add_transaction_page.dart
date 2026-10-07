import 'dart:async';
import 'dart:io';
import '../../../../core/utils/currency_formatter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/category/category_classify.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/notification_dao.dart' show kKindBienDongSoDu;
import '../../../../core/di/injection_container.dart';
import '../../../../core/notification/kho_bien_lai.dart';
import '../../../budget/data/models/budget_entity.dart';
import '../../../budget/data/repositories/budget_repository.dart';
import '../../domain/ban_phim_so_tien.dart';
import '../../domain/dien_san_bien_dong.dart';
import '../../domain/doc_cau_giao_dich.dart';
import '../../domain/goi_y_chuyen_khoan.dart';
import '../../data/doc_cau_bang_ai.dart';
import '../../data/vi_theo_nguon_store.dart';
import '../widgets/so_tien_lon.dart';
import '../widgets/xem_anh_bien_lai.dart';
import '../../../budget/domain/budget_impact.dart';
import '../../../wallet/domain/wallet_type.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/category/data/goi_y_phan_hoi_store.dart';
import '../../../../features/category/data/models/category_suggestion.dart';
import '../../../../features/category/data/repositories/category_management_repository.dart';
import '../../../../features/category/data/services/category_suggestion_engine.dart';
import '../../../../features/category/domain/de_xuat_tu_khoa.dart';
import '../../../../features/category/domain/gan_hang_loat.dart' show hopLeTheoChieu;
import '../../../../features/category/domain/phan_loai_ghi_chu.dart';
import '../../../../features/category/domain/phan_loai_so_tien.dart';
import '../../../../features/premium/presentation/cubit/goi_cubit.dart';
import '../../../../features/premium/presentation/widgets/nut_nang_cap.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/vi_chon_san.dart';
import '../../domain/vi_hay_dung.dart';
import '../../data/models/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import '../../../../core/ui/bao_che_day_toast.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

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

  /// Xoá cứng hàng loại 20 theo `dedupeKey` (D1). `null` → `NotificationDao.xoaCung`.
  final Future<void> Function(int idaccount, String khoa)? xoaBienDong;

  /// Sổ giao dịch để nhắc *"có thể bạn đã ghi khoản này"* (D1). `null` → `TransactionDao.getAll`.
  final Future<List<KhoanSo>> Function(int idaccount)? khoanTrongSo;

  /// Các hàng biến động đang chờ của tài khoản — căn cứ luật cặp của gợi ý Chuyển khoản (spec 2026-09-30). `null` →
  /// `NotificationDao.getAll`.
  final Future<List<DienSanBienDong>> Function(int idaccount)? hangBienDongCho;

  /// Chia sẻ biên lai (2026-10-02): thư mục ảnh biên lai — form hiện ảnh nhỏ của hàng đang mở ([DienSanBienDong.anh])
  /// để đối chiếu, và xoá tệp khi Lưu / Bỏ qua. `null` → `sl<KhoBienLai>()` nếu đã đăng ký.
  final KhoBienLai? khoBienLai;

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
      return context.read<GoiCubit>().duocDungAiQuickInput;
    } on ProviderNotFoundException {
      return true;
    }
  }

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

  /// Bàn phím số 16 phím có đang mở không (2026-09-30, việc sau D1). Màn mở đã có số tiền (sửa · biến động số dư)
  /// hoặc ô Nhập nhanh vừa điền số tiền thì ẨN — việc còn lại là soát thẻ form, và ở 360 dp 16 phím chiếm nửa dưới
  /// màn (đo Realme). Chạm khối số tiền để đảo. ⚠️ Cờ này chưa phải "phím có trên màn": bàn phím HỆ THỐNG mở cũng
  /// giấu chúng (G58) — hỏi [_coBanPhimSo].
  late bool _hienBanPhimSo;

  List<Wallet> _wallets = [];
  /// Bảng ví hay dùng, rỗng khi chưa đủ căn cứ hoặc chưa nạp xong.
  Map<String, String> _viHayDung = const {};

  /// Mô hình học từ ghi chú; `null` khi chưa nạp xong hoặc học lỗi — khi ấy thẻ gợi ý rơi về bảng từ khoá.
  BoPhanLoaiGhiChu? _boPhanLoai;

  /// Cặp (cụm, danh mục) đang bị thôi gợi ý (`tatCapTu`) — nạp một lần sau khi có mô hình.
  Set<(String, String)> _tatCap = const {};

  /// Mô hình học theo số tiền (dự án C); `null` khi chưa nạp xong hoặc học lỗi — khi ấy thẻ chỉ còn B1 / từ khoá.
  BoPhanLoaiSoTien? _boSoTien;

  /// Cặp (mã bậc, danh mục) của nguồn số tiền đang bị thôi gợi ý (`tatCapSoTienTu`).
  Set<(String, String)> _tatCapSoTien = const {};

  /// Cặp người dùng vừa bấm *Bỏ qua* trong lượt mở màn này. Thẻ nguồn số tiền tính lại ở MỖI phím số, nên thiếu tập
  /// này thì bấm Bỏ qua xong gõ thêm một chữ số cùng bậc là thẻ bật lại ngay (cùng nếp [_boQuaLuotNay]).
  final Set<(String, String)> _boQuaSoTienLuotNay = {};

  /// Cặp (cụm, danh mục) đang bị thôi ĐỀ XUẤT TỪ KHOÁ — tập riêng của nguồn `kNguonDeXuatTuKhoa` (spec 2026-09-30 §2.4).
  Set<(String, String)> _tatCapTuKhoa = const {};

  /// Cặp người dùng vừa ✕ trong lượt này — dòng ẩn tới khi rời màn.
  final Set<(String, String)> _boQuaLuotNay = {};

  /// Mẫu học trừ giao dịch đang sửa (đường sửa); `null` ở đường tạo mới → dùng `_boPhanLoai.mau`.
  List<MauGhiChu>? _mauDeXuat;

  /// Đề xuất thêm / chuyển từ khoá đang hiện dưới hàng Danh mục; `tenCu` khác `null` = đề xuất chuyển.
  ({DeXuatTuKhoa dx, String tenDanhMuc, String? tenCu})? _deXuat;

  /// "Đã thêm / Đã chuyển …" — tự ẩn sau 2 giây (người dùng chốt 2026-09-30, màn Stitch `8ca1338e…`).
  String? _daThemTuKhoa;
  Timer? _hoanDeXuat;
  Timer? _anDaThem;

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

  /// Khoá của thẻ gợi ý — để [_cuonToiTheGoiY] đưa thẻ nguồn số tiền vào khung nhìn.
  final GlobalKey _khoaTheGoiY = GlobalKey();

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

  /// D1: form đang mở từ một hàng biến động số dư (đường tạo mới).
  DienSanBienDong? get _bienDong => _isEditing ? null : widget.bienDong;

  /// D1: bảng nguồn → ví đã có một ví HOẠT ĐỘNG cho cặp nguồn + đuôi này — khi ấy Lưu không ghi đè (spec §3.3: ghi ở
  /// lần Lưu đầu của mỗi cặp).
  bool _viNguonDaNho = false;

  /// D1: khoản trong sổ cùng tiền + chiều + ngày với tin — dòng *"Có thể bạn đã ghi khoản này"*.
  List<KhoanSo> _trungTrongSo = const [];

  /// Gợi ý Chuyển khoản đang hiện (thẻ) và ví đoán cho hai phía; `null` = không gợi ý (spec gợi ý chuyển khoản §4).
  GoiYChuyenKhoan? _goiYChuyen;
  ({String? tu, String? den, bool daNhoTu, bool daNhoDen})? _viGoiY;

  /// Gợi ý người dùng ĐÃ áp — Lưu ở đoạn Chuyển khoản thì xoá cả hàng cặp và nhớ ví hai phía (§5).
  GoiYChuyenKhoan? _goiYDaApDung;

  ViTheoNguonStore? get _viTheoNguon =>
      widget.viTheoNguon ?? (sl.isRegistered<ViTheoNguonStore>() ? sl<ViTheoNguonStore>() : null);

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
    // D1 điền số tiền SAU (chờ ví + mô hình) — quyết từ tin ngay lúc mở, kẻo 16 phím chớp lên rồi tắt.
    _hienBanPhimSo = _amountString == '0' && _bienDong?.soTien == null;
    _noteController.addListener(_onNoteChanged);
    _nhapNhanhFocus.addListener(() {
      if (_nhapNhanhFocus.hasFocus) unawaited(_docAi?.chuanBi());
    });
    final napVi = _loadWallets();
    // Đường sửa mở với danh mục + ghi chú sẵn → tính đề xuất từ khoá sau khi có mẫu và tập tắt.
    final napHoc = _loadViHayDung().then((_) => _napTatCap());
    unawaited(napHoc.then((_) => _tinhDeXuat()));
    // D1: điền sau khi có cả ví (chọn sẵn theo nguồn) lẫn mô hình B1 + tập tắt (đoán danh mục).
    if (_bienDong != null) unawaited(Future.wait([napVi, napHoc]).then((_) => _dienTuBienDong()));
    // Chia sẻ biên lai: hàng đang mở mang ảnh → tìm tệp. Tệp đã mất thì dải nguồn dựng như không có ảnh.
    if (_bienDong?.anh case final anh?) {
      unawaited(_khoBienLai?.duongDan(anh).then((p) {
        if (mounted && p != null) setState(() => _duongDanAnh = p);
      }));
    }
  }

  KhoBienLai? get _khoBienLai => widget.khoBienLai ?? (sl.isRegistered<KhoBienLai>() ? sl<KhoBienLai>() : null);

  /// Đường dẫn ảnh biên lai của hàng đang mở; `null` = không có ảnh (hoặc chưa tìm xong).
  String? _duongDanAnh;

  /// Xoá ảnh biên lai của hàng vừa Lưu / Bỏ qua (người dùng chốt: ảnh chỉ sống tới lúc ấy). Không bao giờ ném.
  Future<void> _xoaAnhBienLai(DienSanBienDong d) async {
    try {
      await _khoBienLai?.xoa(d.anh);
    } catch (e) {
      debugPrint('[BienLai] xoá ảnh lỗi: ${e.runtimeType}');
    }
  }

  /// D1 — điền form từ hàng biến động số dư, qua ĐÚNG đường điền của C2 ([_dienKetQua]). Không lưu.
  Future<void> _dienTuBienDong() async {
    final d = _bienDong;
    final id = _accountId();
    if (d == null || !mounted) return;
    final (chonDuoc, tuKhoa) = await _napDanhMucVaTuKhoa();
    String? viId;
    if (id != null) {
      try {
        // Dòng nhắc (không đuôi TK) thì thử thêm ví của cả NGUỒN — chỉ khi nó chắc (một ví duy nhất).
        final nho = await _viTheoNguon?.doc(id, d.nguon, d.duoi) ??
            (d.phien != null ? await _viTheoNguon?.docTheoNguon(id, d.nguon) : null);
        // Chỉ ví HOẠT ĐỘNG (`_wallets` là `getActive`): ví đã lưu trữ / xoá thì coi như chưa nhớ.
        if (nho != null && _wallets.any((w) => w.id == nho)) viId = nho;
      } catch (e) {
        debugPrint('[BienDong] đọc ví theo nguồn lỗi: $e');
      }
    }
    if (!mounted) return;
    _viNguonDaNho = viId != null;
    final kq = ketQuaTuBienDong(d,
        chonDuoc: chonDuoc, mo: _boPhanLoai, tatCap: _tatCap, tuKhoa: tuKhoa, walletId: viId);
    _dienKetQua(kq, chonDuoc: chonDuoc);
    setState(() {
      // Lần đầu của cặp nguồn + đuôi: ví TRỐNG, không phải ví mặc định — để ví mặc định là để bảng nguồn → ví học nhầm
      // nó ở lần Lưu đầu, rồi chọn sẵn sai mãi.
      if (viId == null) _selectedWallet = null;
      // `_dienKetQua` chỉ đổi phần ngày; giờ trong tin là giờ giao dịch (spec §3.3).
      final t = d.thoiGian;
      if (t != null) _selectedDate = t;
    });
    if (id == null) return;
    unawaited(_tinhGoiYChuyen(d, id));
    try {
      final so = await (widget.khoanTrongSo ?? _khoanTrongSoMacDinh)(id);
      final trung = khoanCoTheDaGhi(so, soTien: d.soTien, chieu: d.chieu, ngay: d.thoiGian);
      if (mounted) setState(() => _trungTrongSo = trung);
    } catch (e) {
      debugPrint('[BienDong] đọc sổ để nhắc trùng lỗi: $e');
    }
  }

  /// Gợi ý Chuyển khoản (spec 2026-09-30 §2–3): luật cặp trên các hàng đang chờ, rồi luật nội dung tin. Ví phía nguồn
  /// của tin theo luật D1 (chỉ ví đã nhớ); phía kia: đã nhớ → ví duy nhất trùng tên nguồn → trống. Lỗi → không gợi ý.
  Future<void> _tinhGoiYChuyen(DienSanBienDong d, int id) async {
    try {
      final cho = await (widget.hangBienDongCho ?? _hangChoMacDinh)(id);
      final gy = goiYChuyenKhoan(d, cho);
      if (gy == null) return;
      Future<String?> nho(String nguon, String? duoi) async {
        final v = await _viTheoNguon?.doc(id, nguon, duoi);
        return v != null && _wallets.any((w) => w.id == v) ? v : null;
      }

      final nhoTu = await nho(gy.nguonTu, gy.duoiTu);
      final nhoDen = await nho(gy.nguonDen, gy.duoiDen);
      if (!mounted) return;
      final ds = [for (final w in _wallets) (id: w.id, ten: w.name)];
      String? doan(String nguon, String? daNho) => daNho ?? (nguon == d.nguon ? null : viTheoTenNguon(nguon, ds));
      setState(() {
        _goiYChuyen = gy;
        _viGoiY = (
          tu: doan(gy.nguonTu, nhoTu),
          den: doan(gy.nguonDen, nhoDen),
          daNhoTu: nhoTu != null,
          daNhoDen: nhoDen != null,
        );
      });
    } catch (e) {
      debugPrint('[BienDong] gợi ý chuyển khoản lỗi: $e');
    }
  }

  static Future<List<DienSanBienDong>> _hangChoMacDinh(int id) async {
    final ds = <DienSanBienDong>[];
    for (final n in await sl<AppDatabase>().notificationDao.getAll(id)) {
      final link = n.deeplink;
      if (n.kind != kKindBienDongSoDu || n.dismissedAt != null || link == null) continue;
      final h = dienSanBienDongTuQuery(Uri.tryParse(link)?.queryParameters ?? const {});
      if (h != null) ds.add(h);
    }
    return ds;
  }

  /// Bấm *Ghi là chuyển khoản*: đổi đoạn qua ĐÚNG [_chonHuong], điền hai ví; ô không đoán được để TRỐNG — ví mặc định
  /// ở đây là để bảng nguồn → ví học nhầm (D1 §3.3). Không lưu (bất biến ④ nhóm C).
  void _apGoiYChuyen() {
    final gy = _goiYChuyen;
    final v = _viGoiY;
    if (gy == null || v == null) return;
    _chonHuong('transfer');
    Wallet? tim(String? id) {
      for (final w in _wallets) {
        if (w.id == id) return w;
      }
      return null;
    }

    setState(() {
      _selectedWallet = tim(v.tu);
      _destinationWallet = tim(v.den);
      _nguoiDungDaChonVi = true;
      _goiYDaApDung = gy;
      _goiYChuyen = null;
    });
  }

  static Future<List<KhoanSo>> _khoanTrongSoMacDinh(int id) async => [
        for (final t in await sl<AppDatabase>().transactionDao.getAll(id))
          (id: t.id, soTien: t.amount, loai: t.type, ngay: t.date, ghiChu: t.note),
      ];

  /// D1 — xử lý xong một hàng biến động (Lưu hoặc Bỏ qua): xoá CỨNG hàng loại 20 (`NotificationDao.xoaCung`, ngoại lệ
  /// có chủ ý — spec §3.3), và khi Lưu ở lần đầu của cặp nguồn + đuôi thì nhớ ví. Mọi giá trị truyền vào đã chốt lúc
  /// gọi: màn có thể đã `pop`. Không bao giờ ném.
  Future<void> _dongBienDong(DienSanBienDong d, int id, {String? viDaLuu, bool nhoVi = false}) async {
    final store = _viTheoNguon;
    try {
      if (nhoVi && viDaLuu != null) await store?.ghi(id, d.nguon, d.duoi, viDaLuu);
    } catch (e) {
      debugPrint('[BienDong] ghi ví theo nguồn lỗi: $e');
    }
    await _xoaHangBienDong(id, d.khoa);
    await _xoaAnhBienLai(d);
  }

  /// Xoá cứng một hàng loại 20 theo `dedupeKey` (ngoại lệ có chủ ý — spec D1 §3.3). Không bao giờ ném.
  Future<void> _xoaHangBienDong(int id, String khoa) async {
    final xoa = widget.xoaBienDong ??
        (sl.isRegistered<AppDatabase>() ? sl<AppDatabase>().notificationDao.xoaCung : null);
    try {
      await xoa?.call(id, khoa);
    } catch (e) {
      debugPrint('[BienDong] xoá hàng biến động lỗi: $e');
    }
  }

  /// Lưu sau khi áp gợi ý Chuyển khoản (spec §5): nhớ ví cho CẢ HAI nguồn — mỗi phía theo phía của nó. ⚠️ Không theo
  /// `_selectedWallet`: tin THU ghi thành chuyển khoản thì ví của nguồn tin là ví ĐÍCH, nhớ ví nguồn là mọi tin sau của
  /// nguồn ấy chọn sẵn sai ví, im lặng. Rồi xoá hàng đang mở và hàng cặp (còn chờ là người dùng ghi đôi). Không ném.
  Future<void> _dongChuyenKhoan(DienSanBienDong d, GoiYChuyenKhoan gy, int id,
      {String? viTu, String? viDen, required bool daNhoTu, required bool daNhoDen}) async {
    final store = _viTheoNguon;
    try {
      if (!daNhoTu && viTu != null) await store?.ghi(id, gy.nguonTu, gy.duoiTu, viTu);
      if (!daNhoDen && viDen != null) await store?.ghi(id, gy.nguonDen, gy.duoiDen, viDen);
    } catch (e) {
      debugPrint('[BienDong] ghi ví theo nguồn lỗi: $e');
    }
    await _xoaHangBienDong(id, d.khoa);
    await _xoaAnhBienLai(d);
    final cap = gy.khoaCap;
    if (cap != null) await _xoaHangBienDong(id, cap);
  }

  Future<void> _boQuaBienDong() async {
    final d = _bienDong;
    final id = _accountId();
    if (d != null && id != null) await _dongBienDong(d, id);
    if (mounted) context.pop();
  }

  /// Đọc phản hồi cũ → cặp đang bị thôi gợi ý. Lỗi thì bỏ qua: thẻ vẫn gợi ý như chưa ai từng bỏ qua.
  Future<void> _napTatCap() async {
    final bo = _boPhanLoai;
    final boTien = _boSoTien;
    final store = _phanHoiStore;
    final id = _accountId();
    // Hai mô hình độc lập: B1 học lỗi (`null`) không được kéo theo việc bỏ nạp tập tắt của nguồn số tiền.
    if ((bo == null && boTien == null) || store == null || id == null) return;
    try {
      final phanHoi = await store.doc(id);
      final tat = bo == null ? const <(String, String)>{} : tatCapTu(phanHoi, bo.mau);
      final tatTuKhoa =
          bo == null ? const <(String, String)>{} : tatCapTu(phanHoi, _mauDeXuat ?? bo.mau, nguon: kNguonDeXuatTuKhoa);
      final tatTien = boTien == null ? const <(String, String)>{} : tatCapSoTienTu(phanHoi, boTien.mau);
      if (mounted) {
        setState(() {
          _tatCap = tat;
          _tatCapTuKhoa = tatTuKhoa;
          _tatCapSoTien = tatTien;
        });
      }
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
    _hoanDeXuat?.cancel();
    _anDaThem?.cancel();
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
    unawaited(_tinhDeXuat());
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
    if (widget.boSoTien != null) _boSoTien = widget.boSoTien;
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
    final dangSua = _editing?.id;
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
    // Dự án C: mô hình theo số tiền, học từ CÙNG lượt đọc sổ. `getAll` đã bỏ hàng có `deletedAt`; `isDeleted` là cờ
    // xoá mềm thứ hai của bảng — mẫu học không được chứa khoản người dùng đã bỏ.
    BoPhanLoaiSoTien? boTien = widget.boSoTien;
    if (boTien == null) {
      try {
        boTien = BoPhanLoaiSoTien.hoc(mauSoTienTu([
          for (final t in txs)
            (
              loai: t.type,
              categoryId: t.categoryId,
              ghiChu: t.note,
              soTien: t.amount,
              walletId: t.walletId,
              ngay: t.date,
              daXoa: t.isDeleted,
            ),
        ]));
      } catch (e) {
        debugPrint('[GoiYDanhMuc] học mô hình số tiền lỗi: $e');
        boTien = null;
      }
    }
    if (mounted) {
      setState(() {
        _viHayDung = bang;
        _boPhanLoai = bo;
        _boSoTien = boTien;
        // Đường sửa: mẫu của CHÍNH giao dịch đang sửa phải ra khỏi phép đếm — hàm đề xuất cộng bản đang gõ vào.
        _mauDeXuat = dangSua == null
            ? null
            : mauHocTu([
                for (final t in txs)
                  if (t.id != dangSua) (loai: t.type, categoryId: t.categoryId, ghiChu: t.note, ngay: t.date),
              ]);
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
    unawaited(_tinhDeXuat());
    // Đoạn Chi / Thu là thông tin CHIỀU duy nhất của gợi ý theo số tiền (dự án C): đổi đoạn là đổi tập mẫu được học.
    _henGoiYTheoForm();
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
  /// - danh mục đến từ B1 hoặc từ khoá thì đặt [_choPhanXu] như thẻ gợi ý, để lúc lưu ghi phản hồi `chon` / `khac`.
  Future<void> _dienTuCau() async {
    final cau = _nhapNhanhController.text.trim();
    if (cau.isEmpty || _dangDien) return;
    _dangDien = true;
    final luot = ++_luotDien;
    FocusScope.of(context).unfocus();
    final (chonDuoc, tuKhoa) = await _napDanhMucVaTuKhoa();
    // Người dùng chốt 2026-09-30 (spec C2 banner "ĐỔI LẦN HAI"): luật trước — chỉ hỏi mô hình (~18 s trên Realme) khi còn
    // ô câu có nhắc mà luật không đọc được (số tiền, ngày, ví); AI về thì luật kiểm từng ô và chỉ LẤP ô luật để trống.
    KetQuaAi? ai;
    final docAi = _docAi;
    final conThieu = _docCau(cau, chonDuoc, tuKhoa).oThieu.isNotEmpty;
    if (conThieu && docAi != null && mounted && await docAi.sanSang()) {
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
    _apDungKetQua(cau, chonDuoc, tuKhoa, ai: ai);
  }

  /// Danh mục chọn được + từ khoá của chúng (bước từ khoá của C2, người dùng chốt 2026-09-30). Lỗi đọc thì rỗng — ô
  /// Nhập nhanh vẫn điền được mọi ô khác.
  Future<(List<Category>, Map<String, List<String>>)> _napDanhMucVaTuKhoa() async {
    final id = _accountId();
    if (id == null) return (const <Category>[], const <String, List<String>>{});
    try {
      return (
        await _categoryRepository.selectableChildrenAll(accountId: id),
        await _categoryRepository.loadAllKeywords(accountId: id),
      );
    } catch (e) {
      debugPrint('[NhapNhanh] đọc danh mục / từ khoá lỗi: $e');
      return (const <Category>[], const <String, List<String>>{});
    }
  }

  /// Huỷ lượt đọc bằng AI: điền ngay bằng luật, mô hình thôi giải mã.
  Future<void> _huyDocAi() async {
    _luotDien++;
    unawaited(_docAi?.huy());
    final cau = _nhapNhanhController.text.trim();
    final (chonDuoc, tuKhoa) = await _napDanhMucVaTuKhoa();
    if (!mounted) return;
    setState(() {
      _dangDien = false;
      _dangDocAi = false;
    });
    if (cau.isNotEmpty) _apDungKetQua(cau, chonDuoc, tuKhoa);
  }

  KetQuaDocCau _docCau(String cau, List<Category> chonDuoc, Map<String, List<String>> tuKhoa, {KetQuaAi? ai}) =>
      docCauGiaoDich(
        cau,
        now: DateTime.now(),
        vi: _wallets,
        chonDuoc: chonDuoc,
        mo: _boPhanLoai,
        tatCap: _tatCap,
        ai: ai,
        tuKhoa: tuKhoa,
        // Dòng nguồn "Đọc bằng AI" chỉ khi AI làm ĐỔI một ô — chiều / ví đang chọn không tính (người dùng chốt 2026-09-30).
        chieuDangChon: _huong,
        viDangChon: _selectedWallet?.id,
      );

  /// Đọc câu rồi điền những ô đọc được vào form (xem [_dienTuCau]).
  void _apDungKetQua(String cau, List<Category> chonDuoc, Map<String, List<String>> tuKhoa, {KetQuaAi? ai}) =>
      _dienKetQua(_docCau(cau, chonDuoc, tuKhoa, ai: ai), chonDuoc: chonDuoc);

  /// Điền một [KetQuaDocCau] đã dựng sẵn vào form — phần ÁP, tách khỏi phần đọc câu (2026-09-30, mở D1): ô Nhập nhanh
  /// đi qua [_apDungKetQua], còn form điền sẵn từ tin biến động số dư (D1) dựng `KetQuaDocCau` từ query rồi gọi thẳng
  /// đây. Mỗi ô đi đúng đường người dùng vẫn đi (chiều qua [_chonHuong], số tiền qua `themPhimSoTien`, danh mục qua
  /// [_chonDanhMuc]…) — xem [_dienTuCau].
  void _dienKetQua(KetQuaDocCau kq, {required List<Category> chonDuoc}) {
    final now = DateTime.now();
    if (kq.khongDocDuocGi) {
      setState(() => _ketQuaDien =
          (tomTat: kCauChuaDocDuoc, docDuoc: false, quaAi: kq.quaAi, canhBao: kq.canhBao, lyDo: null));
      return;
    }

    final loai = kq.loai;
    if (loai != null && loai != _huong) _chonHuong(loai);
    Wallet? vi;
    Wallet? viDen;
    for (final w in _wallets) {
      if (w.id == kq.walletId) vi = w;
      if (w.id == kq.walletToId) viDen = w;
    }
    setState(() {
      final soTien = kq.soTien;
      if (soTien != null) {
        var a = '0';
        for (final c in soTien.toInt().toString().split('')) {
          a = themPhimSoTien(a, c);
        }
        _amountString = a;
        _hienBanPhimSo = false;
      }
      final ngay = kq.ngay;
      if (ngay != null) {
        _selectedDate = DateTime(ngay.year, ngay.month, ngay.day, _selectedDate.hour, _selectedDate.minute);
      }
      if (vi != null) {
        _selectedWallet = vi;
        _nguoiDungDaChonVi = true;
      }
      // Chuyển ví (§2.9). Câu chỉ nêu ví đích mà ví nguồn đang chọn lại chính là nó → để trống ví nguồn cho người dùng
      // chọn: chuyển vào chính nó là khoản vô nghĩa, và màn không chặn lúc lưu.
      if (viDen != null) {
        _destinationWallet = viDen;
        if (vi == null && _selectedWallet?.id == viDen.id) _selectedWallet = null;
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
    final goiY = danhMuc != null ? kq.goiY : null;
    final lyDo = danhMuc != null ? kq.lyDoDanhMuc : null;
    setState(() {
      if (goiY != null) _choPhanXu = (goiY: goiY, ghiChu: _noteController.text.trim());
      _ketQuaDien = (
        tomTat: cauDaDien(kq, tenVi: vi?.name, tenViDen: viDen?.name, tenDanhMuc: danhMuc?.name, now: now),
        docDuoc: true,
        quaAi: kq.quaAi,
        canhBao: kq.canhBao,
        lyDo: lyDo,
      );
    });
    // Ô Nhập nhanh điền xong mà danh mục VÀ ghi chú còn trống (câu chỉ có số tiền) → nguồn số tiền được thử (dự án C).
    // Form biến động, hoặc câu có để lại ghi chú, thì hàm tự thoát.
    _henGoiYTheoForm();
  }

  /// Hoãn việc tra cứu gợi ý cho tới khi người dùng ngừng gõ.
  ///
  /// `TextEditingController` phát tín hiệu ở MỖI ký tự. Không hoãn thì một ghi
  /// chú 30 ký tự sinh 30 lượt đọc CSDL, mỗi lượt lại đọc thêm từ khoá — và
  /// mọi kết quả trừ cái cuối đều bị vứt đi.
  Timer? _hoanGoiY;
  static const Duration _doTreGoiY = Duration(milliseconds: 300);

  /// Số tiền đang trên màn dưới dạng MỘT con số, hoặc `null` khi chưa có (0) hay phép tính còn dở (`"30000+"`). Phép
  /// tính đủ hai vế tính trên TỔNG — bàn phím không có phím `=`, biểu thức nằm nguyên tới lúc lưu (spec dự án C 3.1).
  double? _soTienDangCo() {
    if (coToanTu(_amountString) && !coPhepToanDangCho(_amountString)) return null;
    final x = ketQuaBieuThuc(_amountString);
    return x > 0 ? x : null;
  }

  /// Nguồn số tiền có được dùng ở lượt mở màn này không — MỘT định nghĩa cho cả chỗ hẹn lẫn chỗ đoán: đã có mô hình,
  /// không ở chế độ sửa, không phải form biến động số dư (người dùng không chọn hai chỗ ấy cho lần này — spec mục 2
  /// hàng 4). Hai chỗ mỗi nơi một bản chép thì bỏ một vế ở MỘT chỗ vẫn xanh (đo bằng bản sai 2026-10-02).
  bool get _coNguonSoTien => _boSoTien != null && !_isEditing && _bienDong == null;

  /// Dự án C — hẹn tính lại thẻ gợi ý khi một tín hiệu của nguồn SỐ TIỀN đổi (số tiền, ví, ngày, đoạn). Dùng CÙNG timer
  /// với ghi chú: thẻ chỉ có một, nên chỉ một lượt tính đang chờ.
  ///
  /// Thoát sớm khi nguồn số tiền không dùng được ([_coNguonSoTien]) → mọi đường cũ (B1, từ khoá) không đổi một bước nào.
  void _henGoiYTheoForm() {
    if (!_coNguonSoTien) return;
    // Gợi ý số tiền đã hiện mà bậc vừa đổi: thẻ ấy nói về bậc cũ — huỷ, không phải phán xét của người dùng (spec 3.4).
    // Đặt Ở ĐÂY chứ không chỉ trong `_loadSuggestion`: khi người dùng đã chọn danh mục qua bảng rồi mới đổi số tiền,
    // `_loadSuggestion` không chạy nữa, và gợi ý cũ sẽ bị ghi `khac` lúc lưu cho một khoản ở bậc khác hẳn.
    final cho = _choPhanXu;
    if (cho != null && cho.goiY.nguon == kNguonGoiYSoTien) {
      final x = _soTienDangCo();
      if (x == null || maBacCua(bacTienCua(x)) != cho.goiY.amTietChinh) _choPhanXu = null;
    }
    // Ghi chú có chữ thì thẻ thuộc về B1 / từ khoá, mà số tiền, ví, ngày, đoạn không phải tín hiệu của hai nguồn ấy —
    // không hẹn gì. ⚠️ Hẹn ở đây là ĐỔI hành vi cũ: đổi đoạn Chi ↔ Thu vốn gỡ thẻ B1 cho tới khi ghi chú đổi (và
    // "đổi đoạn → không ghi phản hồi" dựa vào đó); hẹn lại là thẻ B1 tự bật lên sau mỗi lần chạm đoạn.
    if (_noteController.text.trim().isNotEmpty) return;
    _hoanGoiY?.cancel();
    if (_isTransfer || _selectedCategory != null) return;
    _hoanGoiY = Timer(_doTreGoiY, () {
      if (mounted) unawaited(_loadSuggestion(_noteController.text.trim()));
    });
  }

  /// Nguồn thứ ba của thẻ gợi ý (dự án C), CHỈ gọi khi ghi chú trống: đoán theo bậc tiền + nhóm thứ + ví, chỉ danh mục
  /// đúng chiều của đoạn đang chọn. `null` = chưa đủ để nói.
  CategorySuggestion? _goiYSoTien(List<Category> categories) {
    final bo = _boSoTien;
    if (bo == null || !_coNguonSoTien || _isTransfer) return null;
    final soTien = _soTienDangCo();
    if (soTien == null) return null;
    final d = bo.doan(
      chieu: _huong,
      soTien: soTien,
      ngay: _selectedDate,
      walletId: _selectedWallet?.id,
      hopLe: hopLeTheoChieu(_huong, categories),
      tatCap: {..._tatCapSoTien, ..._boQuaSoTienLuotNay},
    );
    if (d == null) return null;
    final cat = categories.firstWhere((c) => c.id == d.categoryId);
    return CategorySuggestion(
      category: cat,
      matchedKeyword: d.maBac,
      nguon: kNguonGoiYSoTien,
      amTietChinh: d.maBac,
      lyDo: cauLyDoSoTien(d, tenDanhMuc: cat.name),
    );
  }

  void _onNoteChanged() {
    _henDeXuat();
    _hoanGoiY?.cancel();
    final note = _noteController.text.trim();
    // Controller phát cả khi chỉ đổi con trỏ — so CHỮ, không coi mỗi lần phát là "đổi ghi chú".
    if (_choPhanXu != null && note != _choPhanXu!.ghiChu) _choPhanXu = null;
    if (_isTransfer || _selectedCategory != null) {
      if (_suggestion != null && mounted) {
        setState(() => _suggestion = null);
      }
      return;
    }
    if (note.isEmpty) {
      // Thẻ B1 / từ khoá nói về chữ vừa bị xoá — gỡ NGAY như trước dự án C; thẻ số tiền thì chính là của ô trống.
      if (_suggestion != null && _suggestion!.nguon != kNguonGoiYSoTien && mounted) {
        setState(() => _suggestion = null);
      }
      // Không có mô hình số tiền thì ghi chú trống là hết việc — đúng hành vi trước dự án C.
      if (_boSoTien == null) return;
    } else if (_suggestion?.nguon == kNguonGoiYSoTien && mounted) {
      // Chữ đầu tiên vừa vào ô ghi chú: thẻ số tiền chỉ dành cho ô TRỐNG — gỡ NGAY, không chờ độ trễ; để nó đứng thêm
      // 300 ms là người dùng thấy thẻ cãi lại chữ họ đang gõ.
      setState(() => _suggestion = null);
    }
    _hoanGoiY = Timer(_doTreGoiY, () {
      if (!mounted) return;
      // Đọc lại từ controller thay vì dùng `note` đã bắt ở trên: trong lúc chờ
      // người dùng có thể đã gõ tiếp, và thứ đáng gợi ý là văn bản HIỆN TẠI.
      _loadSuggestion(_noteController.text.trim());
    });
  }

  void _henDeXuat() {
    _hoanDeXuat?.cancel();
    _hoanDeXuat = Timer(_doTreGoiY, () => unawaited(_tinhDeXuat()));
  }

  /// Đề xuất thêm từ khoá (spec 2026-09-30) — tính lại khi ghi chú hoặc danh mục đổi. Mọi nguồn danh mục như nhau
  /// (chọn tay, thẻ gợi ý, Nhập nhanh). Không phiên / không mẫu học → im.
  Future<void> _tinhDeXuat() async {
    final cat = _selectedCategory;
    final ghiChu = _noteController.text.trim();
    final mau = _mauDeXuat ?? _boPhanLoai?.mau;
    if (cat == null || _isTransfer || ghiChu.isEmpty || mau == null || _accountId() == null) {
      if (mounted && _deXuat != null) setState(() => _deXuat = null);
      return;
    }
    final (chonDuoc, tuKhoa) = await _napDanhMucVaTuKhoa();
    if (!mounted || _selectedCategory?.id != cat.id || _isTransfer || _noteController.text.trim() != ghiChu) return;
    final ten = {for (final c in chonDuoc) c.id: c.name};
    final d = deXuatTuKhoa(
      ghiChu: ghiChu,
      categoryId: cat.id,
      mau: mau,
      // Chỉ danh mục còn sống: từ khoá của danh mục đã xoá không phải xung đột.
      tuKhoa: {for (final e in tuKhoa.entries) if (ten.containsKey(e.key)) e.key: e.value},
      tatCap: {..._tatCapTuKhoa, ..._boQuaLuotNay},
    );
    setState(() => _deXuat = d == null
        ? null
        : (dx: d, tenDanhMuc: cat.name, tenCu: d.tuDanhMuc == null ? null : ten[d.tuDanhMuc]));
  }

  CategorySuggestion _goiYCua(DeXuatTuKhoa d) => CategorySuggestion(
        category: _selectedCategory!,
        matchedKeyword: d.tuKhoa,
        nguon: kNguonDeXuatTuKhoa,
        amTietChinh: d.cumBoDau,
      );

  /// Thêm / Chuyển — GHI NGAY (spec §2.3). Chuyển bỏ ở danh mục cũ TRƯỚC: không có khoảnh khắc cụm thuộc hai danh mục
  /// (bộ so coi hai danh mục khớp ngang nhau là hoà → thôi đoán).
  Future<void> _chapNhanDeXuat() async {
    final d = _deXuat;
    final id = _accountId();
    if (d == null || id == null || _selectedCategory == null) return;
    final goiY = _goiYCua(d.dx);
    setState(() => _deXuat = null);
    try {
      final tuKhoa = await _categoryRepository.loadAllKeywords(accountId: id);
      final cu = d.dx.tuDanhMuc;
      if (cu != null) {
        await _categoryRepository.saveKeywords(
          accountId: id,
          categoryId: cu,
          keywords: [for (final k in tuKhoa[cu] ?? const <String>[]) if (!cungTuKhoa(k, d.dx.tuKhoa)) k],
        );
      }
      await _categoryRepository.saveKeywords(
        accountId: id,
        categoryId: d.dx.categoryId,
        keywords: [...?tuKhoa[d.dx.categoryId], d.dx.tuKhoa],
      );
    } catch (e) {
      debugPrint('[DeXuatTuKhoa] ghi từ khoá lỗi: $e');
      return;
    }
    _ghiPhanHoi(goiY, kKetQuaGoiYChon, chon: d.dx.categoryId);
    if (!mounted) return;
    setState(() => _daThemTuKhoa = d.tenCu == null
        ? 'Đã thêm ‘${d.dx.tuKhoa}’ vào ${d.tenDanhMuc}'
        : 'Đã chuyển ‘${d.dx.tuKhoa}’ sang ${d.tenDanhMuc}');
    _anDaThem?.cancel();
    _anDaThem = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _daThemTuKhoa = null);
    });
  }

  void _boQuaDeXuat() {
    final d = _deXuat;
    if (d == null || _selectedCategory == null) return;
    _ghiPhanHoi(_goiYCua(d.dx), kKetQuaGoiYBoQua);
    setState(() {
      _boQuaLuotNay.add((d.dx.cumBoDau, d.dx.categoryId));
      _deXuat = null;
    });
  }

  Future<void> _loadSuggestion(String note) async {
    final accountId = _accountId();
    // Chưa có phiên thì không gợi ý gì — đọc danh mục bằng mã admin là gợi ý
    // danh mục của người khác.
    if (accountId == null) return;
    // MỘT cửa cho cả ba nguồn (dự án C): hàm này nay được hẹn cả khi số tiền / ví / ngày / đoạn đổi, không chỉ khi
    // ghi chú đổi — nên tự nó phải chặn hai trạng thái không bao giờ có thẻ.
    if (_isTransfer || _selectedCategory != null) return;
    final requestedHuong = _huong;
    final soTienLucHoi = _amountString;
    final viLucHoi = _selectedWallet?.id;
    final ngayLucHoi = _selectedDate;
    // Đoạn Chi/Thu chỉ là lối vào, không khoanh vùng gợi ý: tìm trên cả ba
    // phân loại vì chiều tiền suy từ danh mục được chọn, không phải ngược lại.
    final categories = await _categoryRepository.selectableChildrenAll(
      accountId: accountId,
    );
    CategorySuggestion? suggestion;
    if (note.isEmpty) {
      // Dự án C: ghi chú TRỐNG → đoán theo số tiền. KHÁC hai nguồn dưới, nguồn này khoanh theo đoạn Chi/Thu: số tiền
      // không mang nghĩa chiều, đoạn đang chọn là thông tin chiều duy nhất.
      //
      // ⚠️ CHỈ khi ghi chú trống (người dùng chốt 2026-10-02 sau phép đo CSDL thật): bản đầu còn dùng nguồn này khi
      // ghi chú có chữ mà B1 lẫn từ khoá đều im, và 3/4 lần thẻ sai rơi đúng vào đó — *"ca phe sang"* 10.000 → Di
      // chuyển, thẻ nói ngược chữ người dùng vừa gõ.
      suggestion = _goiYSoTien(categories);
    } else {
      // B1: mô hình HỌC đi trước — nó nói từ chính các lần người dùng tự chốt danh mục. `null` = chưa đủ để nói
      // (sổ mỏng, ghi chú lạ, hậu nghiệm thấp, cặp đang bị thôi gợi ý) → bảng từ khoá như trước B1.
      // `hopLe` = mọi danh mục chọn được, cả ba phân loại — cùng nếp "đoạn Chi/Thu không khoanh vùng gợi ý" ở trên.
      final doan = _boPhanLoai?.doan(
        note,
        hopLe: {for (final c in categories) c.id},
        tatCap: _tatCap,
      );
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
    }
    if (!mounted ||
        _huong != requestedHuong ||
        _isTransfer ||
        _selectedCategory != null ||
        _noteController.text.trim() != note ||
        _amountString != soTienLucHoi ||
        _selectedWallet?.id != viLucHoi ||
        _selectedDate != ngayLucHoi) {
      return;
    }
    final truoc = _suggestion;
    setState(() {
      _suggestion = suggestion;
      if (suggestion != null) {
        _choPhanXu = (goiY: suggestion, ghiChu: note);
      } else if (_choPhanXu?.goiY.nguon == kNguonGoiYSoTien) {
        // Thẻ số tiền vừa bị thay bằng "không có gì" (bậc / ví / ngày / đoạn đổi): gợi ý cũ không còn là thứ người
        // dùng đang nhìn — bỏ, không ghi phản hồi nào cho nó.
        _choPhanXu = null;
      }
    });
    // Chỉ khi thẻ nguồn số tiền VỪA hiện (hoặc đổi sang danh mục khác). Cùng một gợi ý được tính lại ở mỗi phím số
    // thì không cuộn — người dùng đã cuộn đi là có chủ ý.
    if (suggestion != null &&
        suggestion.nguon == kNguonGoiYSoTien &&
        (truoc?.nguon != kNguonGoiYSoTien || truoc?.category.id != suggestion.category.id)) {
      _cuonToiTheGoiY();
    }
  }

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

  void _showWalletPickerBottomSheet(BuildContext context,
      {required bool isDestination}) {
    // `isScrollControlled` + danh sách ví trong `Flexible` / `SingleChildScrollView`: bảng cao theo số ví và CUỘN khi
    // nhiều ví hơn chỗ trống. Bản cũ là `Column` không cuộn trong trần 9/16 màn — đo trên OnePlus 13R (2026-09-30,
    // nghiệm thu D1) tài khoản 5 ví tràn 13 px, ví cuối bị sọc vàng đè và không chạm được. Cùng họ G60.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
                  // `Expanded`: tiêu đề trần trong `Row` tràn khi cỡ chữ hệ thống lớn.
                  Expanded(
                    child: Text(
                      isDestination ? 'Chọn ví đích' : 'Chọn ví thanh toán',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                      // Ví là một tín hiệu của gợi ý theo số tiền (dự án C); ví ĐÍCH thì không.
                      if (!isDestination) _henGoiYTheoForm();
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
                  ),
                ),
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
    _henGoiYTheoForm();
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
      // Nhóm thứ (ngày thường / cuối tuần) là một tín hiệu của gợi ý theo số tiền (dự án C).
      _henGoiYTheoForm();
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
    if (!_isTransfer && _selectedCategory == null) {
      baoNhanh('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      return;
    }
    if (_isTransfer && _destinationWallet == null) {
      baoNhanh('Vui lòng chọn ví đích', loai: LoaiThongBao.loi);
      return;
    }
    final type = _resolvedType;
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
            final impactText = budgetImpactSnackText(_pendingImpact);
            _pendingImpact = null;
            // Lưu kèm cảnh báo ngân sách ("Đã lưu. Ngân sách X đã vượt hạn mức.") là
            // THÔNG TIN, không phải xong trơn.
            baoNhanh(
              impactText ?? (_isEditing ? 'Đã lưu thay đổi' : 'Thêm giao dịch thành công!'),
              loai: impactText == null ? LoaiThongBao.xong : LoaiThongBao.thongTin,
            );
            final d = _bienDong;
            final id = _accountId();
            if (d != null && id != null) {
              final gy = _goiYDaApDung;
              final v = _viGoiY;
              if (gy != null && v != null && _isTransfer) {
                unawaited(_dongChuyenKhoan(d, gy, id,
                    viTu: _selectedWallet?.id,
                    viDen: _destinationWallet?.id,
                    daNhoTu: v.daNhoTu,
                    daNhoDen: v.daNhoDen));
              } else {
                unawaited(_dongBienDong(d, id, viDaLuu: _selectedWallet?.id, nhoVi: !_viNguonDaNho));
              }
            }
            context.pop(true);
          } else if (state.actionSuccess == false &&
              state.errorMessage != null) {
            baoNhanh('Lỗi: ${state.errorMessage}', loai: LoaiThongBao.loi);
          }
        }
      },
      builder: (context, state) {
        final isSubmitting = state is TransactionLoadedState && state.isSubmitting;
        final coBanPhimSo = _coBanPhimSo(context);
        // MỘT luật cho nút lưu: 16 phím (mang phím ✓) không trên màn thì ✓ ở thanh tiêu đề — cả khi ẩn theo cờ lẫn
        // khi bàn phím hệ thống đang mở (G58; trước 2026-09-30 lúc gõ ghi chú là không có nút lưu nào).
        final luuTieuDe = coBanPhimSo
            ? null
            : IconButton(
                key: const Key('luu-thanh-tieu-de'),
                tooltip: 'Lưu giao dịch',
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
            title: Text(
              _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
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
                  child: _buildSegmentControl(),
                ),
                const SizedBox(height: 16),
                _buildAmountDisplay(),
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
                          _buildDaiNguon(d),
                          const SizedBox(height: 12),
                          if (_goiYChuyen case final gy? when !_isTransfer) ...[
                            _buildGoiYChuyen(gy),
                            const SizedBox(height: 12),
                          ],
                        ] else if (!_isEditing) ...[
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
                // Từ 2026-09-30 còn ẩn khi màn đã có số tiền ([_hienBanPhimSo]); ✓ khi ấy ở thanh tiêu đề.
                // 2026-10-06 (Stitch `fb68baba…`): 16 phím do app tự vẽ, hệ điều hành
                // không báo `viewInsets` — báo chiều cao cho AppToast để viên lỗi lúc
                // bấm ✓ nổi TRÊN bàn phím thay vì đè hai hàng phím dưới.
                if (coBanPhimSo)
                  BaoCheDayToast(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: _buildNumericKeyboard(context, isSubmitting: isSubmitting),
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

  /// 16 phím có trên màn không: cờ [_hienBanPhimSo] **và** bàn phím hệ thống đang đóng (G58).
  bool _coBanPhimSo(BuildContext context) => _hienBanPhimSo && MediaQuery.viewInsetsOf(context).bottom == 0;

  /// Chạm khối số tiền. Bàn phím hệ thống đang mở (gõ ghi chú) thì 16 phím bị G58 giấu dù cờ bật — đảo cờ lúc ấy
  /// là tắt phím đi mà người dùng không thấy gì đổi; nên đóng bàn phím hệ thống và MỞ 16 phím.
  void _chamSoTien() {
    final banPhimHeThong = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (banPhimHeThong) FocusScope.of(context).unfocus();
    setState(() => _hienBanPhimSo = banPhimHeThong || !_hienBanPhimSo);
  }

  Widget _buildAmountDisplay() {
    final coPhepToan = coPhepToanDangCho(_amountString);
    // Gợi ý chỉ khi 16 phím ẩn THEO CỜ (Stitch `b52c0651…` — "Bàn phím ẩn khi đã có số tiền"); biểu thức gõ dở thì dòng
    // `= tổng` quan trọng hơn — đó là chỗ duy nhất tổng hiện ra trước khi lưu.
    final goiYCham = !_hienBanPhimSo && !coPhepToan;
    return GestureDetector(
      key: const Key('so-tien-cham'),
      behavior: HitTestBehavior.opaque,
      onTap: _chamSoTien,
      child: Column(
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
        if (goiYCham)
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 14, color: AppColors.outline),
              SizedBox(width: 4),
              Text(
                'Chạm để sửa số tiền',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.outline),
              ),
            ],
          )
        else
          Text(
            coPhepToan
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
      ),
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
            ? '${_selectedWallet!.name} • ${CurrencyFormatter.formatLienKhoi(_selectedWallet!.balance)}'
            : 'Chọn ví');

    final destWalletDisplay = _isLoadingWallets
        ? 'Đang tải ví...'
        : (_destinationWallet != null
            ? '${_destinationWallet!.name} • ${CurrencyFormatter.formatLienKhoi(_destinationWallet!.balance)}'
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
            if (_bienDong != null && _trungTrongSo.isNotEmpty) _buildNhacTrung(context),
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
            if (_deXuat != null || _daThemTuKhoa != null) _buildDeXuatTuKhoa(),
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
              // D1: giờ trong tin là giờ giao dịch — hiện ra để người dùng thấy nó được giữ.
              DateFormat(_bienDong != null ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 16, color: AppColors.primary),
            ),
            trailingIcon: Icons.calendar_month,
            onTap: _pickDate,
          ),
        ],
      ),
    );
  }

  /// D1 — dải nguồn (Stitch `52d9d2ef…`): *"Từ thông báo MB Bank · TK ••7777 · 02/09 12:01"*.
  Widget _buildDaiNguon(DienSanBienDong d) => Container(
        key: const Key('bien-dong-dai-nguon'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Chia sẻ biên lai: hàng mang ảnh → ảnh nhỏ thay biểu tượng ngân hàng, chạm để xem to. Khung CỐ ĐỊNH
            // 48 × 64 (biên lai dọc) để dải không nhảy chiều cao khi ảnh giải mã xong.
            if (_duongDanAnh case final p?)
              Semantics(
                button: true,
                label: 'Xem ảnh biên lai',
                child: GestureDetector(
                  key: const Key('bien-lai-anh-nho'),
                  onTap: () => xemAnhBienLai(context, p),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 64,
                      child: Image.file(
                        File(p),
                        fit: BoxFit.cover,
                        // Canh GIỮA: ảnh chia sẻ từ app ngân hàng là ảnh toàn màn, thẻ biên lai nằm giữa — canh đỉnh là
                        // ảnh nhỏ chỉ thấy nền (đo Realme 2026-10-02, biên lai MB Bank 1080 × 2400).
                        alignment: Alignment.center,
                        cacheWidth: 144,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: AppColors.surfaceContainerHigh,
                          child: Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Icon(d.cachDoc == null ? Icons.account_balance : Icons.receipt_long_outlined,
                  size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dongNguonBienDong(d),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (dongPhuBienLai(d.cachDoc) case final phu?) ...[
                    const SizedBox(height: 4),
                    Text(
                      phu,
                      key: const Key('bien-lai-dong-phu'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  /// Thẻ gợi ý Chuyển khoản (spec 2026-09-30 §4, Stitch *"Thêm giao dịch - Gợi ý chuyển khoản từ biến động"*).
  Widget _buildGoiYChuyen(GoiYChuyenKhoan gy) => Container(
        key: const Key('the-goi-y-chuyen-khoan'),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        // Nút ở hàng RIÊNG, căn phải: cùng hàng với chữ thì ở 360 dp cả hai dòng chữ ngắt đôi (đo Realme 2026-09-30).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                  child: const Icon(Icons.swap_horiz, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Có vẻ là chuyển khoản',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Từ ${gy.nguonTu} sang ${gy.nguonDen}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              key: const Key('goi-y-chuyen-khoan'),
              onPressed: _apGoiYChuyen,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Ghi là chuyển khoản', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );

  /// D1 — *"Có thể bạn đã ghi khoản này"* (spec §3.3): chỉ NHẮC, không chặn lưu. **Xem** liệt kê các khoản khớp.
  Widget _buildNhacTrung(BuildContext context) {
    final d = _bienDong!;
    final chieu = d.chieu == 'thu' ? 'thu' : 'chi';
    return Container(
      key: const Key('bien-dong-nhac-trung'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Có thể bạn đã ghi khoản này',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyFormatter.format(d.soTien!)} $chieu hôm '
                  '${DateFormat('dd/MM').format(d.thoiGian!)} đã có trong sổ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () => _xemKhoanTrung(context), child: const Text('Xem')),
        ],
      ),
    );
  }

  Future<void> _xemKhoanTrung(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Khoản đã có trong sổ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                for (final k in _trungTrongSo)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(k.ghiChu.isEmpty ? '(không ghi chú)' : k.ghiChu),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(k.ngay)),
                    trailing: Text(CurrencyFormatter.formatCoDau(k.soTien, thu: k.loai == 'thu')),
                  ),
              ],
            ),
          ),
        ),
      );

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
                    // Basic khoá cả ô — spec Premium 8.2.
                    enabled: _laPremium,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _dienTuCau(),
                    style: const TextStyle(fontSize: 15, color: AppColors.primary),
                    // ⚠️ Tắt CẢ nền và ba loại viền: theme của app đặt `filled` + `enabledBorder` / `focusedBorder` cho
                    // mọi ô nhập, `border: none` một mình không che được — máy thật hiện một ô trắng có viền nằm
                    // trong khung xám (nghiệm thu Realme 2026-09-30).
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: _laPremium ? 'VD: hôm qua ăn phở 45k tiền mặt' : 'Tính năng Premium',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.outlineVariant),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // `minimumSize` hữu hạn: theme của app ép mọi ElevatedButton rộng vô hạn (bẫy 4.11).
                if (_laPremium)
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
                  )
                else
                  const NutNangCap(),
              ],
            ),
          ),
          if (!_laPremium)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Nâng cấp để đọc câu bằng AI',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

  /// Dòng đề xuất thêm / chuyển từ khoá (spec 2026-09-30, màn Stitch `8ca1338e…`).
  Widget _buildDeXuatTuKhoa() {
    final daThem = _daThemTuKhoa;
    final d = _deXuat;
    const dam = TextStyle(fontWeight: FontWeight.w700);
    return Container(
      key: const Key('de-xuat-tu-khoa'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: daThem != null || d == null
          ? Row(children: [
              const Icon(Icons.check_circle, color: AppColors.income, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(daThem ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
              ),
            ])
          : Row(children: [
              Icon(d.tenCu == null ? Icons.add_circle : Icons.sync, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  d.tenCu == null
                      ? TextSpan(children: [
                          const TextSpan(text: 'Thêm '),
                          TextSpan(text: '‘${d.dx.tuKhoa}’', style: dam),
                          const TextSpan(text: ' làm từ khoá của '),
                          TextSpan(text: d.tenDanhMuc, style: dam),
                          const TextSpan(text: '?'),
                        ])
                      : TextSpan(children: [
                          TextSpan(text: '‘${d.dx.tuKhoa}’', style: dam),
                          const TextSpan(text: ' đang là từ khoá của '),
                          TextSpan(text: d.tenCu, style: dam),
                          const TextSpan(text: ' — chuyển sang '),
                          TextSpan(text: d.tenDanhMuc, style: dam),
                          const TextSpan(text: '?'),
                        ]),
                  style: const TextStyle(fontSize: 13, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              // ⚠️ `minimumSize` hữu hạn BẮT BUỘC (bẫy 4.11): theme ép ElevatedButton rộng vô hạn.
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: _chapNhanDeXuat,
                child: Text(d.tenCu == null ? 'Thêm' : 'Chuyển'),
              ),
              IconButton(
                tooltip: 'Bỏ qua đề xuất',
                icon: const Icon(Icons.close, size: 18),
                onPressed: _boQuaDeXuat,
              ),
            ]),
    );
  }

  Widget _buildSuggestionCard(CategorySuggestion suggestion) => Container(
        key: _khoaTheGoiY,
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
            // `Wrap` chứ không `Row` + `Spacer`: đủ chỗ thì hai nút nằm hai đầu một hàng y như trước; chật (màn 360 dp
            // với cỡ chữ lớn) thì nút sau XUỐNG DÒNG thay vì tràn sọc vàng. Từ dự án C thẻ này hiện cả khi 16 phím số
            // đang mở — tức thường xuyên hơn hẳn. `SizedBox` rộng hết cỡ để `spaceBetween` có chỗ mà giãn: `Wrap` trong
            // `Column` căn trái tự co theo nội dung, hai nút sẽ dính vào nhau.
            SizedBox(
              width: double.infinity,
              child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () {
                    _ghiPhanHoi(suggestion, kKetQuaGoiYBoQua);
                    if (suggestion.nguon == kNguonGoiYSoTien) {
                      _boQuaSoTienLuotNay.add((suggestion.amTietChinh, suggestion.categoryId));
                    }
                    setState(() {
                      _suggestion = null;
                      _choPhanXu = null;
                    });
                  },
                  child: const Text('Bỏ qua'),
                ),
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
      key: const Key('ban-phim-so'),
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

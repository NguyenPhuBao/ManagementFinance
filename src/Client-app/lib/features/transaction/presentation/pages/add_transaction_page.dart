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
import '../../domain/doc_mon_hang.dart';
import '../../domain/doc_cau_giao_dich.dart';
import '../../domain/goi_y_chuyen_khoan.dart';
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
import '../../../../features/category/data/models/category_suggestion.dart';
import '../../../../features/category/data/repositories/category_management_repository.dart';
import '../../../../features/category/data/services/category_suggestion_engine.dart';
import '../../../../features/category/domain/de_xuat_tu_khoa.dart';
import '../../../../features/category/domain/gan_hang_loat.dart' show hopLeTheoChieu;
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
  BoPhanLoaiGhiChu? get _boPhanLoai => _cubit.boPhanLoai;
  BoPhanLoaiSoTien? get _boSoTien => _cubit.boSoTien;
  List<MauGhiChu>? get _mauDeXuat => _cubit.mauDeXuat;
  Wallet? get _selectedWallet => _s.viNguon;
  Wallet? get _destinationWallet => _s.viDich;
  Category? get _selectedCategory => _s.danhMuc;
  String? get _debtDirection => _s.chieuNo;
  DateTime get _selectedDate => _s.ngay;
  bool get _isLoadingWallets => _s.dangNapVi;
  List<PhanTach> get _phanTach => _s.phanTach;
  Map<String, Category> get _dmTheoId => _s.dmTheoId;

  /// Cặp (cụm, danh mục) đang bị thôi gợi ý (`tatCapTu`) — nạp một lần sau khi có mô hình.
  Set<(String, String)> _tatCap = const {};

  /// Cặp (mã bậc, danh mục) của nguồn số tiền đang bị thôi gợi ý (`tatCapSoTienTu`).
  Set<(String, String)> _tatCapSoTien = const {};

  /// Cặp người dùng vừa bấm *Bỏ qua* trong lượt mở màn này. Thẻ nguồn số tiền tính lại ở MỖI phím số, nên thiếu tập
  /// này thì bấm Bỏ qua xong gõ thêm một chữ số cùng bậc là thẻ bật lại ngay (cùng nếp [_boQuaLuotNay]).
  final Set<(String, String)> _boQuaSoTienLuotNay = {};

  /// Cặp (cụm, danh mục) đang bị thôi ĐỀ XUẤT TỪ KHOÁ — tập riêng của nguồn `kNguonDeXuatTuKhoa` (spec 2026-09-30 §2.4).
  Set<(String, String)> _tatCapTuKhoa = const {};

  /// Cặp người dùng vừa ✕ trong lượt này — dòng ẩn tới khi rời màn.
  final Set<(String, String)> _boQuaLuotNay = {};

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

  CategorySuggestion? _suggestion;

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

  /// Kết quả lần *Điền* gần nhất, để dựng dòng tóm tắt dưới ô; `null` khi chưa điền lần nào.
  KetQuaDien? _ketQuaDien;
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

  /// Tác động lên ngân sách của khoản vừa gửi đi, để listener chọn lời nhắn
  /// sau khi lưu xong. Đặt ngay trước khi gửi event, xoá ngay khi đã dùng.
  BudgetImpact? _pendingImpact;

  TransactionEntity? get _editing => widget.initial?.transaction;
  bool get _isEditing => _editing != null;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    if (editing != null) {
      // Điền sẵn TRƯỚC khi gắn listener ghi chú, để lần gán text đầu không
      // kích hoạt tra cứu gợi ý. (Phần còn lại của đường sửa do Cubit dựng sẵn.)
      _noteController.text = editing.note;
    }
    _noteController.addListener(_onNoteChanged);
    _nhapNhanhFocus.addListener(() {
      if (_nhapNhanhFocus.hasFocus) unawaited(_nguon.docAi?.chuanBi());
    });
    // Đường sửa mở với danh mục + ghi chú sẵn → tính đề xuất từ khoá sau khi có mẫu và tập tắt.
    final napHoc = _cubit.moTrang().then((_) => _napTatCap());
    unawaited(napHoc.then((_) => _tinhDeXuat()));
    // D1: điền sau khi có cả ví (chọn sẵn theo nguồn) lẫn mô hình B1 + tập tắt (đoán danh mục).
    if (_bienDong != null) unawaited(napHoc.then((_) => _dienTuBienDong()));
    // Chia sẻ biên lai: hàng đang mở mang ảnh → tìm tệp. Tệp đã mất thì dải nguồn dựng như không có ảnh.
    if (_bienDong?.anh case final anh?) {
      // A5: ảnh quét nằm ở kho RIÊNG (`anh_quet/`), kèm danh sách món (mục 11.2b).
      unawaited(_nguon.duongDanAnh(_bienDong!).then((p) {
        if (mounted && p != null) setState(() => _duongDanAnh = p);
      }));
      if (_laQuet && widget.choTickMon) {
        unawaited(_nguon.docMonQuet(anh).then((m) {
          if (mounted) setState(() => _monQuet = m);
        }));
      }
    }
  }

  /// A5 — form mở từ ảnh quét (khoá `quet:`): không nguồn ngân hàng, không hàng loại 20.
  bool get _laQuet => _bienDong?.laQuet ?? false;

  /// A5 mục 11.2b — danh sách món của ảnh quét loại hoá đơn (rỗng: biên lai, gõ tay, đọc hỏng) — sheet *Thêm phần*
  /// cho tick món thay vì gõ số.
  List<MonHang> _monQuet = const [];

  /// Số giao dịch của lần Lưu đang chờ `actionSuccess` — toast *"Đã lưu N giao dịch"*.
  int _soGiaoDichVuaLuu = 1;

  /// Đường dẫn ảnh biên lai của hàng đang mở; `null` = không có ảnh (hoặc chưa tìm xong).
  String? _duongDanAnh;

  /// D1 — điền form từ hàng biến động số dư, qua ĐÚNG đường điền của C2 ([_dienKetQua]). Không lưu.
  Future<void> _dienTuBienDong() async {
    final d = _bienDong;
    final id = _accountId();
    if (d == null || !mounted) return;
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(_accountId());
    String? viId;
    // A5: ảnh quét không gắn nguồn ngân hàng → không bảng "nguồn → ví"; giữ ví mặc định đã chọn sẵn.
    if (id != null && !_laQuet) {
      try {
        // Dòng nhắc (không đuôi TK) thì thử thêm ví của cả NGUỒN — chỉ khi nó chắc (một ví duy nhất).
        final nho = await _nguon.viTheoNguon(id, d.nguon, d.duoi) ??
            (d.phien != null ? await _nguon.viTheoNguonChung(id, d.nguon) : null);
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
    // Lần đầu của cặp nguồn + đuôi: ví TRỐNG, không phải ví mặc định — để ví mặc định là để bảng nguồn → ví học nhầm
    // nó ở lần Lưu đầu, rồi chọn sẵn sai mãi.
    if (viId == null && !_laQuet) _cubit.ghiOLoi(viNguon: null, datViNguon: true);
    // `_dienKetQua` chỉ đổi phần ngày; giờ trong tin là giờ giao dịch (spec §3.3).
    final t = d.thoiGian;
    if (t != null) _cubit.ghiOLoi(ngay: t);
    // A5 (spec 5.6): gợi ý chuyển khoản và nhắc trùng của D1 không áp cho ảnh quét.
    if (id == null || _laQuet) return;
    unawaited(_tinhGoiYChuyen(d, id));
    try {
      final so = await _nguon.khoanTrongSo(id);
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
      final cho = await _nguon.hangBienDongCho(id);
      final gy = goiYChuyenKhoan(d, cho);
      if (gy == null) return;
      Future<String?> nho(String nguon, String? duoi) async {
        final v = await _nguon.viTheoNguon(id, nguon, duoi);
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

    _cubit.ghiOLoi(viNguon: tim(v.tu), datViNguon: true, viDich: tim(v.den), datViDich: true, nguoiDungDaChonVi: true);
    setState(() {
      _goiYDaApDung = gy;
      _goiYChuyen = null;
    });
  }

  /// D1 — xử lý xong một hàng biến động (Lưu hoặc Bỏ qua): xoá CỨNG hàng loại 20 (`NotificationDao.xoaCung`, ngoại lệ
  /// có chủ ý — spec §3.3), và khi Lưu ở lần đầu của cặp nguồn + đuôi thì nhớ ví. Mọi giá trị truyền vào đã chốt lúc
  /// gọi: màn có thể đã `pop`. Không bao giờ ném.
  Future<void> _dongBienDong(DienSanBienDong d, int id, {String? viDaLuu, bool nhoVi = false}) async {
    // A5: form từ ảnh quét — không hàng loại 20, không bảng nguồn → ví; chỉ xoá ảnh (dispose cũng xoá — luỹ đẳng).
    if (d.laQuet) {
      await _nguon.xoaAnhQuet(d.anh);
      return;
    }
    try {
      if (nhoVi && viDaLuu != null) await _nguon.nhoViTheoNguon(id, d.nguon, d.duoi, viDaLuu);
    } catch (e) {
      debugPrint('[BienDong] ghi ví theo nguồn lỗi: $e');
    }
    await _nguon.xoaHangBienDong(id, d.khoa);
    await _nguon.xoaAnhBienLai(d.anh);
  }

  /// Lưu sau khi áp gợi ý Chuyển khoản (spec §5): nhớ ví cho CẢ HAI nguồn — mỗi phía theo phía của nó. ⚠️ Không theo
  /// `_selectedWallet`: tin THU ghi thành chuyển khoản thì ví của nguồn tin là ví ĐÍCH, nhớ ví nguồn là mọi tin sau của
  /// nguồn ấy chọn sẵn sai ví, im lặng. Rồi xoá hàng đang mở và hàng cặp (còn chờ là người dùng ghi đôi). Không ném.
  Future<void> _dongChuyenKhoan(DienSanBienDong d, GoiYChuyenKhoan gy, int id,
      {String? viTu, String? viDen, required bool daNhoTu, required bool daNhoDen}) async {
    try {
      if (!daNhoTu && viTu != null) await _nguon.nhoViTheoNguon(id, gy.nguonTu, gy.duoiTu, viTu);
      if (!daNhoDen && viDen != null) await _nguon.nhoViTheoNguon(id, gy.nguonDen, gy.duoiDen, viDen);
    } catch (e) {
      debugPrint('[BienDong] ghi ví theo nguồn lỗi: $e');
    }
    await _nguon.xoaHangBienDong(id, d.khoa);
    await _nguon.xoaAnhBienLai(d.anh);
    final cap = gy.khoaCap;
    if (cap != null) await _nguon.xoaHangBienDong(id, cap);
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
    final id = _accountId();
    // Hai mô hình độc lập: B1 học lỗi (`null`) không được kéo theo việc bỏ nạp tập tắt của nguồn số tiền.
    if ((bo == null && boTien == null) || id == null) return;
    try {
      final phanHoi = await _nguon.docPhanHoi(id);
      if (phanHoi == null) return;
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
    final id = _accountId();
    if (id == null) return;
    _nguon.ghiPhanHoi(idaccount: id, goiY: goiY, ketQua: ketQua, chon: chon);
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
    unawaited(_cubit.close());
    // A5: ảnh quét chỉ sống tới khi form đóng — MỘT chỗ cho mọi đường thoát (Lưu, Bỏ qua, Back hệ thống, nút ←).
    if (_laQuet) unawaited(_nguon.xoaAnhQuet(_bienDong?.anh));
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
  /// dùng, phần tách); trang chỉ gỡ thẻ gợi ý và tính lại đề xuất từ khoá.
  void _chonDanhMuc(Category category) {
    _cubit.chonDanhMuc(category);
    setState(() => _suggestion = null);
    unawaited(_tinhDeXuat());
  }

  /// Chạm một đoạn Chi tiêu / Thu nhập / Chuyển khoản.
  void _chonHuong(String huong) {
    _cubit.chonHuong(huong);
    setState(() {
      _suggestion = null;
      _choPhanXu = null;
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
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(_accountId());
    // Người dùng chốt 2026-09-30 (spec C2 banner "ĐỔI LẦN HAI"): luật trước — chỉ hỏi mô hình (~18 s trên Realme) khi còn
    // ô câu có nhắc mà luật không đọc được (số tiền, ngày, ví); AI về thì luật kiểm từng ô và chỉ LẤP ô luật để trống.
    KetQuaAi? ai;
    final docAi = _nguon.docAi;
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

  /// Huỷ lượt đọc bằng AI: điền ngay bằng luật, mô hình thôi giải mã.
  Future<void> _huyDocAi() async {
    _luotDien++;
    unawaited(_nguon.docAi?.huy());
    final cau = _nhapNhanhController.text.trim();
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(_accountId());
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
    final soTien = kq.soTien;
    if (soTien != null) _cubit.chonSoTien(soTien);
    final ngay = kq.ngay;
    if (ngay != null) {
      _cubit.ghiOLoi(ngay: DateTime(ngay.year, ngay.month, ngay.day, _selectedDate.hour, _selectedDate.minute));
    }
    if (vi != null) _cubit.ghiOLoi(viNguon: vi, datViNguon: true, nguoiDungDaChonVi: true);
    // Chuyển ví (§2.9). Câu chỉ nêu ví đích mà ví nguồn đang chọn lại chính là nó → để trống ví nguồn cho người dùng
    // chọn: chuyển vào chính nó là khoản vô nghĩa, và màn không chặn lúc lưu.
    if (viDen != null) {
      _cubit.ghiOLoi(viDich: viDen, datViDich: true);
      if (vi == null && _selectedWallet?.id == viDen.id) _cubit.ghiOLoi(viNguon: null, datViNguon: true);
    }
    Category? danhMuc;
    if (!_s.laChuyen && kq.categoryId != null) {
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
      final x = _s.soTienDangCo;
      if (x == null || maBacCua(bacTienCua(x)) != cho.goiY.amTietChinh) _choPhanXu = null;
    }
    // Ghi chú có chữ thì thẻ thuộc về B1 / từ khoá, mà số tiền, ví, ngày, đoạn không phải tín hiệu của hai nguồn ấy —
    // không hẹn gì. ⚠️ Hẹn ở đây là ĐỔI hành vi cũ: đổi đoạn Chi ↔ Thu vốn gỡ thẻ B1 cho tới khi ghi chú đổi (và
    // "đổi đoạn → không ghi phản hồi" dựa vào đó); hẹn lại là thẻ B1 tự bật lên sau mỗi lần chạm đoạn.
    if (_noteController.text.trim().isNotEmpty) return;
    _hoanGoiY?.cancel();
    if (_s.laChuyen || _selectedCategory != null) return;
    _hoanGoiY = Timer(_doTreGoiY, () {
      if (mounted) unawaited(_loadSuggestion(_noteController.text.trim()));
    });
  }

  /// Nguồn thứ ba của thẻ gợi ý (dự án C), CHỈ gọi khi ghi chú trống: đoán theo bậc tiền + nhóm thứ + ví, chỉ danh mục
  /// đúng chiều của đoạn đang chọn. `null` = chưa đủ để nói.
  CategorySuggestion? _goiYSoTien(List<Category> categories) {
    final bo = _boSoTien;
    if (bo == null || !_coNguonSoTien || _s.laChuyen) return null;
    final soTien = _s.soTienDangCo;
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
    if (_s.laChuyen || _selectedCategory != null) {
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
    if (cat == null || _s.laChuyen || ghiChu.isEmpty || mau == null || _accountId() == null) {
      if (mounted && _deXuat != null) setState(() => _deXuat = null);
      return;
    }
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(_accountId());
    if (!mounted || _selectedCategory?.id != cat.id || _s.laChuyen || _noteController.text.trim() != ghiChu) return;
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
      final tuKhoa = await _nguon.tuKhoa(id);
      final cu = d.dx.tuDanhMuc;
      if (cu != null) {
        await _nguon.luuTuKhoa(
          idaccount: id,
          categoryId: cu,
          tuKhoa: [for (final k in tuKhoa[cu] ?? const <String>[]) if (!cungTuKhoa(k, d.dx.tuKhoa)) k],
        );
      }
      await _nguon.luuTuKhoa(
        idaccount: id,
        categoryId: d.dx.categoryId,
        tuKhoa: [...?tuKhoa[d.dx.categoryId], d.dx.tuKhoa],
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
    if (_s.laChuyen || _selectedCategory != null) return;
    final requestedHuong = _huong;
    final soTienLucHoi = _amountString;
    final viLucHoi = _selectedWallet?.id;
    final ngayLucHoi = _selectedDate;
    // Đoạn Chi/Thu chỉ là lối vào, không khoanh vùng gợi ý: tìm trên cả ba
    // phân loại vì chiều tiền suy từ danh mục được chọn, không phải ngược lại.
    final categories = await _nguon.danhMucChonDuoc(accountId);
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
        final keywordsByCategory = await _nguon.tuKhoa(accountId);
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
        _s.laChuyen ||
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
            // Ví là một tín hiệu của gợi ý theo số tiền (dự án C); ví ĐÍCH thì không.
            _henGoiYTheoForm();
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
    _ghiPhanHoiKhiLuu();
    bloc.add(AddTransactionEvent(
      transaction: tx,
      destinationWalletId: tx.walletTransfer,
    ));
  }

  /// B1: thẻ gợi ý đã hiện mà người dùng chọn qua bảng rồi lưu — chọn đúng danh mục gợi ý là `chon`, khác là `khac`.
  /// Khoản đã tách: chỉ cho DANH MỤC CHÍNH (thẻ gợi ý hiện cho nó; phần chọn tay không ghi — spec 11.5).
  void _ghiPhanHoiKhiLuu() {
    final choPhanXu = _choPhanXu;
    final daChon = _selectedCategory;
    if (choPhanXu != null && daChon != null && !_s.laChuyen) {
      _ghiPhanHoi(
        choPhanXu.goiY,
        daChon.id == choPhanXu.goiY.categoryId ? kKetQuaGoiYChon : kKetQuaGoiYKhac,
        chon: daChon.id,
      );
      _choPhanXu = null;
    }
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
    _ghiPhanHoiKhiLuu();
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
      mon: _monQuet,
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
            final d = _bienDong;
            final id = _accountId();
            if (d != null && id != null) {
              final gy = _goiYDaApDung;
              final v = _viGoiY;
              if (gy != null && v != null && _s.laChuyen) {
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
                          DaiNguonBienDong(d: d, duongDanAnh: _duongDanAnh),
                          const SizedBox(height: 12),
                          if (d.luaChonTien.isNotEmpty) ...[
                            KhoiChonSoTien(
                              ds: d.luaChonTien,
                              dangChon: ketQuaBieuThuc(_amountString),
                              onChon: _dienSoTienChon,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_goiYChuyen case final gy? when !_s.laChuyen) ...[
                            TheGoiYChuyen(gy: gy, onApDung: _apGoiYChuyen),
                            const SizedBox(height: 12),
                          ],
                        ] else if (!_isEditing) ...[
                          ONhapNhanh(
                            controller: _nhapNhanhController,
                            focusNode: _nhapNhanhFocus,
                            laPremium: _laPremium,
                            dangDocAi: _dangDocAi,
                            ketQua: _ketQuaDien,
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
    final s = _suggestion; // bắt một lần lúc dựng — callback không đọc lại `_suggestion` lúc chạm
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
      nhacTrung: _bienDong != null && _trungTrongSo.isNotEmpty ? NhacTrung(d: _bienDong!, trung: _trungTrongSo) : null,
      deXuatTuKhoa: _deXuat != null || _daThemTuKhoa != null
          ? DongDeXuatTuKhoa(
              daThem: _daThemTuKhoa,
              deXuat: _deXuat,
              onChapNhan: _chapNhanDeXuat,
              onBoQua: _boQuaDeXuat,
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
              onBoQua: () {
                _ghiPhanHoi(s, kKetQuaGoiYBoQua);
                if (s.nguon == kNguonGoiYSoTien) {
                  _boQuaSoTienLuotNay.add((s.amTietChinh, s.categoryId));
                }
                setState(() {
                  _suggestion = null;
                  _choPhanXu = null;
                });
              },
              onChon: () {
                _ghiPhanHoi(s, kKetQuaGoiYChon, chon: s.categoryId);
                _choPhanXu = null;
                _chonDanhMuc(s.category);
              },
            ),
    );
  }

  /// Điền số của chip — đi qua `themPhimSoTien` như mọi đường điền khác (cùng trần số chữ số).
  void _dienSoTienChon(double v) => _cubit.chonSoTien(v);
}

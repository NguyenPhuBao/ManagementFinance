/// Tổng tài sản theo thời gian — **định nghĩa duy nhất** (#5 của khảo sát lần
/// hai, 2026-09-17).
///
/// ## Vì sao KHÔNG gọi là "tài sản ròng"
///
/// Mục #5 của bảng khảo sát mượn tên *net worth* của Monarch và PocketSmith,
/// nhưng FlowMoney **không có mô hình công nợ**: không dư nợ gốc, không lãi
/// suất, không kỳ hạn — đó chính là lý do A8 #9 bị bỏ hẳn. Tiền **đi vay** nằm
/// trong ví như mọi đồng khác, nên một con số gọi là "tài sản ròng" sẽ **tăng**
/// đúng lúc người dùng mắc nợ thêm. Người dùng chốt lấy tên đo đúng thứ tính
/// được: tổng số dư các ví được tính vào tổng, tại từng mốc thời gian.
///
/// ## Vì sao suy ngược được, dù không lưu lịch sử số dư
///
/// Từ **G37** (2026-09-13) `wallets.balance` thôi là dữ liệu gốc — nó là
/// **cache của một công thức** trên sổ giao dịch. Nên số dư tại mọi thời điểm
/// `T` suy lại được: `soDu(T) = soDuHienTai − Σ biến động sau T`. Mục 3.16 kết
/// luận "không lưu lịch sử số dư → chịu" là ảnh chụp trước G37.
///
/// ## Ba chỗ KHÁC `dongTienCua`, phá cái nào cũng hỏng im lặng
///
/// 1. **Không đi qua `khoanVaoThongKe`.** Hàm ấy loại khoản chuyển, khoản điều
///    chỉnh số dư và khoản mở sổ — nhưng cả ba **đều làm đổi số dư ví thật**.
///    Loại chúng là đường lệch đúng bằng tổng của chúng, không lỗi nào báo.
///    Chốt ở đây là **kiểu dữ liệu**: [BienDongVi] cố ý **không mang**
///    `categoryId` lẫn `ghiChu`, nên không ai lọc theo hai luật ấy được kể cả
///    khi muốn. Đó là chốt chắc hơn một câu chú thích.
/// 2. **Tính theo TỪNG ví rồi mới lọc**, không lọc ví rồi cộng: khoản chuyển
///    giữa hai ví cùng tính vào tổng thì triệt tiêu, nhưng chuyển sang một ví
///    bị loại khỏi tổng thì **có** làm tài sản giảm. Gộp trước là mất nửa kia.
/// 3. **Cửa sổ biến động đóng ở cả hai đầu: `[moc, now]`.** Hai vế, và vế thứ
///    hai là chỗ bản đầu làm sai.
///
///    Vế đầu: mốc kẹp về `min(ky.to, now)`, vì `ky.to` của kỳ đang xem nằm ở
///    **tương lai**.
///
///    Vế sau: hàng ghi **ngày tương lai** bị bỏ khỏi phép trừ — đo được hai
///    hàng như thế trên tài khoản thật ngày 2026-09-16 (`2026-10-10`,
///    `2026-11-10`, đều là khoản trích mục tiêu). Lý do không phải kế toán mà
///    là **tính nhất quán**: `wallets.balance` là tổng **mọi** hàng còn sống
///    *bất kể ngày*, nên một khoản hẹn ngày 10/10 đã nằm trong số dư Trang chủ
///    ngay hôm nay. Trừ nó ra là đường nói một con số còn Trang chủ nói con số
///    khác — người dùng đọc thành "biểu đồ hỏng". Giữ nó lại ở **mọi** điểm thì
///    cả đường kể đúng câu chuyện mà phần còn lại của app đang kể.
///
///    Kẹp mốc **một mình là chưa đủ**: hàng ngày 10/10 vẫn nằm sau mốc `now`
///    nên vẫn bị trừ. Ca test "giao dịch ghi ngày TƯƠNG LAI" canh đúng chỗ đó,
///    và nó đỏ ở bản chỉ có vế đầu.
///
/// ## Giới hạn, và vì sao phải nói ra
///
/// Suy ngược cho mốc **trước giao dịch đầu tiên** luôn ra một con số vô nghĩa
/// (thường là 0). Người dùng có 10 triệu từ tháng 8 mà mới ghi sổ từ 02/09 thì
/// đường nói họ trắng tay hồi tháng 8. Đó là số 0 **"chưa biết"**, không phải 0
/// "không có gì" — [mocThieuDuLieu] cho giao diện một câu để nói ra, và
/// [thayDoiTaiSan] trả `null` thay vì in ra một khoản tăng bịa.
///
/// Ca "khoản neo `Số dư ban đầu` ghi ngày vá chứ không phải ngày tạo ví" mà
/// mục 3.25 lo nằm **gọn trong** giới hạn trên và dùng chung một câu cảnh báo.
/// Đo ngày 2026-09-17 trên dữ liệu thật: cả bốn ví của tài khoản thử có
/// `Balance` khớp **đúng** tổng sổ (lệch `0`) và **không** khoản neo nào — ca
/// ấy không xảy ra ở đây.
///
/// ⚠️ Ví `banking` do server tự ghi số dư từ SePay (`tinhLaiSoDu` cố ý bỏ qua
/// chúng), nên các điểm **quá khứ** của ví ấy là xấp xỉ; điểm cuối vẫn đúng vì
/// nó đọc thẳng `balance`.
library;

import '../../wallet/domain/vi_tinh_vao_tong.dart';
import 'pham_vi_ky.dart';

/// Một biến động số dư, đủ dùng cho phép suy ngược và **không hơn**.
///
/// [soTien] luôn **dương** — chiều nằm ở [loai], đúng quy ước bảng
/// `transactions` của client. [viDich] chỉ có nghĩa với `'transfer'`.
///
/// ⚠️ Cố ý **không** có `categoryId` và `ghiChu`: xem mục 1 ở đầu tệp.
typedef BienDongVi = ({
  DateTime ngay,
  double soTien,
  String loai,
  String viNguon,
  String? viDich,
});

/// Một ví và số dư **hiện tại** của nó, kèm ba cờ mà [viTinhVaoTong] cần.
typedef ViHienTai = ({
  String id,
  double soDu,
  bool includeInTotal,
  String? status,
  bool isDeleted,
});

/// Một điểm trên đường tổng tài sản.
///
/// [moc] là thời điểm thật mà [tong] nói tới — thường là `ky.to`, nhưng kỳ đang
/// diễn ra thì kẹp về `now`. Giao diện cần nó để nói đúng "tính tới lúc nào".
typedef DiemTaiSan = ({Ky ky, DateTime moc, double tong});

/// Tiêu đề khối, đổi theo đơn vị đang xem — cùng khuôn với [tieuDeXuHuong] và
/// [tieuDeDongTienTuDo].
///
/// Đặt ở tầng domain để test được: tầng vẽ không test được (bẫy 4.9
/// `ANALYTICS_FEATURE.md`). Kỳ tuỳ chọn rơi về "tháng" vì chuỗi của nó cũng lùi
/// theo tháng.
String tieuDeTongTaiSan(DonViKy donVi) =>
    'Tổng tài sản ${cumSoKy(donVi)} gần đây';

/// `"6 tháng"`, `"6 quý"`, … — **một định nghĩa** cho cả tiêu đề khối lẫn câu
/// "… trong 6 tháng" dưới con số thay đổi.
///
/// Tách ra vì hai chỗ ấy phải nói **cùng một quãng thời gian**: viết tay hai
/// lần là lần đổi `kSoKyXuHuong` đầu tiên sẽ để lại một chỗ nói "6" còn chỗ kia
/// nói con số mới, ngay cạnh nhau.
String cumSoKy(DonViKy donVi) => switch (donVi) {
      DonViKy.tuan => '$kSoKyXuHuong tuần',
      DonViKy.quy => '$kSoKyXuHuong quý',
      DonViKy.nam => '$kSoKyXuHuong năm',
      DonViKy.thang || DonViKy.tuyChon => '$kSoKyXuHuong tháng',
    };

/// [soKy] điểm, **cũ nhất trước**, điểm cuối là kỳ [ky].
///
/// [bienDong] phải là **toàn bộ** sổ giao dịch còn sống của tài khoản, không
/// phải phần đã cắt theo kỳ: phép suy đi ngược từ [now] về từng mốc, nên nó cần
/// biết cả phần phát sinh **sau** kỳ đang xem. Đưa vào danh sách đã cắt là cả
/// sáu điểm bằng nhau một cách im lặng — cùng cái bẫy `dongTienCua` đã ghi.
List<DiemTaiSan> tongTaiSanCua(
  List<BienDongVi> bienDong,
  List<ViHienTai> vi, {
  required Ky ky,
  required DateTime now,
  int soKy = kSoKyXuHuong,
}) {
  // Lọc ví **một lần**, qua đúng hàm mà Trang chủ, màn Quản lý ví và trang Báo
  // cáo dùng. `fold` trần trên mọi ví là bản chép tay đã sai bốn lần, lần gần
  // nhất là G42.
  final trongTong = {
    for (final v in vi)
      if (viTinhVaoTong(
        includeInTotal: v.includeInTotal,
        status: v.status,
        isDeleted: v.isDeleted,
      ))
        v.id: v,
  };

  final soDuHienTai =
      trongTong.values.fold<double>(0, (s, v) => s + v.soDu);

  return [
    for (var i = soKy - 1; i >= 0; i--)
      () {
        final k = lui(ky, i);
        // Kẹp về `now`: xem mục 3 ở đầu tệp.
        final moc = k.to.isAfter(now) ? now : k.to;

        var sau = 0.0;
        for (final b in bienDong) {
          // Biên MỞ, cùng luật với `_trongKhoang` và `dongTienCua`: hàng đúng
          // tại mốc thuộc về phía **sau** mốc.
          if (b.ngay.isBefore(moc)) continue;
          // Đầu kia của cửa sổ: hàng ghi ngày tương lai đã nằm sẵn trong
          // `balance` nên giữ nguyên ở mọi điểm — xem mục 3 ở đầu tệp.
          if (b.ngay.isAfter(now)) continue;
          switch (b.loai) {
            case 'thu':
              if (trongTong.containsKey(b.viNguon)) sau += b.soTien;
            case 'chi':
              if (trongTong.containsKey(b.viNguon)) sau -= b.soTien;
            case 'transfer':
              // Thiếu ví đích thì không biết tiền đi đâu — cùng luật với
              // `tongTheoVi` và `_applyBalances`, cả hai đều bỏ qua.
              final dich = b.viDich;
              if (dich == null) continue;
              if (trongTong.containsKey(b.viNguon)) sau -= b.soTien;
              if (trongTong.containsKey(dich)) sau += b.soTien;
          }
        }

        return (ky: k, moc: moc, tong: soDuHienTai - sau);
      }(),
  ];
}

/// Ngày mà giao diện phải nói ra, hoặc `null` khi cả chuỗi đều đứng vững.
///
/// Trả ngày của [giaoDichDauTien] khi điểm **cũ nhất** của [chuoi] rơi vào
/// quãng trước nó — quãng mà mọi con số chỉ là "chưa biết". Xem phần *Giới hạn*
/// ở đầu tệp.
DateTime? mocThieuDuLieu(
  List<DiemTaiSan> chuoi, {
  required DateTime? giaoDichDauTien,
}) {
  if (giaoDichDauTien == null || chuoi.isEmpty) return null;
  return chuoi.first.moc.isBefore(giaoDichDauTien) ? giaoDichDauTien : null;
}

/// Thay đổi tài sản trên cả chuỗi, hoặc `null` khi con số ấy sẽ nói dối.
///
/// `null` khi [mocThieuDuLieu] có giá trị: điểm đầu khi ấy là số 0 "chưa biết",
/// nên hiệu với nó in ra **nguyên cả tài sản** như thể người dùng vừa kiếm được
/// ngần ấy trong sáu kỳ. Giao diện **ẩn hẳn dòng** chứ không in `0 đ` — cùng
/// kỷ luật với [tyLeTietKiem].
double? thayDoiTaiSan(
  List<DiemTaiSan> chuoi, {
  required DateTime? giaoDichDauTien,
}) {
  if (chuoi.isEmpty) return null;
  if (giaoDichDauTien == null) return null;
  if (mocThieuDuLieu(chuoi, giaoDichDauTien: giaoDichDauTien) != null) {
    return null;
  }
  return chuoi.last.tong - chuoi.first.tong;
}

/// Biểu đồ **thác nước** — cơ cấu dòng tiền của một kỳ (A8 #10, 2026-09-15).
///
/// Câu chuyện nó kể: số dư đầu kỳ → cộng thu → trừ dần từng nhóm chi → số dư
/// cuối kỳ. Mỗi nhóm chi là một khối **nổi**: đáy của khối này là đỉnh của khối
/// trước, nên cả biểu đồ đọc được như một bậc thang đi xuống.
///
/// ⚠️ **Phép cân là thứ đắt nhất ở đây.** `đầu kỳ + thu − Σ nhóm chi` phải ra
/// đúng `cuối kỳ`; lệch thì bậc thang hở một khe ngay giữa biểu đồ — không
/// exception, không log, chỉ là một hình vẽ sai mà người đọc tưởng là thật. Có
/// ca test canh đúng điều kiện ấy (`thac_nuoc_test.dart`).
///
/// Vì thế hàm này **không tự tính** `cuoiKy`: nó nhận con số mà khối "Dòng tiền
/// trong kỳ" đang hiện. Hai khối cùng trang nói hai con số khác nhau cho cùng
/// một kỳ là điều dự án cấm, và tự cộng lấy là cách chắc chắn nhất để rơi vào
/// đó khi một bên đổi luật lọc.
library;

/// Vai của một bậc: cột mốc hai đầu, cột thu, hay một nhóm chi.
enum LoaiBuoc { moc, thu, chi }

/// Một bậc của thác nước.
///
/// [tu] và [den] là giá trị tích luỹ **trước** và **sau** bước, nên chúng mang
/// cả chiều: bậc chi có `den < tu`. Tầng vẽ tự lấy `min`/`max` cho `fromY`/
/// `toY` của `fl_chart` — giữ chiều ở đây để tầng thuần còn kiểm được rằng
/// khối chi đi xuống.
class BuocThacNuoc {
  final String nhan;

  /// Giá trị tích luỹ **trước** bước này.
  final double tu;

  /// Giá trị tích luỹ **sau** bước này.
  final double den;

  final LoaiBuoc loai;

  const BuocThacNuoc({
    required this.nhan,
    required this.tu,
    required this.den,
    required this.loai,
  });

  /// Độ cao khối, luôn không âm.
  double get giaTri => (den - tu).abs();
}

/// Dựng các bậc của thác nước cho một kỳ.
///
/// [nhomChi] đã gom sẵn và **đúng thứ tự vẽ** — khối gọi hàm này mượn
/// `topVaKhac()` để có "năm danh mục lớn nhất + Khác", nên thác nước và vòng
/// tròn cơ cấu không thể nói hai con số khác nhau.
///
/// Hai cột mốc mọc **từ đáy** (`tu = 0`) chứ không nổi: chúng là số dư tuyệt
/// đối, không phải một bước thay đổi.
///
/// Trả **rỗng** khi kỳ không có gì để kể. Trả ba cột bằng 0 thì biểu đồ hiện ra
/// một hình phẳng và người dùng tưởng app hỏng — khối gọi phải tự ẩn đi.
List<BuocThacNuoc> thacNuocCua({
  required double dauKy,
  required double cuoiKy,
  required double thu,
  required List<({String ten, double soTien})> nhomChi,
}) {
  final rong = dauKy == 0 && cuoiKy == 0 && thu == 0 && nhomChi.isEmpty;
  if (rong) return const [];

  final ra = <BuocThacNuoc>[
    BuocThacNuoc(nhan: 'Đầu kỳ', tu: 0, den: dauKy, loai: LoaiBuoc.moc),
    BuocThacNuoc(
        nhan: '+Thu', tu: dauKy, den: dauKy + thu, loai: LoaiBuoc.thu),
  ];

  var moc = dauKy + thu;
  for (final n in nhomChi) {
    final den = moc - n.soTien;
    ra.add(BuocThacNuoc(
        nhan: n.ten, tu: moc, den: den, loai: LoaiBuoc.chi));
    moc = den;
  }

  ra.add(BuocThacNuoc(nhan: 'Cuối kỳ', tu: 0, den: cuoiKy, loai: LoaiBuoc.moc));
  return ra;
}

/// Ranh giới giữa phần **trong mức trung bình** và phần **vượt** của một bậc
/// chi — chỗ đặt vạch nét đứt trên cột.
///
/// ⚠️ Vì sao không phải một đường ngang vắt qua cả biểu đồ: các khối chi của
/// thác nước **nổi** ở vùng cao (14,6 triệu xuống 13,6 triệu), còn mức trung
/// bình là một con số nhỏ (174 nghìn) nằm tít dưới đáy trục — đường ngang ở đó
/// không cắt cột nào, nên không nói được nhóm nào vượt. Mắt so **độ cao** khối,
/// mà đường ngang thì so **vị trí**. Vạch đặt trên từng cột mới so được.
///
/// Phần nhạt đo **từ đỉnh khối xuống**, nên ranh nằm ở `tu - tb`.
///
/// Trả `null` khi bậc không phải chi, khi khối không vượt mức trung bình, hay
/// khi chưa có mức trung bình nào — cả ba đều là "không có vạch", và vẽ một
/// vạch ngoài khối là bịa ra chỗ không có.
double? ranhVuotTrungBinh(BuocThacNuoc buoc, double trungBinh) {
  if (buoc.loai != LoaiBuoc.chi) return null;
  if (trungBinh <= 0) return null;
  // ⚠️ Ngưỡng **nửa đồng**, không so `<=` trần: `giaTri` là hiệu của hai số
  // thực nên một nhóm bằng đúng mức trung bình vẫn có thể ra lớn hơn chừng
  // 1e-10, và khi ấy cột mọc thêm một vạch đậm cao **không tới một phần triệu
  // pixel** — người dùng thấy một vạch không giải thích được. Cùng ngưỡng mà
  // `dieu_chinh_so_du_service.dart` dùng cho đuôi lẻ của `double`.
  if (buoc.giaTri - trungBinh <= 0.5) return null;
  return buoc.tu - trungBinh;
}

/// Mức chi trung bình của một nhóm — mốc của vạch trên từng cột chi.
///
/// Nó trả lời "nhóm nào ngốn hơn mức bình thường": cột nào vượt đường là chỗ
/// đáng xem lại. Chia cho **số nhóm**, không phải số ngày hay số giao dịch —
/// đường này so các cột với nhau chứ không so với thời gian.
double trungBinhNhomChi(List<({String ten, double soTien})> nhomChi) {
  if (nhomChi.isEmpty) return 0;
  final tong = nhomChi.fold(0.0, (s, x) => s + x.soTien);
  return tong / nhomChi.length;
}

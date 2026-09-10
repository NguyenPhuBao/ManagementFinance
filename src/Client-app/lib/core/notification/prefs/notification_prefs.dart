import '../notification_rules.dart';

/// Bốn nhóm thông báo mà người dùng bật/tắt độc lập.
///
/// Nhóm chứ không phải từng `NotificationKind`: tám công tắc là quá nhiều để
/// người dùng hiểu, và hai loại trong cùng nhóm luôn được bật/tắt cùng nhau
/// trong thực tế (ai tắt "sắp đến hạn" thì cũng không muốn "quá hạn").
enum NotificationGroup { bill, budget, goal, system, summary }

/// Loại thông báo thuộc nhóm nào.
///
/// Dùng `switch` không có `default` **có chủ ý**: thêm một giá trị vào
/// `NotificationKind` mà quên xếp nhóm sẽ thành lỗi biên dịch chứ không lặng lẽ
/// rơi vào một nhóm nào đó.
NotificationGroup nhomCua(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.billDueSoon:
    case NotificationKind.billOverdue:
    case NotificationKind.billAutoPaid:
    case NotificationKind.billAutoPayFailed:
      return NotificationGroup.bill;
    case NotificationKind.budgetNearLimit:
    case NotificationKind.budgetOverspent:
      return NotificationGroup.budget;
    case NotificationKind.goalCompleted:
    case NotificationKind.goalCycleReady:
    case NotificationKind.goalBehind:
    case NotificationKind.goalMilestone:
    case NotificationKind.goalAutoDeposited:
    case NotificationKind.goalAutoDepositFailed:
      return NotificationGroup.goal;
    case NotificationKind.syncFailed:
    case NotificationKind.walletNegative:
    case NotificationKind.walletLowBalance:
      return NotificationGroup.system;
    // Nhóm RIÊNG, cố ý không gộp vào `system`. Nhóm ấy đang là "Đồng bộ hỏng
    // và số dư ví âm"; ai tắt tổng kết tuần vì thấy phiền thì **không** có ý
    // tắt luôn cảnh báo ví âm. Đúng loại nhầm lẫn mà commit `dfb8721` đã phải
    // đi sửa một lần.
    //
    // Kho tuỳ chọn lưu nhóm bị **TẮT** chứ không phải nhóm được bật, nên nhóm
    // mới tự động BẬT với mọi bản ghi cũ — chính là lý do định dạng ấy được
    // chọn từ đầu.
    case NotificationKind.weeklySummary:
      return NotificationGroup.summary;
  }
}

/// Loại thông báo **không chịu công tắc nhóm**.
///
/// Bốn loại này là những loại DUY NHẤT báo việc **tiền thật rời ví** trong lúc
/// người dùng vắng mặt — hai chỗ trong app tự chuyển tiền hộ họ.
///
/// "Đừng nhắc tôi hoá đơn sắp tới hạn" và "đừng cho tôi biết app vừa rút tiền
/// của tôi" là hai câu hoàn toàn khác nhau, nhưng trước đây người dùng chỉ gạt
/// được **một** công tắc cho cả hai: tắt nhóm Hoá đơn vì thấy nhắc hạn phiền
/// là mất luôn cảnh báo app vừa trừ tiền, và vì bộ lọc chạy trước khi ghi nên
/// trung tâm thông báo cũng không còn dấu vết nào.
///
/// Muốn im hẳn thì vẫn còn **công tắc tổng** cho thông báo hệ điều hành —
/// công tắc ấy chỉ chặn bước bắn ra ngoài, hàng vẫn được ghi lại trong app.
///
/// ⚠️ Đừng nới danh sách này ra cả nhóm: công tắc mất tác dụng thì người dùng
/// sẽ tắt luôn công tắc tổng, và khi ấy họ mất mọi thứ.
bool luonBao(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.billAutoPaid:
    case NotificationKind.billAutoPayFailed:
    case NotificationKind.goalAutoDeposited:
    case NotificationKind.goalAutoDepositFailed:
      return true;
    case NotificationKind.billDueSoon:
    case NotificationKind.billOverdue:
    case NotificationKind.budgetNearLimit:
    case NotificationKind.budgetOverspent:
    case NotificationKind.goalCompleted:
    case NotificationKind.goalCycleReady:
    case NotificationKind.goalBehind:
    // Cột mốc là lời ghi nhận, không phải báo tiền rời ví — nên nó **chịu**
    // công tắc nhóm Mục tiêu như ba loại trên. Nới danh sách `luonBao` ra cho
    // nó là làm đúng cái việc mà cảnh báo ở đầu hàm này cấm.
    case NotificationKind.goalMilestone:
    case NotificationKind.syncFailed:
    case NotificationKind.walletNegative:
    case NotificationKind.walletLowBalance:
    // Tổng kết tuần **chịu** công tắc nhóm: nó không báo tiền rời ví, nó chỉ
    // mời người dùng quay lại xem. Đúng loại thông báo mà người ta phải tắt
    // được, nếu không họ sẽ tắt công tắc tổng và mất mọi thứ.
    case NotificationKind.weeklySummary:
      return false;
  }
}

/// Tuỳ chọn thông báo của **một tài khoản**.
///
/// ## Vì sao lưu nhóm bị TẮT chứ không phải nhóm được bật
///
/// Để mặc định là "bật hết" mà không cần biết trước danh sách nhóm. Thêm nhóm
/// thứ năm ở bản sau thì mọi bản ghi cũ tự động bật nhóm ấy — đúng ý người
/// dùng hơn là im lặng tắt một tính năng họ chưa từng thấy. Nếu lưu danh sách
/// bật, mọi bản ghi cũ sẽ thiếu nhóm mới và nó chết ngay từ đầu.
class NotificationPrefs {
  const NotificationPrefs({
    this.osBat = true,
    this.nhomTat = const {},
    this.gioNhac = _gioMacDinh,
    this.phutNhac = _phutMacDinh,
    this.soNgayNhacHoaDon = _soNgayMacDinh,
    this.imLangBat = false,
    this.imLangTuPhut = _imLangTuMacDinh,
    this.imLangDenPhut = _imLangDenMacDinh,
    this.nguongSoDuThap = _nguongSoDuMacDinh,
    this.nhacGhiChepBat = false,
    this.gioNhacGhiChep = _gioGhiChepMacDinh,
    this.phutNhacGhiChep = _phutGhiChepMacDinh,
    this.tongKetTuanBat = false,
    this.thuTongKet = _thuTongKetMacDinh,
    this.gioTongKet = _gioTongKetMacDinh,
    this.phutTongKet = _phutTongKetMacDinh,
  });

  /// Công tắc **tổng** cho thông báo cấp hệ điều hành.
  ///
  /// Tắt nó thì thông báo **vẫn được ghi** vào trung tâm trong app, chỉ không
  /// bắn ra ngoài. Đây là chỗ dành cho người muốn xem lại lịch sử khi mở app
  /// nhưng không muốn bị làm phiền.
  final bool osBat;

  /// Các nhóm bị tắt. Tắt nhóm là **không sinh thông báo** của nhóm ấy, cả
  /// trong app lẫn ra hệ điều hành.
  final Set<NotificationGroup> nhomTat;

  /// Giờ trong ngày để bắn nhắc đặt trước (0–23). Xem bẫy 7.3: thiếu nó thì
  /// `zonedSchedule` nổ lúc 00:00.
  final int gioNhac;
  final int phutNhac;

  /// Số ngày nhắc trước hạn, dùng cho hoá đơn không tự đặt.
  final int soNgayNhacHoaDon;

  /// Có bật khoảng giờ không bắn thông báo ra hệ điều hành không.
  ///
  /// **Mặc định TẮT.** Bật sẵn là lặng lẽ đổi hành vi của mọi bản đã cài —
  /// cảnh báo vượt ngân sách lúc 23h thôi hiện ra ngoài mà không ai báo. Cùng
  /// lý lẽ với việc lưu *nhóm bị tắt* thay vì *nhóm được bật*.
  final bool imLangBat;

  /// Mốc bắt đầu và kết thúc, tính bằng **số phút từ nửa đêm**.
  ///
  /// Một số nguyên thay vì cặp giờ/phút: khoảng giờ im lặng gần như luôn vắt
  /// qua nửa đêm, và phép so trên một trục duy nhất đọc dễ hơn hẳn so với việc
  /// so từng cặp.
  final int imLangTuPhut;
  final int imLangDenPhut;

  /// Cảnh báo khi số dư một ví xuống tới mức này, đơn vị **đồng**.
  ///
  /// `0` = **tắt**, và đó là mặc định. Một con số thay vì một cặp
  /// công tắc-cộng-số vì cặp ấy biểu diễn được một trạng thái vô nghĩa (bật
  /// nhưng ngưỡng bằng 0), còn một con số thì không.
  ///
  /// Mặc định tắt vì mọi bản ghi có sẵn trên máy người dùng đều thiếu trường
  /// này — bật sẵn là lặng lẽ đổi hành vi của mọi bản đã cài, cùng lý lẽ với
  /// giờ im lặng.
  final int nguongSoDuThap;

  /// Có nhắc người dùng ghi chép vào cuối ngày không.
  ///
  /// **Mặc định TẮT**, cùng lý lẽ với giờ im lặng và [nguongSoDuThap]: mọi bản
  /// ghi đang nằm trên máy người dùng đều thiếu trường này, nên bật sẵn là
  /// lặng lẽ cho cả tập người dùng hiện tại một thông báo mỗi ngày mà không ai
  /// báo trước.
  ///
  /// ⚠️ Lời nhắc này **không đi qua bộ luật** và **không sinh hàng** nào trong
  /// `AppNotifications`. Mười bốn loại kia đều là *bản ghi* một việc đã xảy ra
  /// và người dùng đọc lại chúng trong trung tâm thông báo; lời nhắc này chỉ
  /// có nghĩa khi họ **đang không mở app**, nên lúc mở ra xem thì nó đã hết lý
  /// do tồn tại. Nó sống hoàn toàn trong `ReminderScheduler`.
  final bool nhacGhiChepBat;

  /// Giờ và phút bắn lời nhắc ghi chép.
  ///
  /// **Riêng, không dùng chung [gioNhac].** Giờ nhắc chung mặc định 8h sáng vì
  /// nó là của hoá đơn — nhắc trước khi tới hạn thì phải sớm. Một câu "hôm nay
  /// ghi chép chưa" lúc 8h sáng là hỏi trước khi có gì để ghi.
  ///
  /// Giờ im lặng **không chặn** lời nhắc này: đây là mốc người dùng tự chọn và
  /// đang nhìn thấy trên màn hình, app không được đoán lại hộ họ — cùng lý lẽ
  /// đã ghi ở [dangImLang] cho mọi lịch đặt trước.
  final int gioNhacGhiChep;
  final int phutNhacGhiChep;

  /// Có bắn Tổng kết tuần không.
  ///
  /// **Mặc định TẮT**, cùng lý lẽ đã ghi ở [nhacGhiChepBat] và [imLangBat]:
  /// mọi bản ghi đang nằm trên máy người dùng đều thiếu trường này, nên bật
  /// sẵn là lặng lẽ cho cả tập người dùng hiện tại một thông báo mỗi tuần mà
  /// không ai báo trước. Nặng hơn hai trường kia một bậc, vì loại này nổ **khi
  /// app đã đóng** và **không đi qua giờ im lặng**.
  ///
  /// Công tắc nhóm `summary` vẫn tồn tại và vẫn chặn được — hai thứ khác nhau:
  /// công tắc này là "tôi có muốn loại này không", công tắc nhóm là "tạm im
  /// cả nhóm". Cùng hình dạng với cặp `nhacGhiChepBat` + công tắc tổng.
  final bool tongKetTuanBat;

  /// Thứ trong tuần để bắn Tổng kết tuần — **1 = thứ Hai … 7 = Chủ nhật**,
  /// đúng quy ước của `DateTime.weekday`.
  ///
  /// Người dùng chọn được thay vì app đặt cứng, và đó là một quyết định về
  /// **sự tôn trọng**, không phải về tính linh hoạt: lịch đặt trước không đi
  /// qua giờ im lặng (xem [dangImLang]), nên một mốc do app tự đặt sẽ kêu
  /// xuyên qua khung giờ người dùng đã nói là muốn yên. Thứ khiến nhắc hoá đơn
  /// không phiền không phải giờ của nó, mà là việc giờ ấy do họ đặt và đang
  /// nhìn thấy trên màn hình.
  final int thuTongKet;

  /// Giờ và phút bắn Tổng kết tuần. **Riêng**, không dùng chung [gioNhac] —
  /// cùng lý lẽ với [gioNhacGhiChep].
  final int gioTongKet;
  final int phutTongKet;

  static const int _gioMacDinh = 8;
  static const int _phutMacDinh = 0;

  /// 20:00 — cuối ngày, sau bữa tối, còn đủ tỉnh táo để mở app ghi lại.
  static const int _gioGhiChepMacDinh = 20;
  static const int _phutGhiChepMacDinh = 0;

  static const int _imLangTuMacDinh = 22 * 60;
  static const int _imLangDenMacDinh = 7 * 60;
  static const int _phutTrongNgay = 24 * 60;

  /// Khớp `@default("3")` của cột `Time_notification` phía backend, để một hoá
  /// đơn tạo ở client và một hoá đơn tạo ở nơi khác hành xử như nhau.
  static const int _soNgayMacDinh = 3;

  /// Trần của `soNgayNhacHoaDon`. Rộng hơn cửa sổ quét 30 ngày một chút để
  /// không chặn oan, nhưng vẫn loại được những con số vô nghĩa.
  static const int _soNgayToiDa = 60;

  /// Thứ Hai 08:00 — đầu tuần làm việc, và là lúc "tuần qua" vừa mới khép lại
  /// nên câu chữ còn đúng nghĩa. Có mặc định hợp lý để bản cài mới không bắt
  /// ai phải vào cấu hình trước khi tính năng có ích.
  static const int _thuTongKetMacDinh = DateTime.monday;
  static const int _gioTongKetMacDinh = 8;
  static const int _phutTongKetMacDinh = 0;

  static const int _nguongSoDuMacDinh = 0;

  /// Trần của [nguongSoDuThap] — một tỉ đồng. Không phải hạn chế sản phẩm mà
  /// là lưới chắn dữ liệu hỏng: một con số vô nghĩa lớn biến cảnh báo thành
  /// luôn-bật cho mọi ví, đúng kiểu hỏng mà `BudgetEntity.warningRatio` đã
  /// chặn ở phía ngân sách.
  static const int _nguongSoDuToiDa = 1000000000;

  static const NotificationPrefs macDinh = NotificationPrefs();

  bool batNhom(NotificationGroup nhom) => !nhomTat.contains(nhom);

  /// Loại thông báo này có được sinh không.
  bool chapNhan(NotificationKind kind) =>
      luonBao(kind) || batNhom(nhomCua(kind));

  /// [luc] có rơi vào khoảng giờ im lặng không.
  ///
  /// Chỉ chặn **bước bắn ra hệ điều hành** — hàng vẫn được ghi vào trung tâm
  /// trong app, đúng ngữ nghĩa của công tắc tổng. Đây là "đừng đánh thức tôi",
  /// không phải "đừng ghi lại gì".
  ///
  /// Lịch **đặt trước** không đi qua đây: giờ nhắc là do người dùng tự chọn và
  /// đang nhìn thấy trên màn hình, app không nên đoán lại hộ họ.
  bool dangImLang(DateTime luc) {
    if (!imLangBat) return false;

    // Hai mốc trùng nhau là khoảng RỖNG, không phải cả ngày. Người dùng lỡ tay
    // đặt bằng nhau không được mất sạch thông báo hệ điều hành — đó là kiểu
    // hỏng họ sẽ không bao giờ lần ra nguyên nhân.
    if (imLangTuPhut == imLangDenPhut) return false;

    final phut = luc.hour * 60 + luc.minute;

    // Tính từ mốc đầu, KHÔNG tính mốc cuối: mốc cuối là lúc im lặng kết thúc.
    if (imLangTuPhut < imLangDenPhut) {
      return phut >= imLangTuPhut && phut < imLangDenPhut;
    }
    // Vắt qua nửa đêm — ca chính, và là chỗ phép so trần trả sai nửa khoảng.
    return phut >= imLangTuPhut || phut < imLangDenPhut;
  }

  NotificationPrefs copyWith({
    bool? osBat,
    Set<NotificationGroup>? nhomTat,
    int? gioNhac,
    int? phutNhac,
    int? soNgayNhacHoaDon,
    bool? imLangBat,
    int? imLangTuPhut,
    int? imLangDenPhut,
    int? nguongSoDuThap,
    bool? nhacGhiChepBat,
    int? gioNhacGhiChep,
    int? phutNhacGhiChep,
    bool? tongKetTuanBat,
    int? thuTongKet,
    int? gioTongKet,
    int? phutTongKet,
  }) {
    return NotificationPrefs(
      osBat: osBat ?? this.osBat,
      nhomTat: nhomTat ?? this.nhomTat,
      gioNhac: gioNhac ?? this.gioNhac,
      phutNhac: phutNhac ?? this.phutNhac,
      soNgayNhacHoaDon: soNgayNhacHoaDon ?? this.soNgayNhacHoaDon,
      imLangBat: imLangBat ?? this.imLangBat,
      imLangTuPhut: imLangTuPhut ?? this.imLangTuPhut,
      imLangDenPhut: imLangDenPhut ?? this.imLangDenPhut,
      nguongSoDuThap: nguongSoDuThap ?? this.nguongSoDuThap,
      nhacGhiChepBat: nhacGhiChepBat ?? this.nhacGhiChepBat,
      gioNhacGhiChep: gioNhacGhiChep ?? this.gioNhacGhiChep,
      phutNhacGhiChep: phutNhacGhiChep ?? this.phutNhacGhiChep,
      tongKetTuanBat: tongKetTuanBat ?? this.tongKetTuanBat,
      thuTongKet: thuTongKet ?? this.thuTongKet,
      gioTongKet: gioTongKet ?? this.gioTongKet,
      phutTongKet: phutTongKet ?? this.phutTongKet,
    );
  }

  Map<String, Object?> toJson() => {
        'osBat': osBat,
        'nhomTat': [for (final n in nhomTat) n.name],
        'gioNhac': gioNhac,
        'phutNhac': phutNhac,
        'soNgayNhacHoaDon': soNgayNhacHoaDon,
        'imLangBat': imLangBat,
        'imLangTuPhut': imLangTuPhut,
        'imLangDenPhut': imLangDenPhut,
        'nguongSoDuThap': nguongSoDuThap,
        'nhacGhiChepBat': nhacGhiChepBat,
        'gioNhacGhiChep': gioNhacGhiChep,
        'phutNhacGhiChep': phutNhacGhiChep,
        'tongKetTuanBat': tongKetTuanBat,
        'thuTongKet': thuTongKet,
        'gioTongKet': gioTongKet,
        'phutTongKet': phutTongKet,
      };

  /// Đọc từ JSON, **không bao giờ ném**.
  ///
  /// Mọi trường thiếu, sai kiểu hoặc ngoài dải đều lặng lẽ quy về mặc định.
  /// Nơi gọi là vòng quét thông báo; một ngoại lệ ở đó làm chết cả trung tâm
  /// thông báo trong app — mất nhiều hơn hẳn so với việc dùng một giá trị mặc
  /// định cho một tuỳ chọn.
  factory NotificationPrefs.fromJson(Map<String, Object?> json) {
    return NotificationPrefs(
      osBat: json['osBat'] is bool ? json['osBat']! as bool : true,
      nhomTat: _docNhom(json['nhomTat']),
      gioNhac: _docSo(json['gioNhac'], 0, 23, _gioMacDinh),
      phutNhac: _docSo(json['phutNhac'], 0, 59, _phutMacDinh),
      soNgayNhacHoaDon:
          _docSo(json['soNgayNhacHoaDon'], 0, _soNgayToiDa, _soNgayMacDinh),
      imLangBat: json['imLangBat'] is bool ? json['imLangBat']! as bool : false,
      imLangTuPhut: _docSo(
          json['imLangTuPhut'], 0, _phutTrongNgay - 1, _imLangTuMacDinh),
      imLangDenPhut: _docSo(
          json['imLangDenPhut'], 0, _phutTrongNgay - 1, _imLangDenMacDinh),
      nguongSoDuThap: _docSo(json['nguongSoDuThap'], 0, _nguongSoDuToiDa,
          _nguongSoDuMacDinh),
      nhacGhiChepBat: json['nhacGhiChepBat'] is bool
          ? json['nhacGhiChepBat']! as bool
          : false,
      gioNhacGhiChep:
          _docSo(json['gioNhacGhiChep'], 0, 23, _gioGhiChepMacDinh),
      phutNhacGhiChep:
          _docSo(json['phutNhacGhiChep'], 0, 59, _phutGhiChepMacDinh),
      // Dải 1–7 theo `DateTime.weekday`. Một giá trị 0 hay 8 lọt vào phép tính
      // mốc kế tiếp sẽ đẩy lịch lệch hẳn một tuần, im lặng.
      tongKetTuanBat: json['tongKetTuanBat'] is bool
          ? json['tongKetTuanBat']! as bool
          : false,
      thuTongKet: _docSo(json['thuTongKet'], 1, 7, _thuTongKetMacDinh),
      gioTongKet: _docSo(json['gioTongKet'], 0, 23, _gioTongKetMacDinh),
      phutTongKet: _docSo(json['phutTongKet'], 0, 59, _phutTongKetMacDinh),
    );
  }

  static Set<NotificationGroup> _docNhom(Object? raw) {
    if (raw is! List) return const {};
    return {
      for (final e in raw)
        // `firstWhere` với orElse trả null không dùng được cho enum không
        // nullable, nên duyệt tay. Tên lạ — do bản app cũ hoặc do sửa tay —
        // chỉ được làm hỏng chính nó, không kéo cả bản ghi về mặc định.
        for (final g in NotificationGroup.values)
          if (g.name == e) g,
    };
  }

  static int _docSo(Object? raw, int min, int max, int macDinh) {
    if (raw is! int) return macDinh;
    if (raw < min || raw > max) return macDinh;
    return raw;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.osBat == osBat &&
      other.gioNhac == gioNhac &&
      other.phutNhac == phutNhac &&
      other.soNgayNhacHoaDon == soNgayNhacHoaDon &&
      other.imLangBat == imLangBat &&
      other.imLangTuPhut == imLangTuPhut &&
      other.imLangDenPhut == imLangDenPhut &&
      other.nguongSoDuThap == nguongSoDuThap &&
      other.nhacGhiChepBat == nhacGhiChepBat &&
      other.gioNhacGhiChep == gioNhacGhiChep &&
      other.phutNhacGhiChep == phutNhacGhiChep &&
      other.nhomTat.length == nhomTat.length &&
      other.nhomTat.containsAll(nhomTat);

  @override
  int get hashCode => Object.hash(
        osBat,
        gioNhac,
        phutNhac,
        soNgayNhacHoaDon,
        imLangBat,
        imLangTuPhut,
        imLangDenPhut,
        nguongSoDuThap,
        nhacGhiChepBat,
        gioNhacGhiChep,
        phutNhacGhiChep,
        Object.hashAllUnordered(nhomTat),
      );

  @override
  String toString() => 'NotificationPrefs(osBat: $osBat, nhomTat: '
      '${nhomTat.map((n) => n.name).toList()}, gioNhac: $gioNhac:'
      '${phutNhac.toString().padLeft(2, '0')}, '
      'soNgayNhacHoaDon: $soNgayNhacHoaDon)';
}

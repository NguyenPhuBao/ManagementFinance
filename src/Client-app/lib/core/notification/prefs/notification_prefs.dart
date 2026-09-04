import '../notification_rules.dart';

/// Bốn nhóm thông báo mà người dùng bật/tắt độc lập.
///
/// Nhóm chứ không phải từng `NotificationKind`: tám công tắc là quá nhiều để
/// người dùng hiểu, và hai loại trong cùng nhóm luôn được bật/tắt cùng nhau
/// trong thực tế (ai tắt "sắp đến hạn" thì cũng không muốn "quá hạn").
enum NotificationGroup { bill, budget, goal, system }

/// Loại thông báo thuộc nhóm nào.
///
/// Dùng `switch` không có `default` **có chủ ý**: thêm một giá trị vào
/// `NotificationKind` mà quên xếp nhóm sẽ thành lỗi biên dịch chứ không lặng lẽ
/// rơi vào một nhóm nào đó.
NotificationGroup nhomCua(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.billDueSoon:
    case NotificationKind.billOverdue:
      return NotificationGroup.bill;
    case NotificationKind.budgetNearLimit:
    case NotificationKind.budgetOverspent:
      return NotificationGroup.budget;
    case NotificationKind.goalCompleted:
    case NotificationKind.goalBehind:
      return NotificationGroup.goal;
    case NotificationKind.syncFailed:
    case NotificationKind.walletNegative:
      return NotificationGroup.system;
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

  static const int _gioMacDinh = 8;
  static const int _phutMacDinh = 0;

  /// Khớp `@default("3")` của cột `Time_notification` phía backend, để một hoá
  /// đơn tạo ở client và một hoá đơn tạo ở nơi khác hành xử như nhau.
  static const int _soNgayMacDinh = 3;

  /// Trần của `soNgayNhacHoaDon`. Rộng hơn cửa sổ quét 30 ngày một chút để
  /// không chặn oan, nhưng vẫn loại được những con số vô nghĩa.
  static const int _soNgayToiDa = 60;

  static const NotificationPrefs macDinh = NotificationPrefs();

  bool batNhom(NotificationGroup nhom) => !nhomTat.contains(nhom);

  /// Loại thông báo này có được sinh không.
  bool chapNhan(NotificationKind kind) => batNhom(nhomCua(kind));

  NotificationPrefs copyWith({
    bool? osBat,
    Set<NotificationGroup>? nhomTat,
    int? gioNhac,
    int? phutNhac,
    int? soNgayNhacHoaDon,
  }) {
    return NotificationPrefs(
      osBat: osBat ?? this.osBat,
      nhomTat: nhomTat ?? this.nhomTat,
      gioNhac: gioNhac ?? this.gioNhac,
      phutNhac: phutNhac ?? this.phutNhac,
      soNgayNhacHoaDon: soNgayNhacHoaDon ?? this.soNgayNhacHoaDon,
    );
  }

  Map<String, Object?> toJson() => {
        'osBat': osBat,
        'nhomTat': [for (final n in nhomTat) n.name],
        'gioNhac': gioNhac,
        'phutNhac': phutNhac,
        'soNgayNhacHoaDon': soNgayNhacHoaDon,
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
      other.nhomTat.length == nhomTat.length &&
      other.nhomTat.containsAll(nhomTat);

  @override
  int get hashCode => Object.hash(
        osBat,
        gioNhac,
        phutNhac,
        soNgayNhacHoaDon,
        Object.hashAllUnordered(nhomTat),
      );

  @override
  String toString() => 'NotificationPrefs(osBat: $osBat, nhomTat: '
      '${nhomTat.map((n) => n.name).toList()}, gioNhac: $gioNhac:'
      '${phutNhac.toString().padLeft(2, '0')}, '
      'soNgayNhacHoaDon: $soNgayNhacHoaDon)';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit.dart';

void main() {
  group('mocKeTiep — bước sang kỳ kế tiếp', () {
    test('ngày, tuần, quý, năm', () {
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Day'), DateTime(2026, 3, 11));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Week'), DateTime(2026, 3, 17));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Quarter'), DateTime(2026, 6, 10));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Year'), DateTime(2027, 3, 10));
    });

    test('chu kỳ trống hoặc lạ thì coi như hàng tháng', () {
      expect(mocKeTiep(DateTime(2026, 3, 10), null), DateTime(2026, 4, 10));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Fortnight'),
          DateTime(2026, 4, 10));
    });

    test('31/01 + 1 tháng là 28/02, KHÔNG phải 03/03', () {
      expect(mocKeTiep(DateTime(2026, 1, 31), 'Month'), DateTime(2026, 2, 28),
          reason: 'DateTime(2026, 2, 31) tự chuẩn hoá thành 03/03 chứ không '
              'ném lỗi. Không kẹp về ngày cuối tháng thì mọi mục tiêu đặt vào '
              'ngày 29–31 sẽ trôi dần sang tháng sau, mỗi kỳ một ít, và không '
              'có gì báo.');
    });

    test('31/01 + 1 tháng trong NĂM NHUẬN là 29/02', () {
      expect(mocKeTiep(DateTime(2028, 1, 31), 'Month'), DateTime(2028, 2, 29),
          reason: '2028 là năm nhuận. Kẹp cứng về 28 là mất một ngày mỗi bốn '
              'năm — đúng loại lỗi chỉ lộ ra sau khi bàn giao.');
    });

    test('31/01 + 1 quý là 30/04', () {
      expect(mocKeTiep(DateTime(2026, 1, 31), 'Quarter'), DateTime(2026, 4, 30),
          reason: 'Quý cũng là phép cộng THÁNG nên dính đúng cái bẫy ấy.');
    });

    test('29/02 năm nhuận + 1 năm là 28/02', () {
      expect(mocKeTiep(DateTime(2028, 2, 29), 'Year'), DateTime(2029, 2, 28),
          reason: 'Năm sau không có 29/02.');
    });

    test('giữ nguyên giờ phút của mốc', () {
      expect(mocKeTiep(DateTime(2026, 3, 10, 8, 30), 'Month'),
          DateTime(2026, 4, 10, 8, 30),
          reason: 'Mốc trích là một thời điểm, không phải một ngày. Cắt giờ đi '
              'làm kỳ đầu tiên đến sớm hơn dự tính tới gần một ngày.');
    });
  });

  group('cacKyDenHan — những kỳ đã tới hạn', () {
    test('chưa tới kỳ nào thì rỗng', () {
      final ra = cacKyDenHan(
        mocNeo: null,
        lanChayGanNhat: DateTime(2026, 9, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 20),
      );
      expect(ra, isEmpty,
          reason: 'Bật công tắc ngày 5 thì kỳ đầu tiên rơi vào ngày 5 tháng '
              'sau. Trích ngay lúc bật là lấy tiền người dùng chưa đồng ý.');
    });

    test('đúng một kỳ đã qua', () {
      final ra = cacKyDenHan(
        mocNeo: null,
        lanChayGanNhat: DateTime(2026, 8, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 20),
      );
      expect(ra, [DateTime(2026, 9, 5)]);
    });

    test('bỏ app nhiều tháng thì trả về ĐỦ các kỳ, theo thứ tự', () {
      final ra = cacKyDenHan(
        mocNeo: null,
        lanChayGanNhat: DateTime(2026, 6, 15),
        chuKy: 'Month',
        now: DateTime(2026, 9, 20),
      );
      expect(ra, [
        DateTime(2026, 7, 15),
        DateTime(2026, 8, 15),
        DateTime(2026, 9, 15),
      ]);
    });

    test('mốc rơi ĐÚNG hiện tại thì tính là đã tới hạn', () {
      final ra = cacKyDenHan(
        mocNeo: null,
        lanChayGanNhat: DateTime(2026, 8, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 5),
      );
      expect(ra, [DateTime(2026, 9, 5)],
          reason: 'Biên phải nằm về phía "đã tới hạn", nếu không kỳ ấy trượt '
              'sang lượt chạy sau mà không có lý do nào giải thích được.');
    });

    test('có TRẦN số kỳ mỗi lượt chạy', () {
      final ra = cacKyDenHan(
        mocNeo: null,
        lanChayGanNhat: DateTime(2020, 1, 1),
        chuKy: 'Day',
        now: DateTime(2026, 9, 20),
        toiDa: 12,
      );
      expect(ra.length, 12,
          reason: 'Máy để lâu không mở, chu kỳ ngày, là hàng nghìn kỳ. Trích '
              'hết trong một lượt sẽ rút cạn ví nguồn ngay khi người dùng vừa '
              'mở app. Phần dư để lượt sau xử lý tiếp — không mất kỳ nào.');
      expect(ra.first, DateTime(2020, 1, 2),
          reason: 'Cắt ở ĐUÔI, không ở đầu: các kỳ phải chạy theo đúng thứ tự '
              'thời gian, nếu không mốc chạy gần nhất sẽ nhảy cóc.');
    });

    test('chưa từng chạy lần nào thì không đoán bừa', () {
      expect(
        cacKyDenHan(
          mocNeo: null,
          lanChayGanNhat: null,
          chuKy: 'Month',
          now: DateTime(2026, 9, 20),
        ),
        isEmpty,
        reason: 'Mốc null nghĩa là chưa bật trích tự động. Lấy ngày tạo mục '
            'tiêu làm mốc là bật công tắc hôm nay rồi bị trích ngược lại sáu '
            'tháng cùng một lúc.',
      );
    });
  });

  group('mốc neo do người dùng chọn', () {
    test('nhịp bám theo mốc neo, không bám lúc bật công tắc', () {
      final ra = cacKyDenHan(
        // Người dùng chọn "ngày 15 hàng tháng, 08:00"...
        mocNeo: DateTime(2026, 9, 15, 8),
        // ...trong khi bật công tắc lúc 14 giờ ngày 5.
        lanChayGanNhat: DateTime(2026, 9, 5, 14),
        chuKy: 'Month',
        now: DateTime(2026, 10, 20),
      );

      expect(ra, [DateTime(2026, 9, 15, 8), DateTime(2026, 10, 15, 8)],
          reason: 'Không có mốc neo thì nhịp rơi vào ngày 5 — tức lúc bấm công '
              'tắc — và lựa chọn "ngày 15" của người dùng không có tác dụng '
              'nào, im lặng.');
    });

    test('mốc neo nằm TRƯỚC lúc bật thì kỳ đầu nhảy sang chu kỳ sau', () {
      final ra = cacKyDenHan(
        // Chọn "ngày 1 hàng tháng" trong khi hôm nay đã là ngày 5.
        mocNeo: DateTime(2026, 9, 1, 8),
        lanChayGanNhat: DateTime(2026, 9, 5, 14),
        chuKy: 'Month',
        now: DateTime(2026, 10, 20),
      );

      expect(ra, [DateTime(2026, 10, 1, 8)],
          reason: 'Ngày 1 tháng này đã trôi qua TRƯỚC khi người dùng bật công '
              'tắc. Trích bù cho nó là lấy tiền cho một quãng thời gian họ '
              'chưa hề đồng ý — đúng cái mà mốc "lúc bật" sinh ra để chặn.');
    });

    test('GIỜ trong ngày được tôn trọng: không trích sớm hơn', () {
      final chuaToiGio = cacKyDenHan(
        mocNeo: DateTime(2026, 9, 15, 8),
        lanChayGanNhat: DateTime(2026, 9, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 15, 7, 59),
      );
      expect(chuaToiGio, isEmpty,
          reason: 'Bộ trích chạy khi app mở, nên giờ đã chọn chỉ giữ được MỘT '
              'chiều: không bao giờ sớm hơn. Bỏ vế này thì con số giờ trên màn '
              'hình hoàn toàn vô nghĩa.');

      final daToiGio = cacKyDenHan(
        mocNeo: DateTime(2026, 9, 15, 8),
        lanChayGanNhat: DateTime(2026, 9, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 15, 8),
      );
      expect(daToiGio, [DateTime(2026, 9, 15, 8)]);
    });

    test('mốc neo hàng tuần giữ đúng thứ trong tuần', () {
      // 08/09/2026 là thứ Ba.
      final ra = cacKyDenHan(
        mocNeo: DateTime(2026, 9, 8, 20),
        lanChayGanNhat: DateTime(2026, 9, 5),
        chuKy: 'Week',
        now: DateTime(2026, 9, 30),
      );
      expect(ra.map((d) => d.weekday).toSet(), {DateTime.tuesday});
      expect(ra.length, 4);
    });

    test('mốc neo ngày 31 vẫn kẹp về cuối tháng ngắn', () {
      final ra = cacKyDenHan(
        mocNeo: DateTime(2026, 1, 31, 9),
        lanChayGanNhat: DateTime(2026, 1, 1),
        chuKy: 'Month',
        now: DateTime(2026, 4, 15),
      );
      expect(ra, [
        DateTime(2026, 1, 31, 9),
        DateTime(2026, 2, 28, 9),
        DateTime(2026, 3, 28, 9),
      ], reason: 'Kẹp về 28/02 rồi bước tiếp từ ĐÓ — nhịp trôi dần chứ không '
          'quay lại ngày 31. Đây là hệ quả của việc bước từng kỳ một, và nó '
          'phải được ghi lại rõ chứ không để ai đó phát hiện bằng bất ngờ.');
    });

    test('mốc neo quá xa trong quá khứ thì im lặng bỏ qua', () {
      final ra = cacKyDenHan(
        mocNeo: DateTime(1990, 1, 1),
        lanChayGanNhat: DateTime(2026, 9, 5),
        chuKy: 'Day',
        now: DateTime(2026, 9, 20),
      );
      expect(ra, isEmpty,
          reason: 'Mốc neo đi qua đường đồng bộ nên có thể mang giá trị rác từ '
              'Admin-web hay bản app khác. Bước từng ngày từ 1990 là hàng chục '
              'nghìn vòng lặp ngay trong vòng quét thông báo — treo app. Bỏ '
              'qua và im lặng, cùng nguyên tắc với isBehindSchedule.');
    });
  });

  group('mocNeoTu — dựng mốc neo từ lựa chọn trên màn hình', () {
    final now = DateTime(2026, 9, 5, 14, 30); // thứ Bảy

    test('hàng ngày chỉ lấy giờ, ngày là hôm nay', () {
      expect(mocNeoTu(chuKy: 'Day', ngay: null, gio: 8, phut: 0, now: now),
          DateTime(2026, 9, 5, 8, 0));
    });

    test('hàng tuần rơi đúng thứ đã chọn trong tuần này', () {
      // 2 = thứ Ba. Tuần chứa 05/09/2026 (thứ Bảy) có thứ Ba là 01/09.
      final moc =
          mocNeoTu(chuKy: 'Week', ngay: 2, gio: 20, phut: 15, now: now);
      expect(moc.weekday, DateTime.tuesday);
      expect(moc, DateTime(2026, 9, 1, 20, 15));
    });

    test('hàng tháng rơi đúng ngày đã chọn trong tháng này', () {
      expect(mocNeoTu(chuKy: 'Month', ngay: 15, gio: 8, phut: 0, now: now),
          DateTime(2026, 9, 15, 8, 0));
    });

    test('chọn ngày 31 ở tháng chỉ có 30 ngày thì kẹp về ngày cuối', () {
      expect(mocNeoTu(chuKy: 'Month', ngay: 31, gio: 8, phut: 0, now: now),
          DateTime(2026, 9, 30, 8, 0),
          reason: 'Tháng 9 có 30 ngày. DateTime(2026, 9, 31) tự thành 01/10 '
              'chứ không ném — mốc neo sẽ lệch sang tháng sau ngay từ lúc '
              'dựng, trước cả khi bước kỳ nào.');
    });

    test('mốc neo dựng ra có thể nằm ở QUÁ KHỨ, và như vậy là đúng', () {
      final moc = mocNeoTu(chuKy: 'Month', ngay: 1, gio: 8, phut: 0, now: now);
      expect(moc.isBefore(now), isTrue,
          reason: 'Chọn "ngày 1" vào ngày 5 thì mốc neo là 01/09 — đã qua. '
              'Không phải lỗi: nó chỉ định NHỊP, còn việc không trích bù cho '
              'kỳ đã qua là do sàn `autoDepositLastRun` lo.');
    });
  });

  group('nhanMocNeo — câu chữ trên màn hình', () {
    test('nói rõ cả ngày lẫn giờ', () {
      expect(nhanMocNeo('Month', DateTime(2026, 9, 15, 8, 0)),
          'Ngày 15 hàng tháng, 08:00');
      expect(nhanMocNeo('Week', DateTime(2026, 9, 1, 20, 15)),
          'Thứ Ba hàng tuần, 20:15');
      expect(nhanMocNeo('Day', DateTime(2026, 9, 5, 8, 5)), 'Mỗi ngày, 08:05');
    });

    test('chủ nhật gọi đúng tên, không phải "Thứ 8"', () {
      // 06/09/2026 là chủ nhật.
      expect(nhanMocNeo('Week', DateTime(2026, 9, 6, 9, 0)),
          'Chủ nhật hàng tuần, 09:00');
    });

    test('chưa chọn thì nói là chưa chọn, không bịa mặc định', () {
      expect(nhanMocNeo('Month', null), 'Chưa chọn — trích theo lúc bật',
          reason: 'Mục tiêu bật trích từ bản trước không có mốc neo. Hiện một '
              'ngày mặc định nào đó là nói dối về nhịp mà nó đang chạy.');
    });
  });

  group('quyetDinhTrich — trích bao nhiêu cho MỘT kỳ', () {
    test('đủ tiền và còn thiếu nhiều thì trích đúng số đã cài', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 2000000, soDuViNguon: 900000);
      expect(qd.loai, LoaiTrich.trichDu);
      expect(qd.soTien, 500000);
    });

    test('còn thiếu ÍT hơn số cài thì chỉ trích phần còn thiếu', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 120000, soDuViNguon: 900000);
      expect(qd.loai, LoaiTrich.trichPhanConLai);
      expect(qd.soTien, 120000,
          reason: 'Nạp vượt mục tiêu bằng tay thì app CẢNH BÁO rồi cho qua — '
              'người dùng đang nhìn màn hình. Trích tự động thì họ vắng mặt, '
              'nên vượt bao nhiêu cũng không ai duyệt. Kẹp ở phần còn thiếu.');
    });

    test('ví nguồn không đủ thì KHÔNG trích một phần', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 2000000, soDuViNguon: 300000);
      expect(qd.loai, LoaiTrich.viKhongDu);
      expect(qd.soTien, 0,
          reason: 'Trích một phần làm sổ sách khó đọc (một kỳ ra hai con số '
              'khác nhau) và vẫn không giải quyết được việc thiếu tiền. Bỏ kỳ '
              'đó và BÁO cho người dùng.');
    });

    test('ví vừa đủ đúng bằng số cần trích thì vẫn trích', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 2000000, soDuViNguon: 500000);
      expect(qd.loai, LoaiTrich.trichDu,
          reason: 'Số dư 0 sau khi trích là hợp lệ; chỉ số dư ÂM mới sai. '
              'Chặt hơn ở đây là từ chối một thao tác đúng.');
    });

    test('mục tiêu đã đủ thì dừng hẳn', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 0, soDuViNguon: 900000);
      expect(qd.loai, LoaiTrich.mucTieuDaXong);
      expect(qd.soTien, 0);
    });

    test('số cài ≤ 0 thì không trích', () {
      expect(
        quyetDinhTrich(soTienCai: 0, conThieu: 2000000, soDuViNguon: 900000)
            .loai,
        LoaiTrich.mucTieuDaXong,
        reason: 'Không có số tiền hợp lệ thì không có gì để trích. Trả về một '
            'nhánh DỪNG chứ không phải nhánh "thiếu tiền" — báo "ví không đủ" '
            'cho một cấu hình sai làm người dùng đi nạp tiền vô ích.',
      );
    });
  });

  group('khoaKyTrich — khoá chống trùng của một kỳ', () {
    test('cùng kỳ thì cùng khoá, dù quét bao nhiêu lần', () {
      // Mốc của một kỳ là giá trị TÍNH RA, không phải "bây giờ" — nên hai lượt
      // quét cách nhau vẫn cho cùng một mốc, và vì thế cùng một khoá.
      expect(
        khoaKyTrich('g1', DateTime(2026, 9, 5, 8, 30)),
        khoaKyTrich('g1', DateTime(2026, 9, 5, 8, 30)),
        reason: 'Vòng quét chạy sau mọi lần đồng bộ. Khoá đổi giữa hai lượt là '
            'mỗi lần mở app lại đẻ thêm một thông báo cho việc đã làm rồi.',
      );
    });

    test('hai kỳ CÙNG NGÀY nhưng khác giờ thì khác khoá', () {
      expect(
        khoaKyTrich('g1', DateTime(2026, 9, 5, 8, 30)),
        isNot(khoaKyTrich('g1', DateTime(2026, 9, 5, 21, 0))),
        reason: 'Gộp tới mức NGÀY từng làm một khoản trích thật đi qua mà '
            'KHÔNG có thông báo nào: nó đụng khoá của một kỳ khác cùng ngày, '
            'sinh ra sau khi người dùng đổi chu kỳ. Tiền rời ví trong im lặng '
            'là kiểu hỏng tệ nhất ở vùng này. Mốc kỳ đã là giá trị tính ra và '
            'ổn định, nên đưa cả giờ phút vào khoá không mất tính khử trùng.',
      );
    });

    test('khác mục tiêu hoặc khác kỳ thì khác khoá', () {
      expect(khoaKyTrich('g1', DateTime(2026, 9, 5)),
          isNot(khoaKyTrich('g2', DateTime(2026, 9, 5))));
      expect(khoaKyTrich('g1', DateTime(2026, 9, 5)),
          isNot(khoaKyTrich('g1', DateTime(2026, 10, 5))));
    });
  });
}

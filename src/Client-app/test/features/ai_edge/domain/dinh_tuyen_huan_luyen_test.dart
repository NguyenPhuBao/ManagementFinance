/// Dự án B — phép HỌC của bộ định tuyến (spec mục 4.2), trên dữ liệu đồ chơi.
///
/// Canh chừng điều gì: con số của kiểm chéo quyết ngưỡng và quyết mô hình nào
/// vào app. Kiểm chéo để lọt mẫu đang được đoán vào tập học, hay phép đánh giá
/// bỏ sót một kiểu định tuyến sai, đều cho ra một ngưỡng THẤP hơn mức an toàn —
/// và không gì báo: bảng so sánh chỉ trông đẹp hơn.
library;

import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/dinh_tuyen/du_lieu.dart';
import '../../../tool/dinh_tuyen/huan_luyen.dart';

const _nhan = ['x', 'y', kNhanKhongDinhTuyen];

const _doChoi = [
  MauDinhTuyen('x', 'hoa don dien'),
  MauDinhTuyen('x', 'hoa don nuoc'),
  MauDinhTuyen('x', 'hoa don nao qua han'),
  MauDinhTuyen('x', 'hoa don chua tra'),
  MauDinhTuyen('x', 'tra hoa don'),
  MauDinhTuyen('x', 'hoa don thang nay'),
  MauDinhTuyen('y', 'vi nao am'),
  MauDinhTuyen('y', 'so du vi'),
  MauDinhTuyen('y', 'vi tien mat'),
  MauDinhTuyen('y', 'may vi'),
  MauDinhTuyen('y', 'vi tiet kiem'),
  MauDinhTuyen('y', 'tong vi'),
  MauDinhTuyen(kNhanKhongDinhTuyen, 'xin chao'),
  MauDinhTuyen(kNhanKhongDinhTuyen, 'chao ban'),
  MauDinhTuyen(kNhanKhongDinhTuyen, 'thoi tiet hom nay'),
  MauDinhTuyen(kNhanKhongDinhTuyen, 'thoi tiet ngay mai'),
  MauDinhTuyen(kNhanKhongDinhTuyen, 'cam on ban'),
  MauDinhTuyen(kNhanKhongDinhTuyen, 'chao buoi sang'),
];

DuDoan _d(String dung, String doan, double p) => DuDoan(MauDinhTuyen(dung, 'c'), doan, p);

void main() {
  group('khuTrung', () {
    test('giữ mẫu đầu, bỏ câu trùng sau chuẩn hoá (có dấu / không dấu)', () {
      final r = khuTrung(const [
        MauDinhTuyen('x', 'Hoá đơn nào quá hạn?'),
        MauDinhTuyen('x', 'hoa don nao qua han'),
        MauDinhTuyen('y', 'vi nao am'),
      ]);
      expect(r.map((m) => m.cau), ['Hoá đơn nào quá hạn?', 'vi nao am']);
    });

    test('cùng một câu mang HAI nhãn → ném, kèm câu', () {
      expect(
          () => khuTrung(const [MauDinhTuyen('x', 'vi nao am'), MauDinhTuyen('y', 'Ví nào âm?')]),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('vi nao am'))));
    });
  });

  test('tuVungTu: chỉ đặc trưng có ở ≥ 2 mẫu, xếp theo chữ', () {
    final tv = tuVungTu(_doChoi);
    expect(tv, contains('hoa don'));
    expect(tv, contains('thoi tiet'));
    expect(tv, isNot(contains('dien')), reason: 'chỉ có ở một mẫu');
    expect(tv, [...tv]..sort());
  });

  for (final (ten, hoc) in <(String, HamHoc)>[('Naive Bayes', hocNaiveBayes), ('logistic', hocLogistic)]) {
    group(ten, () {
      test('đoán đúng nhãn mọi câu đã học', () {
        final w = hoc(_doChoi, _nhan);
        for (final m in _doChoi) {
          expect(doanDinhTuyen(w, m.cau).nhan, m.nhan, reason: m.cau);
        }
      });

      test('chạy hai lần ra CÙNG trọng số (không ngẫu nhiên)', () {
        expect(hoc(_doChoi, _nhan).maTran, hoc(_doChoi, _nhan).maTran);
      });

      test('nhãn không có mẫu nào không làm hỏng phép học', () {
        final w = hoc(_doChoi, [..._nhan, 'z']);
        expect(w.maTran.every((v) => v.isFinite), isTrue);
        expect(doanDinhTuyen(w, 'hoa don dien').nhan, 'x');
      });
    });
  }

  test('logistic tự tin hơn khi học lâu hơn — vòng lặp thật sự chạy', () {
    final it = hocLogistic(_doChoi, _nhan, vong: 5);
    final nhieu = hocLogistic(_doChoi, _nhan, vong: 400);
    expect(doanDinhTuyen(nhieu, 'hoa don dien').xacSuat,
        greaterThan(doanDinhTuyen(it, 'hoa don dien').xacSuat));
  });

  group('phanCua', () {
    test('tất định và luôn trong [0, soPhan)', () {
      for (final m in _doChoi) {
        final p = phanCua(chuanHoaDinhTuyen(m.cau));
        expect(p, inInclusiveRange(0, 4));
        expect(phanCua(chuanHoaDinhTuyen(m.cau)), p);
      }
    });

    test('18 câu đồ chơi không dồn hết vào một phần', () {
      expect(_doChoi.map((m) => phanCua(chuanHoaDinhTuyen(m.cau))).toSet().length, greaterThan(2));
    });
  });

  group('kiemCheo', () {
    test('mỗi mẫu được đoán đúng một lần', () {
      final d = kiemCheo(_doChoi, _nhan, hocNaiveBayes);
      expect(d.map((x) => x.mau).toSet(), _doChoi.toSet());
      expect(d, hasLength(_doChoi.length));
    });

    test('⭐ mô hình đoán một mẫu KHÔNG được học mẫu ấy', () {
      // Bộ học giả: ghi lại tập học của từng lượt, và trả một mô hình luôn đoán
      // nhãn "goi<i>" — nhãn đoán vì thế nói ra lượt học nào đã đoán mẫu ấy.
      final tapHoc = <Set<MauDinhTuyen>>[];
      final moiAmTiet = {for (final m in _doChoi) ...amTietDinhTuyen(m.cau)}.toList()..sort();
      TrongSoDinhTuyen gia(List<MauDinhTuyen> mau, List<String> nhan) {
        tapHoc.add(mau.toSet());
        return TrongSoDinhTuyen(
          nhan: ['goi${tapHoc.length - 1}', 'khac'],
          tuVung: moiAmTiet,
          thienLech: [5, 0],
          maTran: List.filled(moiAmTiet.length * 2, 0),
        );
      }

      final d = kiemCheo(_doChoi, _nhan, gia);
      expect(d, hasLength(_doChoi.length));
      for (final x in d) {
        final luot = int.parse(x.nhanDoan.substring(3));
        expect(tapHoc[luot], isNot(contains(x.mau)),
            reason: '"${x.mau.cau}" nằm trong tập học của chính mô hình đoán nó');
        expect(tapHoc[luot], isNotEmpty);
      }
    });
  });

  group('danhGia', () {
    final d = [
      _d('x', 'x', 0.9), // định tuyến đúng
      _d('x', 'y', 0.8), // định tuyến SAI
      _d('x', 'x', 0.4), // dưới ngưỡng — không định tuyến
      _d(kNhanKhongDinhTuyen, 'y', 0.7), // câu không nên định tuyến mà bị định tuyến — SAI
      _d('y', kNhanKhongDinhTuyen, 0.99), // đoán nhãn âm — không định tuyến
      _d(kNhanKhongDinhTuyen, kNhanKhongDinhTuyen, 0.95),
    ];

    test('đếm định tuyến sai, phủ, chính xác', () {
      final t = danhGia(d, 0.6);
      expect(t.soDinhTuyen, 3);
      expect(t.dinhTuyenSai, 2);
      expect(t.phu, closeTo(1 / 4, 1e-9), reason: 'một câu định tuyến đúng trên bốn câu mang nhãn tool');
      expect(t.chinhXac, closeTo(3 / 6, 1e-9));
    });

    test('⭐ câu nhãn đúng là "không định tuyến" bị định tuyến tính là SAI', () {
      expect(danhGia([_d(kNhanKhongDinhTuyen, 'y', 0.7)], 0.6).dinhTuyenSai, 1);
    });

    test('đoán nhãn âm không bao giờ là định tuyến, dù xác suất cao', () {
      final t = danhGia([_d('y', kNhanKhongDinhTuyen, 0.99)], 0.5);
      expect(t.soDinhTuyen, 0);
      expect(t.dinhTuyenSai, 0);
    });

    test('ngưỡng cao hơn thì bớt câu sai', () {
      expect(danhGia(d, 0.85).dinhTuyenSai, 0);
    });

    group('hanhDong — nhãn mà app được phép định tuyến theo (hướng 1, 2026-10-02)', () {
      test('⭐ mô hình đoán một tool NGOÀI tập hành động → không định tuyến, không tính sai', () {
        final t = danhGia(d, 0.6, hanhDong: {'x'});
        expect(t.soDinhTuyen, 1, reason: 'chỉ còn câu đoán x ở 0,9');
        expect(t.dinhTuyenSai, 0, reason: 'hai câu đoán y không còn được định tuyến');
      });

      test('phủ tính trên câu mang nhãn thuộc tập hành động', () {
        final t = danhGia(d, 0.6, hanhDong: {'x'});
        expect(t.phu, closeTo(1 / 3, 1e-9), reason: 'một câu định tuyến đúng trên ba câu nhãn x');
      });

      test('chonNguong chỉ bị đẩy lên bởi câu sai VÀO tập hành động', () {
        final ds = [_d('x', 'y', 0.97), _d('y', 'x', 0.71), _d('x', 'x', 0.9)];
        expect(chonNguong(ds), closeTo(0.99, 1e-9), reason: 'không giới hạn: câu sai vào y ở 0,97 quyết ngưỡng');
        expect(chonNguong(ds, hanhDong: {'x'}), closeTo(0.77, 1e-9),
            reason: 'câu sai vào y ở 0,97 không còn là định tuyến; chỉ câu sai vào x ở 0,71 quyết ngưỡng');
      });
    });

    group('chapNhan — câu mà tool khác cũng trả lời đúng', () {
      const hai = MauDinhTuyen('y', 'thu nhieu hon chi khong', chapNhan: {'x'});

      test('⭐ định tuyến sang tool được chấp nhận KHÔNG tính là sai, và không tính vào phủ', () {
        final t = danhGia([const DuDoan(hai, 'x', 0.9), _d('x', 'x', 0.9)], 0.6, hanhDong: {'x'});
        expect(t.dinhTuyenSai, 0);
        expect(t.soChapNhan, 1);
        expect(t.soDinhTuyen, 2);
        expect(t.phu, closeTo(1, 1e-9), reason: 'phủ = câu nhãn x được định tuyến đúng / câu nhãn x');
      });

      test('định tuyến sang tool KHÔNG được chấp nhận vẫn là sai', () {
        expect(danhGia([const DuDoan(hai, 'z', 0.9)], 0.6).dinhTuyenSai, 1);
      });

      test('câu chấp nhận không đẩy ngưỡng lên', () {
        expect(chonNguong([const DuDoan(hai, 'x', 0.93)], hanhDong: {'x'}), closeTo(0.60, 1e-9));
      });
    });
  });

  test('⭐ phanLuatBoLai: câu LUẬT đã định tuyến không tới mô hình, nên không được chấm', () {
    final d = [
      const DuDoan(MauDinhTuyen('x', 'hoa don nao qua han'), 'y', 0.99),
      const DuDoan(MauDinhTuyen('x', 'cau luat khong bat'), 'x', 0.7),
    ];
    final con = phanLuatBoLai(d, (c) => c.contains('qua han') ? 'x' : null);
    expect(con.map((x) => x.mau.cau), ['cau luat khong bat']);
    expect(chonNguong(con), closeTo(0.60, 1e-9),
        reason: 'câu sai ở p = 0,99 là câu luật đã bắt — nó không được đẩy ngưỡng lên');
  });

  group('chonNguong', () {
    test('mức thấp nhất hết sai + đệm 0,05', () {
      final d = [_d('x', 'y', 0.71), _d('x', 'x', 0.9)];
      expect(chonNguong(d), closeTo(0.77, 1e-9));
    });

    test('không câu nào sai → sàn 0,60', () {
      expect(chonNguong([_d('x', 'x', 0.55), _d('y', 'y', 0.9)]), closeTo(0.60, 1e-9));
    });

    test('đệm không vượt trần 0,99', () {
      expect(chonNguong([_d('x', 'y', 0.97)]), closeTo(0.99, 1e-9));
    });

    test('còn câu sai ở 0,99 → null (mô hình bị loại)', () {
      expect(chonNguong([_d('x', 'y', 0.995)]), isNull);
    });
  });

  group('sinhTepTrongSo', () {
    String sinh(List<String> tuVung) => sinhTepTrongSo(
          TrongSoDinhTuyen(
            nhan: ['a', 'b'],
            tuVung: tuVung,
            thienLech: [0.1, -0.2],
            maTran: List.generate(tuVung.length * 2, (i) => i * 0.5),
          ),
          loai: 'logistic',
          nguong: 0.85,
          bamHuanLuyen: 'abc123',
        );

    test('mang đủ bốn hằng và mã băm', () {
      final s = sinh(['hoa don', 'vi']);
      expect(s, contains("const String kLoaiMoHinhDinhTuyen = 'logistic';"));
      expect(s, contains('const double kNguongDinhTuyen = 0.85;'));
      expect(s, contains("const String kBamBoHuanLuyen = 'abc123';"));
      expect(s, contains('final TrongSoDinhTuyen kTrongSoDinhTuyen'));
      expect(s, contains('|hoa don|vi|'));
    });

    test('⭐ không bao giờ in âm tiết chiều tiền đứng riêng trong nháy (test quét 14)', () {
      // Ghép chuỗi lúc chạy để chính tệp test này không chứa khuôn bị cấm.
      final chi = ['c', 'h', 'i'].join(), thu = ['t', 'h', 'u'].join();
      for (final tv in [
        [chi],
        [thu],
        [chi, thu],
        [thu, 'vi', chi],
      ]) {
        final s = sinh(tv);
        expect(s, isNot(contains("'$chi'")), reason: '$tv');
        expect(s, isNot(contains("'$thu'")), reason: '$tv');
      }
    });
  });
}

/// Rời nhà / Giải tán phải ĐẨY hàng chưa lên server trước khi gọi API, và CHỜ thật (spec gia đình 2026-11-01 mục 7.3): sau
/// khi rời, server từ chối hàng của nhà (`HOUSEHOLD_NOT_MEMBER`), nên hàng chưa đẩy lúc ấy là mất. Đẩy xong mà vẫn còn hàng
/// thì ném [LoaiLoiNha.hangChuaDay] và KHÔNG gọi API; `boQuaHangChuaDay` là lối "tiếp tục dù mất" (hộp hỏi lại thuộc đợt 1B).
library;

import 'dart:async';

import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';

void main() {
  late HouseholdApiGia api;
  late InMemoryNhaStore kho;
  late List<String> nhatKy;
  late Future<void> Function() day;
  late Future<int> Function(int) dem;
  late NhaRepositoryImpl repo;

  Future<void> dung({bool voiHook = true}) async {
    repo = NhaRepositoryImpl(
      api: api,
      kho: kho,
      dayTruocKhiRoi: voiHook ? () => day() : null,
      demHangChuaDay: voiHook ? (n) => dem(n) : null,
    );
    kho.values[18] = nhaCuaToiTuJson(nhaJson(), nhanLuc: DateTime.utc(2026, 11, 1));
    await repo.datTaiKhoan(18);
  }

  setUp(() {
    api = HouseholdApiGia();
    kho = InMemoryNhaStore();
    nhatKy = [];
    day = () async => nhatKy.add('day(api=${api.goi.length})');
    dem = (n) async {
      nhatKy.add('dem($n,api=${api.goi.length})');
      return 0;
    };
  });
  tearDown(() => repo.dispose());

  for (final viec in ['roiNha', 'giaiTan']) {
    Future<void> goi({bool boQua = false}) =>
        viec == 'roiNha' ? repo.roiNha(boQuaHangChuaDay: boQua) : repo.giaiTan(boQuaHangChuaDay: boQua);

    group(viec, () {
      test('thứ tự: đẩy → đếm → API (đẩy và đếm xảy ra khi API CHƯA được gọi)', () async {
        await dung();
        await goi();
        expect(nhatKy, ['day(api=0)', 'dem(12,api=0)'], reason: 'sau khi gọi API thì server đã từ chối hàng của nhà');
        expect(api.goi, contains(viec));
      });

      test('đẩy đang treo thì thao tác phải CHỜ, chưa gọi API', () async {
        final treo = Completer<void>();
        await dung();
        day = () => treo.future;
        var xong = false;
        final f = goi().then((_) => xong = true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(xong, isFalse, reason: 'không chờ lượt đẩy là hàng chưa đẩy bị server từ chối ngay sau đó');
        expect(api.goi, isEmpty);
        treo.complete();
        await f;
        expect(api.goi, contains(viec));
      });

      test('hook đẩy ném lỗi: vẫn tới bước đếm và API (mất mạng thì API tự báo đúng câu)', () async {
        await dung();
        day = () async => throw StateError('mất mạng');
        await goi();
        expect(nhatKy, ['dem(12,api=0)']);
        expect(api.goi, contains(viec));
      });

      test('còn hàng chưa đẩy: ném hangChuaDay và KHÔNG gọi API', () async {
        await dung();
        dem = (n) async => 3;
        await expectLater(goi(), throwsA(isA<LoiNha>().having((e) => e.loai, 'loai', LoaiLoiNha.hangChuaDay)));
        expect(api.goi, isEmpty, reason: 'gọi API trước khi người dùng đồng ý bỏ hàng là mất dữ liệu');
        expect(repo.hienTai.nha!.id, 12, reason: 'nhà trên máy không đổi');
      });

      test('boQuaHangChuaDay: vẫn đẩy, gọi API, không cản', () async {
        await dung();
        dem = (n) async => 3;
        await goi(boQua: true);
        expect(nhatKy, ['day(api=0)']);
        expect(api.goi, contains(viec));
      });

      test('phép đếm hỏng: coi như còn hàng (an toàn), không gọi API', () async {
        await dung();
        dem = (n) async => throw StateError('csdl');
        await expectLater(goi(), throwsA(isA<LoiNha>().having((e) => e.loai, 'loai', LoaiLoiNha.hangChuaDay)));
        expect(api.goi, isEmpty);
      });
    });
  }

  test('không có hook (test cũ, chế độ nền): hành vi như trước, gọi API thẳng', () async {
    await dung(voiHook: false);
    await repo.roiNha();
    expect(api.goi, ['roiNha']);
  });

  test('chưa ở nhà nào: không đếm theo nhà null, API tự báo lỗi', () async {
    await dung();
    kho.values.clear();
    repo.xoaPhien();
    await repo.datTaiKhoan(18); // kho trống → chưa có nhà
    await repo.roiNha();
    expect(nhatKy.where((s) => s.startsWith('dem')), isEmpty);
    expect(api.goi, ['roiNha']);
  });

  test('câu lỗi của hangChuaDay có chữ tiếng Việt, không in số', () {
    final cau = cauLoiNha(LoaiLoiNha.hangChuaDay);
    expect(cau, isNotEmpty);
    expect(RegExp(r'\d').hasMatch(cau), isFalse);
  });
}

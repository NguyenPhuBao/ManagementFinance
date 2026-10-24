import 'dart:async';
import 'dart:typed_data';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/cai_dat_khoa_app_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/khoa_app_gia.dart';

class _KenhTreo extends KenhGia {
  _KenhTreo(this._treo);
  final Completer<KetQuaBatVanTay> _treo;
  int soLanBat = 0;
  @override
  Future<KetQuaBatVanTay> bat(int idaccount, Uint8List biMat) {
    soLanBat++;
    return _treo.future;
  }
}

void main() {
  test('bật vân tay hai lần khi lượt đầu còn treo → lời gọi chồng bị bỏ qua, kênh nhận MỘT lần bat', () async {
    final treo = Completer<KetQuaBatVanTay>();
    final kenh = _KenhTreo(treo);
    final sv = KhoaAppService(store: InMemoryKhoaAppStore(), kenh: kenh, bam: bamNhanh);
    await sv.datPin(10, '246810');
    final cubit = CaiDatKhoaAppCubit(service: sv, idaccount: 10);
    addTearDown(cubit.close);
    await cubit.napLai();

    final a = cubit.batVanTay();
    var bXong = false;
    final b = cubit.batVanTay()..whenComplete(() => bXong = true);
    await pumpEventQueue();
    expect(bXong, isTrue, reason: 'lời gọi chồng phải bị bỏ qua NGAY, không chờ lượt đầu');
    expect(kenh.soLanBat, 1);
    expect(cubit.state.dangLam, isTrue);

    treo.complete(const KetQuaBatVanTay.loi(LoiSinhTrac.huy));
    await Future.wait([a, b]);
    expect(cubit.state.dangLam, isFalse);
  });
}

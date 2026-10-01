/// Màn ĐO của spike C4 — giọng nói và chụp hoá đơn, mỗi phía hai lối (kế hoạch
/// `plans/2026-09-28-c4-spike-giong-noi-chup-hoa-don.md`). Chỉ vào được khi build với `--dart-define=SPIKE_C4=true`
/// (route `/spike-c4`, nút *Quét* ở Trang chủ). Mã BỎ ĐI: không nối vào luồng thật, không lưu gì — chỉ in kết quả thô,
/// thời gian và kết quả `docCauGiaoDich` lên màn và logcat (`[C4] …`, mỗi lượt một dòng; không in nội dung ảnh / âm).
///
/// | Phía | Lối A | Lối B |
/// |---|---|---|
/// | Giọng nói | `SpeechRecognizer` của Android (`speech_to_text`), `vi_VN`, công tắc *chỉ chạy trên máy* | Gemma E2B nhận WAV 16 kHz mono (`record`) |
/// | Hoá đơn | ML Kit Text Recognition (Latin) → luật `docHoaDonTuChu` | Gemma E2B nhận ảnh → JSON |
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/auth/current_account.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../ai_edge/data/mo_hinh_tai_ve.dart';
import '../../ai_edge/data/slm_runtime.dart';
import '../../category/data/repositories/category_management_repository.dart';
import '../../transaction/domain/doc_cau_giao_dich.dart';
import 'spike_c4.dart';

class SpikeC4Page extends StatefulWidget {
  const SpikeC4Page({super.key});

  @override
  State<SpikeC4Page> createState() => _SpikeC4PageState();
}

class _SpikeC4PageState extends State<SpikeC4Page> {
  final _ma = TextEditingController(text: 'N01');
  final _stt = SpeechToText();
  final _ghiAm = AudioRecorder();
  final List<String> _nhatKy = [];

  List<Wallet> _vi = const [];
  List<Category> _danhMuc = const [];
  Map<String, List<String>> _tuKhoa = const {};

  bool _chiTrenMay = false;
  bool _dangNghe = false;
  bool _dangGhi = false;
  bool _dangChay = false;
  String? _anh;
  String _loiTam = '';

  Stopwatch? _dongHoNghe;
  int? _mocDung;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _napDuLieu());
  }

  @override
  void dispose() {
    _ma.dispose();
    unawaited(_stt.cancel());
    unawaited(_ghiAm.dispose());
    // Trả mô hình về trạng thái chưa nạp: đường chữ thường sẽ nạp lại bản không cờ ảnh / âm thanh.
    unawaited(sl<SlmRuntime>().dong());
    super.dispose();
  }

  Future<void> _napDuLieu() async {
    final id = currentAccountIdOrNull(context);
    if (id == null) return _ghi('!! chưa có phiên đăng nhập — docCauGiaoDich sẽ không có ví / danh mục');
    final repo = sl<CategoryManagementRepository>();
    final vi = await sl<AppDatabase>().walletDao.getActive(id);
    final dm = await repo.selectableChildrenAll(accountId: id);
    final tk = await repo.loadAllKeywords(accountId: id);
    if (!mounted) return;
    setState(() {
      _vi = vi;
      _danhMuc = dm;
      _tuKhoa = tk;
    });
    _ghi('nạp ${vi.length} ví, ${dm.length} danh mục');
  }

  void _ghi(String dong) {
    // ignore: avoid_print
    print('[C4] ${_ma.text.trim()} | $dong');
    if (mounted) setState(() => _nhatKy.insert(0, '${_ma.text.trim()} | $dong'));
  }

  /// Chấm một câu bằng đúng hàm của ô Nhập nhanh (luật, không AI): điền được những ô nào.
  String _cham(String cau) {
    if (cau.trim().isEmpty) return 'câu rỗng';
    final kq = docCauGiaoDich(cau, now: DateTime.now(), vi: _vi, chonDuoc: _danhMuc, tuKhoa: _tuKhoa);
    String? ten<T>(Iterable<T> ds, bool Function(T) la, String Function(T) lay) {
      for (final x in ds) {
        if (la(x)) return lay(x);
      }
      return null;
    }

    final ngay = kq.ngay;
    return [
      'tiền=${kq.soTien == null ? '—' : CurrencyFormatter.format(kq.soTien!)}',
      'loại=${kq.loai ?? '—'}',
      'ngày=${ngay == null ? '—' : '${ngay.day}/${ngay.month}'}',
      'ví=${ten<Wallet>(_vi, (w) => w.id == kq.walletId, (w) => w.name) ?? '—'}',
      'dm=${ten<Category>(_danhMuc, (c) => c.id == kq.categoryId, (c) => c.name) ?? '—'}',
      'ghi chú="${kq.ghiChu}"',
      if (kq.oThieu.isNotEmpty) 'thiếu=${kq.oThieu.map((o) => o.name).join(',')}',
    ].join(' · ');
  }

  // ── Giọng nói — lối A ────────────────────────────────────────────────────────────────────────────────────────────

  Future<void> _noiA() async {
    if (_dangNghe) {
      _mocDung = _dongHoNghe?.elapsedMilliseconds;
      await _stt.stop();
      return;
    }
    final ok = await _stt.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          _mocDung ??= _dongHoNghe?.elapsedMilliseconds;
          if (mounted) setState(() => _dangNghe = false);
        }
      },
      onError: (SpeechRecognitionError e) {
        _ghi('NÓI-A ${_chiTrenMay ? 'trên-máy' : 'mặc-định'} LỖI ${e.errorMsg} (permanent=${e.permanent})');
        if (mounted) setState(() => _dangNghe = false);
      },
    );
    if (!ok) return _ghi('NÓI-A không khởi tạo được SpeechRecognizer (thiếu quyền micro hoặc máy không có dịch vụ)');
    final coVi = (await _stt.locales()).where((l) => l.localeId.toLowerCase().startsWith('vi')).map((l) => l.localeId);
    if (coVi.isEmpty) _ghi('NÓI-A ⚠️ máy không liệt kê locale vi nào');
    _dongHoNghe = Stopwatch()..start();
    _mocDung = null;
    setState(() {
      _dangNghe = true;
      _loiTam = '';
    });
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        onDevice: _chiTrenMay,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult r) {
        if (!r.finalResult) {
          if (mounted) setState(() => _loiTam = r.recognizedWords);
          return;
        }
        final tong = _dongHoNghe?.elapsedMilliseconds ?? -1;
        final sauDung = _mocDung == null ? -1 : tong - _mocDung!;
        _ghi('NÓI-A ${_chiTrenMay ? 'trên-máy' : 'mặc-định'} | "${r.recognizedWords}" | tổng $tong ms, sau khi dừng '
            '$sauDung ms | ${_cham(r.recognizedWords)}');
        if (mounted) setState(() => _loiTam = '');
      },
    );
  }

  // ── Giọng nói — lối B ────────────────────────────────────────────────────────────────────────────────────────────

  Future<String> _thuMuc() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/spike_c4');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  Future<void> _noiB() async {
    if (_dangGhi) {
      final p = await _ghiAm.stop();
      setState(() => _dangGhi = false);
      if (p == null) return _ghi('NÓI-B không có tệp ghi âm');
      return _gemmaAm(p);
    }
    if (!await _ghiAm.hasPermission()) return _ghi('NÓI-B thiếu quyền micro');
    final p = '${await _thuMuc()}/${_ma.text.trim()}.wav';
    await _ghiAm.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: p);
    setState(() => _dangGhi = true);
  }

  /// Dùng tệp `spike_c4/<mã>.wav` có sẵn (đẩy bằng adb, hoặc vừa ghi ở lượt trước) — để đo lại cùng một đoạn âm.
  Future<void> _noiBTuTep() async {
    final p = '${await _thuMuc()}/${_ma.text.trim()}.wav';
    if (!File(p).existsSync()) return _ghi('NÓI-B không thấy tệp ${_ma.text.trim()}.wav');
    return _gemmaAm(p);
  }

  Future<void> _gemmaAm(String duongWav) => _chay('NÓI-B', () async {
        final wav = await File(duongWav).readAsBytes();
        final rt = await _runtime();
        if (rt == null) return;
        final tep = await sl<MoHinhTaiVe>().duongTep();
        final d1 = Stopwatch()..start();
        final chep = await rt.spikeDaPhuongThuc(tep, kPromptChepLoi, wav: wav);
        final t1 = d1.elapsedMilliseconds;
        _ghi('NÓI-B chép-lời | "$chep" | $t1 ms (WAV ${wav.length} byte) | ${_cham(chep)}');
        final d2 = Stopwatch()..start();
        final yDinh = await rt.spikeDaPhuongThuc(tep, kPromptYDinh, wav: wav);
        _ghi('NÓI-B ý-định | "$yDinh" | ${d2.elapsedMilliseconds} ms');
      });

  // ── Hoá đơn ──────────────────────────────────────────────────────────────────────────────────────────────────────

  Future<void> _layAnh(ImageSource nguon) async {
    final x = await ImagePicker().pickImage(source: nguon, maxWidth: 1280, imageQuality: 85);
    if (x == null) return;
    // Chép vào thư mục spike để đo lại được cùng một ảnh.
    final dich = '${await _thuMuc()}/${_ma.text.trim()}.jpg';
    await File(x.path).copy(dich);
    setState(() => _anh = dich);
    _ghi('ẢNH đã lấy (${File(dich).lengthSync()} byte)');
  }

  /// Dùng tệp `spike_c4/<mã>.jpg` có sẵn (đẩy bằng adb + run-as trên bản debug).
  Future<void> _anhTuTep() async {
    final p = '${await _thuMuc()}/${_ma.text.trim()}.jpg';
    if (!File(p).existsSync()) return _ghi('ẢNH không thấy tệp ${_ma.text.trim()}.jpg');
    setState(() => _anh = p);
    _ghi('ẢNH dùng tệp có sẵn (${File(p).lengthSync()} byte)');
  }

  Future<void> _chupA() => _chay('CHỤP-A', () async {
        final p = _anh;
        if (p == null) return _ghi('CHỤP-A chưa có ảnh');
        final d = Stopwatch()..start();
        final tr = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final rt = await tr.processImage(InputImage.fromFilePath(p));
          final t = d.elapsedMilliseconds;
          final dong = [for (final b in rt.blocks) for (final l in b.lines) l.text].join('\n');
          final kq = docHoaDonTuChu(dong);
          _ghi('CHỤP-A | $kq | $t ms | OCR ${dong.split('\n').length} dòng, ${dong.length} ký tự');
        } finally {
          await tr.close();
        }
      });

  Future<void> _chupB() => _chay('CHỤP-B', () async {
        final p = _anh;
        if (p == null) return _ghi('CHỤP-B chưa có ảnh');
        final rt = await _runtime();
        if (rt == null) return;
        final anh = await File(p).readAsBytes();
        final d = Stopwatch()..start();
        final chu = await rt.spikeDaPhuongThuc(await sl<MoHinhTaiVe>().duongTep(), kPromptHoaDon, anh: anh);
        final t = d.elapsedMilliseconds;
        final kq = docHoaDonTuJson(chu);
        _ghi('CHỤP-B | ${kq ?? 'KHÔNG RA JSON'} | $t ms (ảnh ${anh.length} byte) | thô="${chu.replaceAll('\n', ' ')}"');
      });

  Future<SlmRuntimeThat?> _runtime() async {
    if (!await sl<MoHinhTaiVe>().daCo()) {
      _ghi('LỐI B: máy chưa có tệp mô hình');
      return null;
    }
    final rt = sl<SlmRuntime>();
    if (rt is! SlmRuntimeThat) {
      _ghi('LỐI B: runtime không phải bản thật');
      return null;
    }
    return rt;
  }

  Future<void> _chay(String ten, Future<void> Function() viec) async {
    if (_dangChay) return;
    setState(() => _dangChay = true);
    try {
      await viec();
    } catch (e) {
      _ghi('$ten LỖI $e');
    } finally {
      if (mounted) setState(() => _dangChay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ban = _dangChay || _dangNghe || _dangGhi;
    return Scaffold(
      appBar: AppBar(title: const Text('Spike C4 — đo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ma,
            decoration: const InputDecoration(labelText: 'Mã lượt (vd N01, H07) — cũng là tên tệp trong spike_c4/'),
          ),
          const SizedBox(height: 12),
          const Text('Giọng nói', style: TextStyle(fontWeight: FontWeight.w700)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lối A: chỉ chạy trên máy (onDevice)'),
            value: _chiTrenMay,
            onChanged: ban ? null : (v) => setState(() => _chiTrenMay = v),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton(
              onPressed: (_dangChay || _dangGhi) ? null : _noiA,
              child: Text(_dangNghe ? 'Dừng (A)' : 'Nói — lối A'),
            ),
            ElevatedButton(
              onPressed: (_dangChay || _dangNghe) ? null : _noiB,
              child: Text(_dangGhi ? 'Dừng ghi (B)' : 'Nói — lối B'),
            ),
            OutlinedButton(onPressed: ban ? null : _noiBTuTep, child: const Text('B từ tệp .wav')),
          ]),
          if (_loiTam.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('… $_loiTam')),
          const SizedBox(height: 16),
          const Text('Hoá đơn', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: ban ? null : () => _layAnh(ImageSource.camera), child: const Text('Chụp')),
            OutlinedButton(onPressed: ban ? null : () => _layAnh(ImageSource.gallery), child: const Text('Thư viện')),
            OutlinedButton(onPressed: ban ? null : _anhTuTep, child: const Text('Tệp .jpg')),
            ElevatedButton(onPressed: (ban || _anh == null) ? null : _chupA, child: const Text('Đọc — lối A')),
            ElevatedButton(onPressed: (ban || _anh == null) ? null : _chupB, child: const Text('Đọc — lối B')),
          ]),
          if (_anh != null) Padding(padding: const EdgeInsets.only(top: 8), child: Image.file(File(_anh!), height: 160)),
          if (_dangChay) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const Divider(height: 32),
          for (final d in _nhatKy) Padding(padding: const EdgeInsets.only(bottom: 8), child: SelectableText(d)),
        ],
      ),
    );
  }
}

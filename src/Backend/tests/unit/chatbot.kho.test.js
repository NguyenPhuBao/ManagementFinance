/**
 * Unit Test — Nội dung kho tri thức (rag/data). Kho là số liệu pháp lý người dùng tin theo, nên test khoá các con số đã đối
 * chiếu nguồn (danh sách PO duyệt 2026-11-08), phép tính ví dụ, và khả năng truy hồi. Số liệu đổi thì sửa kho và test cùng lúc.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const LexicalKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/lexical.search');

const DATA = path.join(__dirname, '../../modules/ai/features/chatbot/rag/data');
const docs = fs.readdirSync(DATA).filter((f) => f.endsWith('.json')).map((f) => JSON.parse(fs.readFileSync(path.join(DATA, f), 'utf8')));
const doc = (id) => docs.find((d) => d.id === id);
const engine = new LexicalKnowledgeSearch();
const IDS = ['thue_giam_tru_2026', 'thue_bieu_2026', 'thue_cach_tinh_luong', 'bao_hiem_bat_buoc', 'bao_hiem_tien_gui', 'quy_khan_cap', 'tra_no_phuong_phap', 'quy_tac_50_30_20',
  'luong_toi_thieu_vung_2026', 'tro_cap_that_nghiep', 'lai_suat_vay_tran', 'nhom_no_no_xau', 'lai_kep_tiet_kiem', 'phong_lua_dao_tai_chinh'];

/** Thuế TNCN từ tiền lương theo biểu 5 bậc, tính độc lập với nội dung kho. */
function thueLuong(luong, nguoiPhuThuoc = 0) {
  const taxable = luong - luong * 0.105 - 15500000 - 6200000 * nguoiPhuThuoc;
  if (taxable <= 0) return { taxable: 0, tax: 0 };
  const bac = [[10e6, 0.05], [30e6, 0.10], [60e6, 0.20], [100e6, 0.30], [Infinity, 0.35]];
  let tax = 0;
  let duoi = 0;
  for (const [tren, suat] of bac) {
    tax += Math.max(0, Math.min(taxable, tren) - duoi) * suat;
    duoi = tren;
  }
  return { taxable: Math.round(taxable), tax: Math.round(tax) };
}
const vnd = (n) => n.toLocaleString('de-DE');

describe('Kho tri thức — cấu trúc', () => {
  it('1. Đủ các tài liệu đã duyệt, không còn tài liệu cũ', () => {
    assert.deepStrictEqual(docs.map((d) => d.id).sort(), [...IDS].sort());
  });

  it('2. Mỗi tài liệu có nguồn, đường dẫn đối chiếu, ngày kiểm tra và từ khoá', () => {
    for (const d of docs) {
      assert.ok(d.title && d.source && d.content, d.id);
      assert.match(d.sourceUrl, /^https:\/\//, d.id);
      assert.match(d.checkedAt, /^\d{4}-\d{2}-\d{2}$/, d.id);
      assert.ok(Array.isArray(d.keywords) && d.keywords.length >= 3, d.id);
    }
  });

  it('3. Đoạn đủ ngắn: ba đoạn dài nhất vẫn vừa trần 2.500 ký tự của kết quả công cụ', () => {
    const lengths = engine.chunks.map((c) => c.text.length).sort((a, b) => b - a);
    assert.ok(lengths[0] <= 800, `đoạn dài nhất ${lengths[0]}`);
    assert.ok(engine.chunks.length >= 20, `chỉ có ${engine.chunks.length} đoạn`);
  });
});

describe('Kho tri thức — số liệu đã đối chiếu', () => {
  it('1. Giảm trừ gia cảnh áp dụng từ kỳ tính thuế 2026', () => {
    const t = doc('thue_giam_tru_2026').content;
    for (const s of ['15.500.000', '186.000.000', '6.200.000', '74.400.000', '2026', '110/2025/UBTVQH15']) assert.ok(t.includes(s), s);
  });

  it('2. Biểu thuế tiền lương đúng 5 bậc', () => {
    const t = doc('thue_bieu_2026').content;
    for (const s of ['Đến 10 triệu đồng/tháng: 5%', 'Trên 10 đến 30 triệu đồng/tháng: 10%', 'Trên 30 đến 60 triệu đồng/tháng: 20%', 'Trên 60 đến 100 triệu đồng/tháng: 30%', 'Trên 100 triệu đồng/tháng: 35%']) assert.ok(t.includes(s), s);
  });

  it('3. Ví dụ tính thuế khớp phép tính độc lập', () => {
    const t = doc('thue_cach_tinh_luong').content;
    for (const [luong, npt] of [[25000000, 0], [25000000, 1], [40000000, 0]]) {
      const { taxable, tax } = thueLuong(luong, npt);
      assert.ok(t.includes(vnd(taxable)), `thu nhập tính thuế ${vnd(taxable)}`);
      assert.ok(t.includes(vnd(tax)), `thuế ${vnd(tax)}`);
    }
    assert.strictEqual(thueLuong(17000000).tax, 0);
    assert.ok(t.includes('17 triệu'));
  });

  it('4. Bảo hiểm bắt buộc của người lao động: 8% + 1,5% + 1% = 10,5%', () => {
    const t = doc('bao_hiem_bat_buoc').content;
    for (const s of ['8%', '1,5%', '1%', '10,5%', '21,5%']) assert.ok(t.includes(s), s);
  });

  it('5. Hạn mức bảo hiểm tiền gửi 350 triệu từ 13/7/2026', () => {
    const t = doc('bao_hiem_tien_gui').content;
    for (const s of ['350 triệu', '13/7/2026', '125 triệu']) assert.ok(t.includes(s), s);
  });

  it('5b. Lương tối thiểu vùng 2026 và các số dẫn xuất', () => {
    const t = doc('luong_toi_thieu_vung_2026').content;
    for (const n of [5310000, 4730000, 4140000, 3700000]) assert.ok(t.includes(vnd(n)), vnd(n));
    assert.ok(t.includes(vnd(5310000 * 20)), 'trần đóng BHTN vùng I');
    const c = doc('tro_cap_that_nghiep').content;
    assert.ok(c.includes(vnd(5310000 * 5)), 'trần trợ cấp vùng I');
    assert.ok(c.includes('60%') && c.includes('ngày làm việc thứ 11'));
  });

  it('5c. Lãi kép: ví dụ khớp phép tính độc lập', () => {
    const t = doc('lai_kep_tiet_kiem').content;
    assert.ok(t.includes(vnd(Math.round(100000000 * 1.06 ** 10))), 'lãi kép');
    assert.ok(t.includes(vnd(100000000 + 100000000 * 0.06 * 10)), 'lãi đơn');
  });

  it('5d. Trần lãi suất vay và nợ xấu', () => {
    assert.ok(doc('lai_suat_vay_tran').content.includes('20%/năm'));
    assert.ok(doc('lai_suat_vay_tran').source.includes('Bộ luật Dân sự'));
    assert.ok(doc('nhom_no_no_xau').source.includes('31/2024/TT-NHNN'));
  });

  it('6. Không còn số lỗi thời hay số chưa có nguồn', () => {
    const all = docs.map((d) => d.content).join('\n');
    for (const s of ['7 BẬC', '7 bậc thuế', '132.000.000', 'Số trừ', 'DTI', '35-40%', '25-35%']) assert.ok(!all.includes(s), `còn "${s}"`);
  });

  it('7. Nguồn của từng tài liệu nêu đúng văn bản', () => {
    assert.ok(doc('thue_bieu_2026').source.includes('109/2025/QH15'));
    assert.ok(doc('bao_hiem_tien_gui').source.includes('05/2026/TT-NHNN'));
    assert.ok(doc('tra_no_phuong_phap').source.includes('CFPB'));
  });
});

describe('Cổng ép tra cứu trên kho hiện tại', () => {
  it('1. "tối thiểu", "tối đa" không bị nhầm là ngôi thứ nhất sau khi bỏ dấu', () => {
    for (const q of ['lương tối thiểu vùng 1 năm 2026 là bao nhiêu', 'tiền gửi được bảo hiểm tối đa bao nhiêu', 'luong toi thieu vung 1 nam 2026 la bao nhieu']) {
      assert.strictEqual(engine.shouldForceLookup(q), true, q);
    }
  });

  it('2. Có "tôi", "mình" (kể cả gõ không dấu) là câu về số liệu riêng: không ép', () => {
    for (const q of ['Tôi nên cắt giảm khoản nào để không vượt ngân sách?', 'mức giảm trừ gia cảnh của mình là bao nhiêu', 'muc giam tru gia canh cua toi la bao nhieu', 'tui đóng bảo hiểm xã hội bao nhiêu phần trăm']) {
      assert.strictEqual(engine.shouldForceLookup(q), false, q);
    }
  });

  it('3. Câu về số liệu không có ngôi thứ nhất: không ép', () => {
    for (const q of ['so sánh chi tiêu tháng này với tháng trước', 'hóa đơn nào sắp đến hạn', 'Những khoản ăn uống lớn nhất tháng này là gì?']) {
      assert.strictEqual(engine.shouldForceLookup(q), false, q);
    }
  });
});

describe('Kho tri thức — truy hồi', () => {
  const first = (q) => engine.search(q, 3).map((r) => r.id);

  const CASES = [
    ['Mức giảm trừ gia cảnh hiện nay là bao nhiêu?', 'thue_giam_tru_2026'],
    ['giảm trừ người phụ thuộc mỗi tháng', 'thue_giam_tru_2026'],
    ['biểu thuế thu nhập cá nhân có mấy bậc', 'thue_bieu_2026'],
    ['biểu thuế TNCN mới', 'thue_bieu_2026'],
    ['thuế suất cao nhất của thuế thu nhập cá nhân', 'thue_bieu_2026'],
    ['cách tính thuế thu nhập cá nhân từ tiền lương', 'thue_cach_tinh_luong'],
    ['lương 25 triệu đóng bao nhiêu thuế', 'thue_cach_tinh_luong'],
    ['đóng bảo hiểm xã hội bao nhiêu phần trăm', 'bao_hiem_bat_buoc'],
    ['tỷ lệ đóng BHXH', 'bao_hiem_bat_buoc'],
    ['người lao động đóng BHYT bao nhiêu', 'bao_hiem_bat_buoc'],
    ['mức đóng bảo hiểm thất nghiệp', 'bao_hiem_bat_buoc'],
    ['gửi tiết kiệm ngân hàng được bảo hiểm tối đa bao nhiêu', 'bao_hiem_tien_gui'],
    ['ngân hàng phá sản có mất tiền gửi không', 'bao_hiem_tien_gui'],
    ['quỹ khẩn cấp cần bao nhiêu tháng chi tiêu', 'quy_khan_cap'],
    ['nên để quỹ dự phòng ở đâu', 'quy_khan_cap'],
    ['phương pháp hòn tuyết lăn là gì', 'tra_no_phuong_phap'],
    ['nên trả khoản nợ lãi suất cao trước hay nợ nhỏ trước', 'tra_no_phuong_phap'],
    ['nợ thẻ tín dụng nên trả thế nào', 'tra_no_phuong_phap'],
    ['quy tắc 50/30/20 là gì', 'quy_tac_50_30_20'],
    ['phương pháp 6 chiếc lọ chia tiền', 'quy_tac_50_30_20'],
    ['lương tối thiểu vùng 1 năm 2026 là bao nhiêu', 'luong_toi_thieu_vung_2026'],
    ['mức lương tối thiểu vùng mới nhất', 'luong_toi_thieu_vung_2026'],
    ['trợ cấp thất nghiệp được bao nhiêu tiền mỗi tháng', 'tro_cap_that_nghiep'],
    ['đóng bảo hiểm thất nghiệp bao lâu thì hưởng mấy tháng trợ cấp', 'tro_cap_that_nghiep'],
    ['cho vay lãi suất tối đa bao nhiêu phần trăm một năm', 'lai_suat_vay_tran'],
    ['vay tín dụng đen lãi cao có phải trả không', 'lai_suat_vay_tran'],
    ['nợ xấu là gì', 'nhom_no_no_xau'],
    ['nợ quá hạn bao nhiêu ngày thì thành nợ xấu', 'nhom_no_no_xau'],
    ['lãi kép là gì', 'lai_kep_tiet_kiem'],
    ['gửi tiết kiệm lãi nhập gốc khác lãi đơn thế nào', 'lai_kep_tiet_kiem'],
    ['bị lừa đảo yêu cầu mã OTP thì làm gì', 'phong_lua_dao_tai_chinh'],
    ['vay tiền qua app đòi đóng phí trước có phải lừa đảo không', 'phong_lua_dao_tai_chinh'],
  ];

  for (const [q, id] of CASES) {
    it(`Tìm thấy ${id}: ${q}`, () => {
      assert.ok(first(q).includes(id), `kết quả: ${first(q).join(', ') || '(rỗng)'}`);
    });
  }

  for (const q of ['Hôm nay thời tiết Hà Nội thế nào?', 'viết cho tôi một bài thơ về mùa thu', 'đội bóng nào vô địch World Cup 2018', 'cách nấu phở bò ngon', 'dịch câu này sang tiếng Anh giúp tôi', 'viết hàm sắp xếp mảng bằng python', 'Ai là người đầu tiên đặt chân lên mặt trăng?']) {
    it(`Lạc đề trả về rỗng: ${q}`, () => {
      assert.deepStrictEqual(first(q), []);
    });
  }
});

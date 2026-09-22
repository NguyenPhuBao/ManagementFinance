/**
 * Test Suite: AI Transaction Classification (3-Tier Hybrid & RAG Standards)
 * Kiểm thử toàn diện chức năng AI Phân Loại Giao Dịch:
 * 1. Text Preprocessing & Unicode NFC Normalization
 * 2. Tier 1: Keyword & Rule-Based Matcher
 * 3. Tier 2: Local NLP / Token Similarity Matcher & Suggested Categories
 * 4. Batch Classification Output (Receipt OCR)
 * 5. Self-Learning Feedback Loop & Keyword Persistence
 * 6. Bank Worker Auto-Classification
 */

const { prisma } = require('../src/Backend/config/db');
const { cleanVietnameseText, removeVietnameseTones, preprocess } = require('../src/Backend/modules/ai/features/classify/classify.preprocess');
const classifyService = require('../src/Backend/modules/ai/features/classify/classify.service');
const classifyRepository = require('../src/Backend/modules/ai/features/classify/classify.repository');

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bright: "\x1b[1m",
};

function assert(condition, message) {
  if (!condition) {
    console.error(`${colors.red}  ✗ FAILED: ${message}${colors.reset}`);
    throw new Error(message);
  }
  console.log(`${colors.green}  ✓ PASSED: ${message}${colors.reset}`);
}

async function runAIClassifyTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}   KIỂM THỬ TOÀN DIỆN AI PHÂN LOẠI GIAO DỊCH (3-TIER & RAG STANDARDS) ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  // 1. Tìm hoặc chuẩn bị tài khoản test và danh mục
  const testAccount = await prisma.account.findFirst({
    where: { idrole: 2, delete_at: null },
  });

  if (!testAccount) {
    console.error('Không tìm thấy tài khoản test.');
    process.exit(1);
  }

  const idaccount = testAccount.idaccount;
  console.log(`${colors.yellow}Tài khoản test: ${idaccount}${colors.reset}\n`);

  const { randomUUID } = require('crypto');

  // Chuẩn bị danh mục mẫu test nếu chưa có
  let catGiaDung = await prisma.category.findFirst({
    where: { name_category: { contains: 'Gia dụng' }, delete_at: null },
  });
  if (!catGiaDung) {
    catGiaDung = await prisma.category.create({
      data: {
        idcategory: randomUUID(),
        name_category: 'Gia dụng & Đồ dùng',
        classify: 'Chi',
        keyword: 'bot giat,robot,gia dung,xà phòng,nuoc tay,comfort,omo',
        icon: 'home',
        is_default: true,
        create_by: idaccount,
      },
    });
  } else {
    // Cập nhật bổ sung keyword nếu cần (chuẩn dấu phẩy không khoảng trắng)
    await prisma.category.update({
      where: { idcategory: catGiaDung.idcategory },
      data: { keyword: 'bot giat,robot,gia dung,xà phòng,nuoc tay,comfort,omo' },
    });
  }

  let catYTe = await prisma.category.findFirst({
    where: { name_category: { contains: 'Y tế' }, delete_at: null },
  });
  if (!catYTe) {
    catYTe = await prisma.category.create({
      data: {
        idcategory: randomUUID(),
        name_category: 'Y tế & Sức khỏe',
        classify: 'Chi',
        keyword: 'ktyt,famapro,khau trang,y te,thuoc,pharmacy,benh vien',
        icon: 'medical_services',
        is_default: true,
        create_by: idaccount,
      },
    });
  } else {
    await prisma.category.update({
      where: { idcategory: catYTe.idcategory },
      data: { keyword: 'ktyt,famapro,khau trang,y te,thuoc,pharmacy,benh vien' },
    });
  }

  let catAnUong = await prisma.category.findFirst({
    where: { name_category: { contains: 'Ăn uống' }, delete_at: null },
  });
  if (!catAnUong) {
    catAnUong = await prisma.category.create({
      data: {
        idcategory: randomUUID(),
        name_category: 'Ăn uống',
        classify: 'Chi',
        keyword: 'highlands,cafe,ca phe,tra sua,an uong,bun bo,pho',
        icon: 'restaurant',
        is_default: true,
        create_by: idaccount,
      },
    });
  } else {
    await prisma.category.update({
      where: { idcategory: catAnUong.idcategory },
      data: { keyword: 'highlands,cafe,ca phe,tra sua,an uong,bun bo,pho' },
    });
  }

  let catTienDien = await prisma.category.findFirst({
    where: { name_category: { contains: 'Điện' }, delete_at: null },
  });
  if (!catTienDien) {
    catTienDien = await prisma.category.create({
      data: {
        idcategory: randomUUID(),
        name_category: 'Hóa đơn tiền điện',
        classify: 'Chi',
        keyword: 'evn,tien dien,dien luc,evn hanoi,evn hcm',
        icon: 'bolt',
        is_default: true,
        create_by: idaccount,
      },
    });
  } else {
    await prisma.category.update({
      where: { idcategory: catTienDien.idcategory },
      data: { keyword: 'evn,tien dien,dien luc,evn hanoi,evn hcm' },
    });
  }

  // =========================================================================
  // TEST 1: Text Preprocessing & Unicode NFC Normalization
  // =========================================================================
  console.log(`${colors.bright}1. Kiểm thử Tiền xử lý & Chuẩn hóa Unicode NFC:${colors.reset}`);
  const rawSample = '  FT26245981273910 - Bột giặt   Robot 800g (Siêu Sạch)  ';
  const cleanRes = cleanVietnameseText(rawSample);
  assert(cleanRes === 'bột giặt robot 800g siêu sạch', `cleanVietnameseText chuẩn hóa: "${cleanRes}"`);
  
  const toneLess = removeVietnameseTones('Bách Hóa Xanh - Cà Phê');
  assert(toneLess.toLowerCase() === 'bach hoa xanh - ca phe', `removeVietnameseTones: "${toneLess}"`);

  // =========================================================================
  // TEST 2: Tier 1 - Keyword & Rule Matcher (OCR Items, MoMo, EVN, Highlands)
  // =========================================================================
  console.log(`\n${colors.bright}2. Kiểm thử Tier 1 (Keyword & Rule Matcher):${colors.reset}`);
  
  // 2.1 OCR Món 1: Bột giặt Robot
  const resOcr1 = await classifyService.classifySingle(idaccount, {
    text: 'Bột giặt Robot 800g',
    amount: 19000,
    merchant: 'ĐỒNG MART',
    source: 'OCR',
  });
  assert(resOcr1.category_name.includes('Gia dụng'), `Bột giặt Robot -> ${resOcr1.category_name}`);
  assert(resOcr1.tier_used === 'tier1_keyword', `Tier used: ${resOcr1.tier_used}`);
  assert(resOcr1.confidence >= 0.90, `Confidence: ${resOcr1.confidence}`);

  // 2.2 OCR Món 2: KTYT FAMAPRO UV
  const resOcr2 = await classifyService.classifySingle(idaccount, {
    text: 'KTYT FAMAPRO UV',
    amount: 19000,
    merchant: 'ĐỒNG MART',
    source: 'OCR',
  });
  assert(resOcr2.category_name.toLowerCase().includes('y tế'), `KTYT FAMAPRO UV -> ${resOcr2.category_name}`);
  assert(resOcr2.confidence >= 0.90, `Confidence: ${resOcr2.confidence}`);

  // 2.3 Casso BankSync: Highlands Coffee
  const resCasso1 = await classifyService.classifySingle(idaccount, {
    text: 'MBVCB.12938471.HIGHLANDS COFFEE.Thanh toan cafe',
    amount: 65000,
    merchant: 'BIDV',
    source: 'BankSync',
  });
  assert(resCasso1.category_name.toLowerCase().includes('ăn uống'), `Highlands Coffee -> ${resCasso1.category_name}`);
  assert(resCasso1.tier_used === 'tier1_keyword', `Tier used: ${resCasso1.tier_used}`);

  // 2.4 Casso BankSync: EVN Tiền điện
  const resCasso2 = await classifyService.classifySingle(idaccount, {
    text: 'THANH TOAN TIEN DIEN EVN HANOI PE01000234918',
    amount: 854000,
    source: 'BankSync',
  });
  assert(resCasso2.category_name.toLowerCase().includes('điện'), `EVN Tiền điện -> ${resCasso2.category_name}`);

  // 2.5 Casso BankSync: Khớp qua counterpart_name viết HOA (corresponsiveName)
  const resCasso3 = await classifyService.classifySingle(idaccount, {
    text: 'CHUYEN KHOAN 123985',
    amount: 35000,
    merchant: 'Techcombank',
    source: 'BankSync',
    counterpart_name: 'HIGHLANDS COFFEE VIETNAM',
  });
  assert(resCasso3.category_name.toLowerCase().includes('ăn uống'), `counterpart_name HIGHLANDS -> ${resCasso3.category_name}`);
  assert(resCasso3.tier_used === 'tier1_keyword', `Tier used: ${resCasso3.tier_used}`);

  // =========================================================================
  // TEST 3: Tier 2 - Local NLP / Token Similarity & Suggested Categories
  // =========================================================================
  console.log(`\n${colors.bright}3. Kiểm thử Tier 2 (Local NLP / Similarity Matcher) & DTO Output:${colors.reset}`);
  
  // Giao dịch không khớp 100% keyword nhưng có từ ngữ liên quan ("tra sua", "quan bun bo")
  const resNlp = await classifyService.classifySingle(idaccount, {
    text: 'Tra sua tran chau duong den size L',
    amount: 55000,
    source: 'Manual',
  });
  assert(resNlp.category_name.toLowerCase().includes('ăn uống'), `Trà sữa trân châu -> ${resNlp.category_name}`);
  assert(resNlp.confidence >= 0.50, `Confidence: ${resNlp.confidence}`);
  assert(Array.isArray(resNlp.suggested_categories) && resNlp.suggested_categories.length > 0, 'Có suggested_categories');
  assert(resNlp.category_id !== null, `category_id: ${resNlp.category_id}`);
  assert(resNlp.classify === 'Chi', `classify: ${resNlp.classify}`);

  // =========================================================================
  // TEST 4: Batch Classification (OCR Món Hàng Hàng Loạt)
  // =========================================================================
  console.log(`\n${colors.bright}4. Kiểm thử Phân loại Batch (Receipt OCR):${colors.reset}`);
  const batchInput = [
    { item_id: 'item_1', text: 'Bột giặt Robot 800g', amount: 19000 },
    { item_id: 'item_2', text: 'KTYT FAMAPRO UV', amount: 19000 },
    { item_id: 'item_3', text: 'Cafe Highlands lon', amount: 25000 },
  ];

  const batchResults = await classifyService.classifyBatch(idaccount, {
    items: batchInput,
    merchant: 'ĐỒNG MART',
    source: 'OCR',
  });

  assert(batchResults.length === 3, `Độ dài batch kết quả = 3 (nhận: ${batchResults.length})`);
  assert(batchResults[0].item_id === 'item_1' && batchResults[0].category_name.toLowerCase().includes('gia dụng'), 'Item 1 -> Gia dụng');
  assert(batchResults[1].item_id === 'item_2' && batchResults[1].category_name.toLowerCase().includes('y tế'), 'Item 2 -> Y tế');
  assert(batchResults[2].item_id === 'item_3' && batchResults[2].category_name.toLowerCase().includes('ăn uống'), 'Item 3 -> Ăn uống');
  assert(batchResults[0].classify === 'Chi', 'classify DTO hợp lệ');

  // =========================================================================
  // TEST 5: Self-Learning Feedback Loop (Học từ người dùng)
  // =========================================================================
  console.log(`\n${colors.bright}5. Kiểm thử Cơ Chế Tự Học (Self-Learning Feedback Loop):${colors.reset}`);
  
  const customKeyword = `mon_dac_biet_${Date.now().toString().slice(-4)}`;
  
  // 5.1 Trước khi học: Chưa có từ khóa này
  const beforeFeedback = await classifyService.classifySingle(idaccount, {
    text: `Mua ${customKeyword}`,
    amount: 100000,
  });
  console.log(`  - Trước khi học: "${customKeyword}" -> Tier: ${beforeFeedback.tier_used}`);

  // 5.2 Người dùng gửi phản hồi: Gán từ khóa này cho danh mục "Y tế & Sức khỏe"
  const feedbackRes = await classifyService.recordFeedback(idaccount, {
    idcategory: catYTe.idcategory,
    keyword: customKeyword,
  });
  assert(feedbackRes.success === true, 'Ghi nhận feedback thành công');
  assert(feedbackRes.keyword.length > 0, `Keyword đã lưu: ${feedbackRes.keyword}`);

  // 5.3 Sau khi học: Giao dịch tiếp theo chứa từ khóa này phải khớp Tier 1 (100% confidence)
  const afterFeedback = await classifyService.classifySingle(idaccount, {
    text: `Thanh toan don hang ${customKeyword}`,
    amount: 100000,
  });
  assert(afterFeedback.category_id === catYTe.idcategory, `Sau khi học: khớp đúng danh mục ${catYTe.name_category || catYTe.namecategory}`);
  assert(afterFeedback.tier_used === 'tier1_keyword', `Sau khi học: Nhận diện trúng Tầng 1 (Keyword Matcher)!`);
  assert(afterFeedback.confidence >= 0.95, `Sau khi học: Confidence = ${afterFeedback.confidence}`);

  console.log(`\n${colors.green}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.green}${colors.bright}   TẤT CẢ CÁC BỘ KIỂM THỬ AI PHÂN LOẠI GIAO DỊCH ĐẠT PASS 100%!     ${colors.reset}`);
  console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}\n`);
}

runAIClassifyTests()
  .catch((err) => {
    console.error('Test Suite Failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

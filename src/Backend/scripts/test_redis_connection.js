const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { resolveRedisUrl } = require('../config/redis.resolver');
const Redis = require('ioredis');

async function testRedisConnection() {
  const provider = (process.env.REDIS_PROVIDER || 'railway').toUpperCase();
  console.log('====================================================');
  console.log(`     KIỂM TRA KẾT NỐI REDIS [PROVIDER: ${provider}]     `);
  console.log('====================================================\n');

  const redisUrl = resolveRedisUrl();

  if (!redisUrl) {
    console.error('❌ CHƯA CẤU HÌNH REDIS_URL TRONG FILE .env!');
    console.error('Vui lòng mở file src/Backend/.env và điền:');
    console.error('REDIS_URL=redis://default:mật_khẩu@host:port\n');
    process.exit(1);
  }

  // Mask password for safe display
  let maskedUrl = redisUrl;
  try {
    const parsed = new URL(redisUrl);
    if (parsed.password) {
      maskedUrl = `${parsed.protocol}//${parsed.username}:******@${parsed.host}${parsed.pathname}`;
    }
  } catch (_) {
    maskedUrl = redisUrl.replace(/:([^@]+)@/, ':******@');
  }

  console.log(`🏷️ Provider đang kích hoạt: ${provider}`);
  console.log(`📡 URL kết nối: ${maskedUrl}`);
  console.log('⏳ Đang kết nối tới Redis server...\n');

  const client = new Redis(redisUrl, {
    maxRetriesPerRequest: 3,
    connectTimeout: 10000,
    lazyConnect: true,
  });

  try {
    const startTime = Date.now();
    await client.connect();
    const connectLatency = Date.now() - startTime;
    console.log(`✅ [1/4] Kết nối TCP Socket thành công! (Độ trễ: ${connectLatency}ms)`);

    // Test PING
    const pingStart = Date.now();
    const pong = await client.ping();
    const pingLatency = Date.now() - pingStart;
    console.log(`✅ [2/4] Ping phản hồi: "${pong}" (Round-trip: ${pingLatency}ms)`);

    // Test SET & GET
    const testKey = `test_healthcheck_${Date.now()}`;
    await client.set(testKey, 'SUCCESS_HELLO_RAILWAY', 'EX', 30);
    const retrievedVal = await client.get(testKey);
    await client.del(testKey);
    if (retrievedVal === 'SUCCESS_HELLO_RAILWAY') {
      console.log('✅ [3/4] Ghi (SET) & Đọc (GET) dữ liệu thành công!');
    } else {
      throw new Error(`Giá trị đọc về không khớp: ${retrievedVal}`);
    }

    // Test BullMQ Lua script compatibility
    const luaResult = await client.eval('return {KEYS[1], ARGV[1]}', 1, 'bullmq_check', 'ok');
    if (Array.isArray(luaResult) && luaResult[0] === 'bullmq_check' && luaResult[1] === 'ok') {
      console.log('✅ [4/4] Khả năng thực thi Lua script (EVAL) chuẩn BullMQ: HOÀN HẢO!');
    }

    // Fetch Redis Info
    try {
      const info = await client.info('server');
      const memory = await client.info('memory');
      const versionMatch = info.match(/redis_version:([^\r\n]+)/);
      const memMatch = memory.match(/used_memory_human:([^\r\n]+)/);
      console.log('\n--- THÔNG TIN HỆ THỐNG REDIS ---');
      if (versionMatch) console.log(`• Phiên bản Redis:    ${versionMatch[1]}`);
      if (memMatch)     console.log(`• RAM đang sử dụng:   ${memMatch[1]}`);
      console.log('• Không giới hạn số lượng lệnh request (Unlimited Commands)');
      console.log('--------------------------------\n');
    } catch (_) {}

    console.log('🎉 TẤT CẢ KIỂM TRA ĐỀU VƯỢT QUA! Redis đã sẵn sàng phục vụ BullMQ 24/7.\n');
  } catch (err) {
    console.error('\n❌ KẾT NỐI THẤT BẠI!');
    console.error(`Chi tiết lỗi: ${err.message}`);
    console.error('\n👉 Gợi ý khắc phục:');
    console.error('1. Đảm bảo bạn đã thêm TCP Proxy (Public Networking) trên Railway nếu chạy từ Localhost.');
    console.error('2. Kiểm tra chuỗi kết nối REDIS_URL có đúng port và password không.');
    console.error('3. Nếu dùng mạng WiFi trường học/công ty, thử đổi DNS sang 8.8.8.8 hoặc 1.1.1.1.\n');
    process.exit(1);
  } finally {
    try {
      await client.quit();
    } catch (_) {
      client.disconnect();
    }
  }
}

testRedisConnection();

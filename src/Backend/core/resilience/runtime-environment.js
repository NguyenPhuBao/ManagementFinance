const os = require('os');
const fs = require('fs');

/**
 * Đọc nội dung file an toàn không ném exception
 * @param {string} filePath 
 * @returns {string|null}
 */
function safeReadFile(filePath) {
  try {
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, 'utf8').trim();
    }
  } catch (_) {}
  return null;
}

/**
 * Nhận diện môi trường thực thi (Cloud, Local Workstation, Bare-metal Host)
 * @param {object} [options]
 * @returns {{ mode: 'cloud'|'local'|'host', provider: string, isContainer: boolean }}
 */
function detectRuntimeEnvironment(options = {}) {
  const env = options.env || process.env;
  const isLinux = options.isLinux !== undefined ? options.isLinux : process.platform === 'linux';

  // 1. Kiểm tra cấu hình tường minh qua SERVER_RUNTIME
  const explicitRuntime = (env.SERVER_RUNTIME || '').toLowerCase();
  if (explicitRuntime === 'cloud') {
    return {
      mode: 'cloud',
      provider: env.CLOUD_PROVIDER || 'Cloud Container',
      isContainer: true,
    };
  }
  if (explicitRuntime === 'host') {
    return {
      mode: 'host',
      provider: 'Bare-metal Host / Dedicated Server',
      isContainer: false,
    };
  }
  if (explicitRuntime === 'local') {
    return {
      mode: 'local',
      provider: 'Local Workstation',
      isContainer: false,
    };
  }

  // 2. Kiểm tra các biến môi trường đặc trưng của nhà cung cấp Cloud
  if (env.RENDER === 'true') {
    return { mode: 'cloud', provider: 'Render Cloud', isContainer: true };
  }
  if (env.RAILWAY_ENVIRONMENT || env.RAILWAY_STATIC_URL) {
    return { mode: 'cloud', provider: 'Railway Cloud', isContainer: true };
  }
  if (env.FLY_APP_NAME || env.FLY_REGION) {
    return { mode: 'cloud', provider: 'Fly.io Cloud', isContainer: true };
  }
  if (env.VERCEL) {
    return { mode: 'cloud', provider: 'Vercel Serverless', isContainer: true };
  }
  if (env.AWS_EXECUTION_ENV || env.ECS_CONTAINER_METADATA_URI) {
    return { mode: 'cloud', provider: 'AWS Cloud Container', isContainer: true };
  }
  if (env.KUBERNETES_SERVICE_HOST) {
    return { mode: 'cloud', provider: 'Kubernetes Pod', isContainer: true };
  }

  // 3. Kiểm tra file hệ thống cgroups / docker container
  if (isLinux) {
    const isDocker = fs.existsSync('/.dockerenv');
    const cgroupContent = safeReadFile('/proc/1/cgroup') || '';
    if (isDocker || cgroupContent.includes('docker') || cgroupContent.includes('kubepods')) {
      return { mode: 'cloud', provider: 'Docker Container', isContainer: true };
    }
  }

  // 4. Mặc định trên môi trường dev cục bộ hoặc host vật lý
  const isDev = (env.NODE_ENV || 'development') === 'development';
  return {
    mode: isDev ? 'local' : 'host',
    provider: isDev ? 'Local Development' : 'Host Server',
    isContainer: false,
  };
}

/**
 * Đọc thông số quota tài nguyên phần cứng (CPU & RAM) theo môi trường thực thi
 * @param {object} [options]
 * @returns {{ mode: string, provider: string, isContainer: boolean, cpuCores: number, ramTotalMb: number, source: string }}
 */
function getRuntimeHardwareSpecs(options = {}) {
  const env = options.env || process.env;
  const envInfo = detectRuntimeEnvironment(options);
  const isLinux = options.isLinux !== undefined ? options.isLinux : process.platform === 'linux';

  // 1. Kiểm tra cấu hình ghi đè tường minh từ biến môi trường
  const envCores = parseFloat(env.CLOUD_CPU_CORES);
  const envRam = parseInt(env.CLOUD_RAM_LIMIT_MB, 10);
  if (!isNaN(envCores) && !isNaN(envRam) && envCores > 0 && envRam > 0) {
    return {
      ...envInfo,
      cpuCores: envCores,
      ramTotalMb: envRam,
      source: 'env_config',
    };
  }

  // 2. Nếu là môi trường Cloud / Container trên Linux: đọc từ cgroups
  if (envInfo.isContainer && isLinux) {
    let cpuCores = null;
    let ramTotalMb = null;
    let source = null;

    // cgroup v2
    const cgroup2CpuMax = safeReadFile('/sys/fs/cgroup/cpu.max');
    if (cgroup2CpuMax) {
      const parts = cgroup2CpuMax.split(/\s+/);
      if (parts[0] !== 'max' && parts.length >= 2) {
        const quota = parseInt(parts[0], 10);
        const period = parseInt(parts[1], 10);
        if (period > 0 && quota > 0) {
          cpuCores = parseFloat((quota / period).toFixed(2));
          source = 'cgroup_v2';
        }
      }
    }

    const cgroup2MemMax = safeReadFile('/sys/fs/cgroup/memory.max');
    if (cgroup2MemMax && cgroup2MemMax !== 'max') {
      const bytes = parseInt(cgroup2MemMax, 10);
      if (!isNaN(bytes) && bytes > 0 && bytes < 9000000000000000) {
        ramTotalMb = Math.round(bytes / 1024 / 1024);
        source = 'cgroup_v2';
      }
    }

    // cgroup v1 fallback
    if (cpuCores === null) {
      const quotaStr = safeReadFile('/sys/fs/cgroup/cpu/cpu.cfs_quota_us');
      const periodStr = safeReadFile('/sys/fs/cgroup/cpu/cpu.cfs_period_us');
      if (quotaStr && periodStr) {
        const quota = parseInt(quotaStr, 10);
        const period = parseInt(periodStr, 10);
        if (quota > 0 && period > 0) {
          cpuCores = parseFloat((quota / period).toFixed(2));
          source = 'cgroup_v1';
        }
      }
    }

    if (ramTotalMb === null) {
      const limitStr = safeReadFile('/sys/fs/cgroup/memory/memory.limit_in_bytes');
      if (limitStr) {
        const bytes = parseInt(limitStr, 10);
        if (!isNaN(bytes) && bytes > 0 && bytes < 9000000000000000) {
          ramTotalMb = Math.round(bytes / 1024 / 1024);
          source = 'cgroup_v1';
        }
      }
    }

    if (cpuCores !== null || ramTotalMb !== null) {
      const defaultHostCores = os.cpus().length || 1;
      const defaultHostRam = Math.round(os.totalmem() / 1024 / 1024);
      return {
        ...envInfo,
        cpuCores: cpuCores !== null ? cpuCores : defaultHostCores,
        ramTotalMb: ramTotalMb !== null ? ramTotalMb : defaultHostRam,
        source: source || 'cgroup_detected',
      };
    }
  }

  // 3. Fallback: Host vật lý hoặc máy cục bộ
  const hostCpus = os.cpus() || [];
  const hostTotalRamMb = Math.round(os.totalmem() / 1024 / 1024);

  return {
    ...envInfo,
    cpuCores: hostCpus.length || 1,
    ramTotalMb: hostTotalRamMb,
    source: 'os_host',
  };
}

module.exports = {
  detectRuntimeEnvironment,
  getRuntimeHardwareSpecs,
};

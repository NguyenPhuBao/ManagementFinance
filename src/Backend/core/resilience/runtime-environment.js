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
  const readFile = options.fileReader || safeReadFile;
  const exists = options.fileExists || fs.existsSync;

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

  // 3. Tự động kiểm tra file hệ thống container (Docker, Podman, cgroups) trên Linux
  if (isLinux) {
    const isDocker = exists('/.dockerenv');
    const isPodman = exists('/run/.containerenv');
    const cgroupContent = readFile('/proc/1/cgroup') || readFile('/proc/self/cgroup') || '';
    if (
      isDocker ||
      isPodman ||
      cgroupContent.includes('docker') ||
      cgroupContent.includes('kubepods') ||
      cgroupContent.includes('containerd') ||
      cgroupContent.includes('libpod')
    ) {
      return { mode: 'cloud', provider: 'Docker Container', isContainer: true };
    }

    // Kiểm tra nếu có giới hạn cgroup v2 (cpu.max khác max hoặc memory.max có hạn ngạch)
    const cgroup2Cpu = readFile('/sys/fs/cgroup/cpu.max');
    if (cgroup2Cpu && !cgroup2Cpu.startsWith('max')) {
      return { mode: 'cloud', provider: 'Container (cgroup v2)', isContainer: true };
    }
    const cgroup1Quota = readFile('/sys/fs/cgroup/cpu/cpu.cfs_quota_us') || readFile('/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us');
    if (cgroup1Quota && parseInt(cgroup1Quota, 10) > 0) {
      return { mode: 'cloud', provider: 'Container (cgroup v1)', isContainer: true };
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
 * Tự động đọc cgroups v1 / v2 từ nhân Linux mà không phụ thuộc vào cấu hình tĩnh
 * @param {object} [options]
 * @returns {{ mode: string, provider: string, isContainer: boolean, cpuCores: number, ramTotalMb: number, source: string }}
 */
function getRuntimeHardwareSpecs(options = {}) {
  const env = options.env || process.env;
  const envInfo = detectRuntimeEnvironment(options);
  const isLinux = options.isLinux !== undefined ? options.isLinux : process.platform === 'linux';
  const readFile = options.fileReader || safeReadFile;

  // 1. Kiểm tra cấu hình ghi đè tường minh từ biến môi trường (nếu người dùng cố tình cấu hình)
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

  // 2. Nếu là môi trường Container / Cloud trên Linux: đọc từ cgroups
  if (envInfo.isContainer && isLinux) {
    let cpuCores = null;
    let ramTotalMb = null;
    let source = null;

    // Tìm subpath từ /proc/self/cgroup nếu có cấu trúc lồng nhau (nested cgroup)
    const selfCgroup = readFile('/proc/self/cgroup') || '';
    let cgroupSubpath = '';
    const lines = selfCgroup.split('\n');
    for (const line of lines) {
      const parts = line.split(':');
      if (parts.length >= 3 && parts[2] && parts[2] !== '/') {
        cgroupSubpath = parts[2].trim();
        break;
      }
    }

    // Helper kiểm tra file ở cả root cgroup và subpath
    const readCgroup = (subDir, fileName) => {
      if (subDir) {
        const p1 = `/sys/fs/cgroup/${subDir}/${fileName}`;
        const v1 = readFile(p1);
        if (v1) return v1;
      }
      if (cgroupSubpath) {
        const pSub = `/sys/fs/cgroup${cgroupSubpath}/${fileName}`;
        const vSub = readFile(pSub);
        if (vSub) return vSub;
      }
      return readFile(`/sys/fs/cgroup/${fileName}`);
    };

    // A. Thử cgroup v2
    const cgroup2CpuMax = readCgroup('', 'cpu.max');
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

    // Nếu cpu.max không giới hạn CFS, thử cpu.weight (proportional weight)
    if (cpuCores === null) {
      const cgroup2Weight = readCgroup('', 'cpu.weight');
      if (cgroup2Weight) {
        const weight = parseInt(cgroup2Weight, 10);
        if (weight > 0 && weight < 100) {
          cpuCores = parseFloat((weight / 100).toFixed(2));
          source = 'cgroup_v2_weight';
        }
      }
    }

    const cgroup2MemMax = readCgroup('', 'memory.max');
    if (cgroup2MemMax && cgroup2MemMax !== 'max') {
      const bytes = parseInt(cgroup2MemMax, 10);
      if (!isNaN(bytes) && bytes > 0 && bytes < 9000000000000000) {
        ramTotalMb = Math.round(bytes / 1024 / 1024);
        source = source || 'cgroup_v2';
      }
    }

    // B. Thử cgroup v1 fallback
    if (cpuCores === null) {
      const quotaStr =
        readCgroup('cpu', 'cpu.cfs_quota_us') ||
        readCgroup('cpu,cpuacct', 'cpu.cfs_quota_us');
      const periodStr =
        readCgroup('cpu', 'cpu.cfs_period_us') ||
        readCgroup('cpu,cpuacct', 'cpu.cfs_period_us');

      if (quotaStr && periodStr) {
        const quota = parseInt(quotaStr, 10);
        const period = parseInt(periodStr, 10);
        if (quota > 0 && period > 0) {
          cpuCores = parseFloat((quota / period).toFixed(2));
          source = 'cgroup_v1';
        }
      }

      // Nếu CFS quota là -1 (unconstrained), kiểm tra cpu.shares
      if (cpuCores === null) {
        const sharesStr =
          readCgroup('cpu', 'cpu.shares') ||
          readCgroup('cpu,cpuacct', 'cpu.shares');
        if (sharesStr) {
          const shares = parseInt(sharesStr, 10);
          if (shares > 0 && shares < 1024) {
            // Chuẩn nhân Linux: 1024 shares = 1 core (ví dụ: 154 shares ~ 0.15 core)
            cpuCores = parseFloat((shares / 1024).toFixed(2));
            source = 'cgroup_v1_shares';
          }
        }
      }
    }

    if (ramTotalMb === null) {
      const limitStr =
        readCgroup('memory', 'memory.limit_in_bytes') ||
        readCgroup('memory,memsw', 'memory.limit_in_bytes');
      if (limitStr) {
        const bytes = parseInt(limitStr, 10);
        if (!isNaN(bytes) && bytes > 0 && bytes < 9000000000000000) {
          ramTotalMb = Math.round(bytes / 1024 / 1024);
          source = source || 'cgroup_v1';
        }
      }
    }

    // C. Fallback tự động thông minh theo container Cloud
    // Ví dụ trên Render Free Container: RAM limit luôn là 512 MB và CPU tiêu chuẩn là 0.15 vCPU
    if (env.RENDER === 'true') {
      if (ramTotalMb === null) ramTotalMb = 512;
      if (cpuCores === null) cpuCores = 0.15;
      source = source || 'render_container_quota';
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

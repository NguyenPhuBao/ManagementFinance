/**
 * Test: Runtime Environment Detection & Hardware Specs (Tier 2: System Impact)
 * Kiểm tra khả năng tự động phân biệt môi trường Cloud Container (cgroups/env) vs Host/Local
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const os = require('os');
const {
  detectRuntimeEnvironment,
  getRuntimeHardwareSpecs,
} = require('../../core/resilience/runtime-environment');

describe('Runtime Environment & Hardware Monitor Detection', () => {
  it('detectRuntimeEnvironment should return local/host by default when not in cloud', () => {
    const envInfo = detectRuntimeEnvironment({
      env: {},
      isLinux: false,
    });

    assert.ok(['local', 'host'].includes(envInfo.mode));
    assert.strictEqual(typeof envInfo.provider, 'string');
    assert.strictEqual(typeof envInfo.isContainer, 'boolean');
  });

  it('detectRuntimeEnvironment should detect Cloud when SERVER_RUNTIME=cloud or provider env is set', () => {
    const renderEnv = detectRuntimeEnvironment({
      env: { RENDER: 'true' },
      isLinux: true,
    });
    assert.strictEqual(renderEnv.mode, 'cloud');
    assert.strictEqual(renderEnv.provider, 'Render Cloud');
    assert.strictEqual(renderEnv.isContainer, true);

    const railwayEnv = detectRuntimeEnvironment({
      env: { RAILWAY_ENVIRONMENT: 'production' },
      isLinux: true,
    });
    assert.strictEqual(railwayEnv.mode, 'cloud');
    assert.strictEqual(railwayEnv.provider, 'Railway Cloud');
    assert.strictEqual(railwayEnv.isContainer, true);

    const explicitCloud = detectRuntimeEnvironment({
      env: { SERVER_RUNTIME: 'cloud', CLOUD_CPU_CORES: '2', CLOUD_RAM_LIMIT_MB: '1024' },
      isLinux: true,
    });
    assert.strictEqual(explicitCloud.mode, 'cloud');
    assert.strictEqual(explicitCloud.isContainer, true);
  });

  it('getRuntimeHardwareSpecs should respect CLOUD_CPU_CORES and CLOUD_RAM_LIMIT_MB when in cloud mode', () => {
    const specs = getRuntimeHardwareSpecs({
      env: {
        SERVER_RUNTIME: 'cloud',
        CLOUD_CPU_CORES: '1',
        CLOUD_RAM_LIMIT_MB: '512',
      },
      isLinux: true,
    });

    assert.strictEqual(specs.mode, 'cloud');
    assert.strictEqual(specs.cpuCores, 1);
    assert.strictEqual(specs.ramTotalMb, 512);
    assert.strictEqual(specs.source, 'env_config');
  });

  it('getRuntimeHardwareSpecs should fall back to os host specs when in local/bare-metal mode', () => {
    const specs = getRuntimeHardwareSpecs({
      env: { SERVER_RUNTIME: 'host' },
      isLinux: false,
    });

    assert.strictEqual(specs.mode, 'host');
    assert.strictEqual(specs.cpuCores, os.cpus().length);
    assert.strictEqual(specs.ramTotalMb, Math.round(os.totalmem() / 1024 / 1024));
  });
});

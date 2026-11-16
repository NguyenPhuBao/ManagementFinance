const BROWSERS = [
  [/Edg(e|A|iOS)?\//, 'Edge'],
  [/OPR\/|Opera/, 'Opera'],
  [/SamsungBrowser\//, 'Samsung Internet'],
  [/Firefox\/|FxiOS\//, 'Firefox'],
  [/Chrome\/|CriOS\//, 'Chrome'],
  [/Safari\//, 'Safari'],
];

const SYSTEMS = [
  [/Windows/, 'Windows'],
  [/Android/, 'Android'],
  [/iPhone|iPad|iOS/, 'iOS'],
  [/Mac OS X|Macintosh/, 'macOS'],
  [/Linux/, 'Linux'],
];

const pick = (list, text) => list.find(([re]) => re.test(text))?.[1];

export const deviceLabel = (name, t) => {
  const value = String(name || '').trim();
  if (!value || value === 'Unknown Device') return t('users.detail.devices.unknown');
  if (!/^Mozilla\//.test(value)) return value.length > 60 ? `${value.slice(0, 57)}...` : value;
  const browser = pick(BROWSERS, value);
  const system = pick(SYSTEMS, value);
  if (browser && system) return t('users.detail.devices.browserOn', { browser, system });
  return browser || system || t('users.detail.devices.browser');
};

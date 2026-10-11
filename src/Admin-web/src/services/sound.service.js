/**
 * Sound Service — Web Audio API Synthesizer
 * Phát âm thanh cảnh báo độc lập, không phụ thuộc file MP3 tĩnh
 */

class SoundService {
  constructor() {
    this.ctx = null;
  }

  /**
   * Khởi tạo hoặc khôi phục AudioContext theo chuẩn Web Audio API
   */
  init() {
    try {
      if (typeof window === 'undefined') return;
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;

      if (!this.ctx) {
        this.ctx = new AudioCtx();
      }

      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume().catch(() => {});
      }
    } catch (_) {
      // Bỏ qua lỗi trong môi trường không hỗ trợ Audio
    }
  }

  /**
   * Còi báo động khẩn cấp: 2 hồi âm tần số kép 880Hz và 440Hz
   * Kích hoạt khi AIOps phát hiện DDoS / Threat Score cao / Sự cố khẩn cấp
   */
  playCriticalAlarm() {
    try {
      this.init();
      if (!this.ctx) return;

      const now = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'triangle';
      // Nhịp 1: 880Hz
      osc.frequency.setValueAtTime(880, now);
      // Nhịp 2: 440Hz sau 150ms
      osc.frequency.setValueAtTime(440, now + 0.15);
      // Nhịp 3: 880Hz sau 300ms
      osc.frequency.setValueAtTime(880, now + 0.3);

      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.55);

      osc.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start(now);
      osc.stop(now + 0.55);
    } catch (_) {
      // Safe fallback
    }
  }

  /**
   * Tiếng chuông thông báo êm dịu (Chime): 520Hz -> 660Hz
   */
  playNotificationSound() {
    try {
      this.init();
      if (!this.ctx) return;

      const now = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(523.25, now); // C5
      osc.frequency.exponentialRampToValueAtTime(659.25, now + 0.12); // E5

      gain.gain.setValueAtTime(0.18, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

      osc.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start(now);
      osc.stop(now + 0.35);
    } catch (_) {
      // Safe fallback
    }
  }
}

export const soundService = new SoundService();
export default soundService;

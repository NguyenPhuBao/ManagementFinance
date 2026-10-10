import { describe, it, expect, vi, beforeEach } from 'vitest';
import { soundService } from '../services/sound.service';

describe('Sound Service — Web Audio API Synthesizer', () => {
  let mockOscillator;
  let mockGain;
  let mockAudioContext;

  beforeEach(() => {
    mockOscillator = {
      type: '',
      frequency: {
        setValueAtTime: vi.fn(),
        exponentialRampToValueAtTime: vi.fn(),
      },
      connect: vi.fn(),
      start: vi.fn(),
      stop: vi.fn(),
    };

    mockGain = {
      gain: {
        setValueAtTime: vi.fn(),
        exponentialRampToValueAtTime: vi.fn(),
      },
      connect: vi.fn(),
    };

    mockAudioContext = {
      state: 'running',
      currentTime: 10,
      destination: {},
      createOscillator: vi.fn(() => mockOscillator),
      createGain: vi.fn(() => mockGain),
      resume: vi.fn().mockResolvedValue(),
    };

    window.AudioContext = vi.fn(() => mockAudioContext);
    soundService.ctx = null;
  });

  it('1. Khởi tạo AudioContext và phát âm thanh còi báo khẩn cấp (Critical Alarm)', () => {
    soundService.playCriticalAlarm();

    expect(window.AudioContext).toHaveBeenCalledTimes(1);
    expect(mockAudioContext.createOscillator).toHaveBeenCalledTimes(1);
    expect(mockAudioContext.createGain).toHaveBeenCalledTimes(1);
    expect(mockOscillator.type).toBe('triangle');
    expect(mockOscillator.start).toHaveBeenCalledWith(10);
    expect(mockOscillator.stop).toHaveBeenCalledWith(10.55);
  });

  it('2. Phát âm thanh chuông thông báo (Notification Chime)', () => {
    soundService.playNotificationSound();

    expect(mockOscillator.type).toBe('sine');
    expect(mockOscillator.start).toHaveBeenCalledWith(10);
    expect(mockOscillator.stop).toHaveBeenCalledWith(10.35);
  });

  it('3. An toàn khi môi trường không hỗ trợ AudioContext (Không gây crash)', () => {
    window.AudioContext = undefined;
    window.webkitAudioContext = undefined;
    soundService.ctx = null;

    expect(() => {
      soundService.playCriticalAlarm();
      soundService.playNotificationSound();
    }).not.toThrow();
  });
});

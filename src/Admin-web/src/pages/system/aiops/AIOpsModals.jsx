import React, { useId } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Button, Modal } from '../../../components/ui';

const fieldClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const THRESHOLDS = [
  { key: 'authFailureThreshold', label: 'authFailure', max: undefined },
  { key: 'trafficSpikeRps', label: 'trafficSpike', max: undefined },
  { key: 'exploitLimit', label: 'exploit', max: undefined },
  { key: 'resourceCpuPercent', label: 'cpu', max: 100 },
  { key: 'resourceMemoryPercent', label: 'ram', max: 100 },
  { key: 'eventLoopLagMs', label: 'lag', max: undefined },
];

export const CalibrateModal = ({ ops }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const {
    showCalibrateModal,
    setShowCalibrateModal,
    customThresholdsInput,
    setCustomThresholdsInput,
    autoRecommendedThresholds,
    handleCalibrate,
    calibrating,
    targetConcurrency,
  } = ops;

  return (
    <Modal
      open={showCalibrateModal}
      onClose={() => setShowCalibrateModal(false)}
      closeDisabled={calibrating}
      size="lg"
      title={t('aiopsPage.calibrate.title')}
      description={t('aiopsPage.calibrate.desc', { n: Number(targetConcurrency).toLocaleString('vi-VN') })}
      footer={
        <>
          <Button onClick={() => setShowCalibrateModal(false)} disabled={calibrating}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="primary" loading={calibrating} onClick={handleCalibrate}>{t('aiopsPage.calibrate.confirm')}</Button>
        </>
      }
    >
      <p className="m-0 mb-3 text-sm text-ink-muted">{t('aiopsPage.calibrate.hint')}</p>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {THRESHOLDS.map(({ key, label, max }) => (
          <div key={key}>
            <label htmlFor={`${ids}-${key}`} className="mb-1 block text-sm font-medium text-ink">
              {t(`aiopsPage.calibrate.${label}`)}
            </label>
            <input
              id={`${ids}-${key}`}
              type="number"
              min="1"
              max={max}
              value={customThresholdsInput[key]}
              placeholder={String(autoRecommendedThresholds[key])}
              onChange={(e) => setCustomThresholdsInput((prev) => ({ ...prev, [key]: e.target.value }))}
              className={`${fieldClass} h-10 tabular-nums`}
            />
          </div>
        ))}
      </div>
    </Modal>
  );
};

export const MitigationModal = ({ ops }) => {
  const { t } = useLanguageSafe();
  const reasonId = useId();
  const { showMitigationModal, setShowMitigationModal, mitigationReason, setMitigationReason, handleTriggerMitigation, mitigating } = ops;

  return (
    <Modal
      open={showMitigationModal}
      onClose={() => setShowMitigationModal(false)}
      closeDisabled={mitigating}
      title={t('aiopsPage.mitigation.title')}
      description={t('aiopsPage.mitigation.desc')}
      footer={
        <>
          <Button onClick={() => setShowMitigationModal(false)} disabled={mitigating}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="danger" icon="lock" loading={mitigating} onClick={handleTriggerMitigation}>{t('aiopsPage.mitigation.confirm')}</Button>
        </>
      }
    >
      <label htmlFor={reasonId} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.mitigation.reason')}</label>
      <textarea id={reasonId} rows={3} value={mitigationReason} onChange={(e) => setMitigationReason(e.target.value)} className={`${fieldClass} py-2`} />
    </Modal>
  );
};

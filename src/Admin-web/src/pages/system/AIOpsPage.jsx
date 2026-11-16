import React from 'react';
import { useLanguageSafe } from '../../store/language.context';
import { Button, PageHeader, SecurityConfirmModal } from '../../components/ui';
import useAIOps from './aiops/useAIOps';
import ScaleSection from './aiops/ScaleSection';
import SignalsSection from './aiops/SignalsSection';
import TrendSection from './aiops/TrendSection';
import VectorSection from './aiops/VectorSection';
import IncidentsSection from './aiops/IncidentsSection';
import QuarantineSection from './aiops/QuarantineSection';
import { CalibrateModal, MitigationModal } from './aiops/AIOpsModals';

const EMPTY_THRESHOLDS = {
  authFailureThreshold: '',
  trafficSpikeRps: '',
  exploitLimit: '',
  resourceCpuPercent: '',
  resourceMemoryPercent: '',
  eventLoopLagMs: '',
};

const AIOpsPage = () => {
  const { t } = useLanguageSafe();
  const ops = useAIOps();

  const openCalibrate = () => {
    ops.setCustomThresholdsInput(EMPTY_THRESHOLDS);
    ops.setShowCalibrateModal(true);
  };

  return (
    <div className="mx-auto flex w-full max-w-screen-2xl flex-col gap-5 p-4 md:p-6">
      <PageHeader
        title={t('aiopsPage.title')}
        description={t('aiopsPage.description')}
        actions={
          <>
            <Button icon="refresh" onClick={ops.handleManualRefresh}>{t('aiopsPage.refresh')}</Button>
            <Button icon="tune" loading={ops.calibrating} onClick={openCalibrate}>{t('aiopsPage.calibrate.open')}</Button>
            {ops.isEmergencyResourceRisk && (
              <Button variant="danger" icon="emergency" onClick={() => ops.setShowMitigationModal(true)}>{t('aiopsPage.mitigation.open')}</Button>
            )}
          </>
        }
      />

      <ScaleSection ops={ops} />
      <SignalsSection ops={ops} />
      <VectorSection ops={ops} />
      <TrendSection ops={ops} />
      <IncidentsSection ops={ops} />
      <QuarantineSection ops={ops} />

      <CalibrateModal ops={ops} />
      <MitigationModal ops={ops} />
      {ops.pinRequest && (
        <SecurityConfirmModal
          isOpen
          onClose={ops.closePinRequest}
          onVerify={ops.pinRequest.run}
          title={ops.pinRequest.title}
          description={ops.pinRequest.description}
          confirmText={ops.pinRequest.confirmText}
          dangerLevel={ops.pinRequest.danger ? 'critical' : 'primary'}
        />
      )}
    </div>
  );
};

export default AIOpsPage;

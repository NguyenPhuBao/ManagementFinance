import React, { useId, useState } from 'react';
import adminApi from '../../../api/admin.api';
import { useAlertSafe } from '../../../store/alert.context';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Modal } from '../../ui';
import { Field, FormError, digits6, inputClass } from './settingsUi';

const EMPTY = { fullName: '', username: '', email: '', countryCode: '+84', phone: '', address: '', pin: '' };
const DEFAULT_SECRET = '123456';
const cleanPhone = (v) => (v || '').trim().replace(/[\s.-]/g, '');

const SummaryRow = ({ label, children }) => (
  <div className="flex justify-between gap-3 border-b border-line py-1.5 last:border-0">
    <span className="text-ink-muted">{label}</span>
    <span className="text-right font-medium text-ink">{children}</span>
  </div>
);

const CreateAdminModal = ({ open, onClose }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const ids = useId();
  const formId = `${ids}-form`;
  const [step, setStep] = useState(1);
  const [form, setForm] = useState(EMPTY);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);

  const set = (key) => (e) => {
    const v = e.target.value;
    setForm((f) => ({ ...f, [key]: key === 'pin' ? digits6(v) : key === 'countryCode' ? v.slice(0, 4) : v }));
  };

  const next = (e) => {
    e.preventDefault();
    setError('');
    const phone = cleanPhone(form.phone);
    if ((form.fullName || '').trim().length < 2) return setError(t('settings.createAdmin.errorFullName'));
    if ((form.username || '').trim().length < 3) return setError(t('settings.createAdmin.errorUsername'));
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((form.email || '').trim())) return setError(t('settings.createAdmin.errorEmail'));
    if (!phone) return setError(t('settings.createAdmin.errorPhoneRequired'));
    if (!/^\+?[0-9]{8,15}$/.test(phone)) return setError(t('settings.createAdmin.errorPhone'));
    setStep(2);
    return undefined;
  };

  const create = async (e) => {
    e.preventDefault();
    setError('');
    if (!/^\d{6}$/.test(form.pin)) return setError(t('settings.createAdmin.errorPin'));
    const payload = {
      fullName: form.fullName.trim(),
      username: form.username.trim(),
      email: form.email.trim(),
      phone: cleanPhone(form.phone),
      address: form.address.trim() || null,
      countryCode: (form.countryCode || '+84').trim().slice(0, 4),
      pin: form.pin,
    };
    setLoading(true);
    try {
      const res = await adminApi.createAdmin(payload);
      setResult(res?.data?.data || payload);
      setStep(3);
      if (notify) notify.success(t('settings.createAdmin.success'));
    } catch (err) {
      setError(err?.response?.data?.message || err?.message || t('settings.createAdmin.failed'));
    } finally {
      setLoading(false);
    }
    return undefined;
  };

  const footer =
    step === 1 ? (
      <>
        <Button onClick={onClose}>{t('common.cancel', 'Hủy bỏ')}</Button>
        <Button type="submit" form={formId} variant="primary" icon="arrow_forward" data-testid="btn-next-create-admin">
          {t('settings.createAdmin.next')}
        </Button>
      </>
    ) : step === 2 ? (
      <>
        <Button icon="arrow_back" onClick={() => setStep(1)} disabled={loading}>
          {t('settings.createAdmin.back')}
        </Button>
        <Button type="submit" form={formId} variant="primary" loading={loading} data-testid="submit-create-admin-btn">
          {t('settings.createAdmin.submit')}
        </Button>
      </>
    ) : (
      <Button variant="primary" onClick={onClose} data-testid="btn-finish-create-admin">
        {t('settings.createAdmin.finish')}
      </Button>
    );

  const phoneText = (r) => `${r?.country_code || r?.countryCode || form.countryCode || '+84'} ${r?.phone || cleanPhone(form.phone)}`;

  return (
    <Modal
      open={open}
      onClose={onClose}
      size="md"
      closeDisabled={loading}
      title={t('settings.createAdmin.title')}
      description={step < 3 ? t('settings.createAdmin.step', { step }) : undefined}
      footer={footer}
    >
      {step === 1 && (
        <form id={formId} onSubmit={next} noValidate className="flex flex-col gap-3">
          <FormError message={error} />
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field id={`${ids}-name`} label={t('settings.createAdmin.fullName')}>
              <input id={`${ids}-name`} data-testid="create-admin-fullname" value={form.fullName} onChange={set('fullName')} className={inputClass} autoFocus />
            </Field>
            <Field id={`${ids}-user`} label={t('settings.createAdmin.username')}>
              <input id={`${ids}-user`} data-testid="create-admin-username" value={form.username} onChange={set('username')} className={inputClass} />
            </Field>
          </div>
          <Field id={`${ids}-email`} label={t('settings.createAdmin.email')}>
            <input id={`${ids}-email`} type="email" data-testid="create-admin-email" value={form.email} onChange={set('email')} className={inputClass} />
          </Field>
          <div className="grid grid-cols-3 gap-3">
            <Field id={`${ids}-cc`} label={t('settings.createAdmin.countryCode')}>
              <input id={`${ids}-cc`} maxLength={4} data-testid="create-admin-country-code" value={form.countryCode} onChange={set('countryCode')} className={`${inputClass} text-center font-mono`} />
            </Field>
            <div className="col-span-2">
              <Field id={`${ids}-phone`} label={t('settings.createAdmin.phone')}>
                <input id={`${ids}-phone`} type="tel" data-testid="create-admin-phone" value={form.phone} onChange={set('phone')} className={inputClass} />
              </Field>
            </div>
          </div>
          <Field id={`${ids}-address`} label={t('settings.createAdmin.address')}>
            <input id={`${ids}-address`} data-testid="create-admin-address" value={form.address} onChange={set('address')} className={inputClass} />
          </Field>
          <p className="m-0 rounded-lg bg-warning-soft px-3 py-2 text-sm text-ink">{t('settings.createAdmin.defaultNote', { secret: DEFAULT_SECRET })}</p>
        </form>
      )}

      {step === 2 && (
        <form id={formId} onSubmit={create} noValidate className="flex flex-col gap-3">
          <FormError message={error} />
          <div className="rounded-lg border border-line px-4 py-2 text-sm">
            <SummaryRow label={t('settings.createAdmin.fullName')}>{form.fullName}</SummaryRow>
            <SummaryRow label={t('settings.createAdmin.username')}>
              <span className="font-mono">{form.username}</span>
            </SummaryRow>
            <SummaryRow label={t('settings.createAdmin.email')}>{form.email}</SummaryRow>
            <SummaryRow label={t('settings.createAdmin.phone')}>{phoneText(null)}</SummaryRow>
            {form.address && <SummaryRow label={t('settings.createAdmin.address')}>{form.address}</SummaryRow>}
          </div>
          <Field id={`${ids}-pin`} label={t('settings.createAdmin.pin')}>
            <input
              id={`${ids}-pin`}
              type="password"
              inputMode="numeric"
              maxLength={6}
              data-testid="create-admin-pin-auth"
              value={form.pin}
              onChange={set('pin')}
              className={`${inputClass} text-center font-mono tracking-widest`}
              autoFocus
            />
          </Field>
        </form>
      )}

      {step === 3 && result && (
        <div className="flex flex-col gap-3">
          <p className="m-0 font-semibold text-success">{t('settings.createAdmin.done')}</p>
          <div className="rounded-lg border border-line px-4 py-2 text-sm">
            <SummaryRow label={t('settings.createAdmin.fullName')}>{result.fullname || result.fullName || form.fullName}</SummaryRow>
            <SummaryRow label={t('settings.createAdmin.username')}>
              <span className="font-mono">{result.username}</span>
            </SummaryRow>
            <SummaryRow label={t('settings.createAdmin.email')}>{result.email}</SummaryRow>
            <SummaryRow label={t('settings.createAdmin.phone')}>{phoneText(result)}</SummaryRow>
            <SummaryRow label={t('settings.createAdmin.initialPassword')}>
              <span className="font-mono">{DEFAULT_SECRET}</span>
            </SummaryRow>
            <SummaryRow label={t('settings.createAdmin.initialPin')}>
              <span className="font-mono">{DEFAULT_SECRET}</span>
            </SummaryRow>
          </div>
          <div>
            <Badge tone="warning">{t('settings.createAdmin.mustChange')}</Badge>
          </div>
        </div>
      )}
    </Modal>
  );
};

export default CreateAdminModal;

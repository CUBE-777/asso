import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useTranslation } from 'react-i18next';
import { memberInputSchema, type MemberInput } from '@ams/validation';
import { createMember } from '@ams/data-access';
import { Button, Field, Input } from '@ams/ui';
import { useState } from 'react';

interface MemberFormPageProps {
  onSaved: (memberId: string) => void;
  onCancel: () => void;
}

export function MemberFormPage({ onSaved, onCancel }: MemberFormPageProps) {
  const { t } = useTranslation();
  const [submitError, setSubmitError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<MemberInput>({
    resolver: zodResolver(memberInputSchema),
    defaultValues: { currentStatus: 'accepted' },
  });

  async function onSubmit(values: MemberInput) {
    setSubmitError(null);
    try {
      const member = await createMember(values);
      onSaved(member.id);
    } catch (err: any) {
      // RLS denials and DB constraint violations both surface here in plain
      // language rather than a raw Postgres error (Section 44: no stack
      // traces to normal users).
      setSubmitError(t('members.saveError'));
      console.error(err);
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex max-w-lg flex-col gap-4">
      <h1 className="text-xl font-semibold">{t('members.addMember')}</h1>

      <Field label={t('members.fields.membershipNumber')} error={errors.membershipNumber?.message}>
        <Input {...register('membershipNumber')} />
      </Field>

      <Field label={t('members.fields.fullName')} error={errors.fullName?.message}>
        <Input {...register('fullName')} />
      </Field>

      <Field label={t('members.fields.email')} error={errors.email?.message}>
        <Input type="email" {...register('email')} />
      </Field>

      <Field label={t('members.fields.phone')} error={errors.phone?.message}>
        <Input {...register('phone')} />
      </Field>

      <Field label={t('members.fields.membershipDate')} error={errors.membershipDate?.message}>
        <Input type="date" {...register('membershipDate')} />
      </Field>

      {submitError && <p className="text-sm text-[var(--color-danger)]">{submitError}</p>}

      <div className="flex gap-3 pt-2">
        <Button type="submit" disabled={isSubmitting}>
          {t('members.save')}
        </Button>
        <Button type="button" variant="secondary" onClick={onCancel}>
          {t('members.cancel')}
        </Button>
      </div>
    </form>
  );
}

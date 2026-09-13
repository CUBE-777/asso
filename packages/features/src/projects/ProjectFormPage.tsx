import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useTranslation } from 'react-i18next';
import { projectInputSchema, type ProjectInput } from '@ams/validation';
import { createProject } from '@ams/data-access';
import { Button, Field, Input, Select, Textarea } from '@ams/ui';

interface ProjectFormPageProps {
  onSaved: (projectId: string) => void;
  onCancel: () => void;
}

const STATUSES: ProjectInput['status'][] = ['planning', 'active', 'on_hold', 'completed', 'cancelled'];

export function ProjectFormPage({ onSaved, onCancel }: ProjectFormPageProps) {
  const { t } = useTranslation();
  const [submitError, setSubmitError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ProjectInput>({
    resolver: zodResolver(projectInputSchema),
    defaultValues: { status: 'planning' },
  });

  async function onSubmit(values: ProjectInput) {
    setSubmitError(null);
    try {
      const project = await createProject(values);
      onSaved(project.id);
    } catch (err: any) {
      setSubmitError(t('projects.saveError'));
      console.error(err);
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex max-w-lg flex-col gap-4">
      <h1 className="text-xl font-semibold">{t('projects.addProject')}</h1>

      <Field label={t('projects.fields.name')} error={errors.name?.message}>
        <Input {...register('name')} />
      </Field>

      <Field label={t('projects.fields.description')} error={errors.description?.message}>
        <Textarea {...register('description')} />
      </Field>

      <Field label={t('projects.fields.objectives')} error={errors.objectives?.message}>
        <Textarea {...register('objectives')} />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t('projects.fields.startDate')} error={errors.startDate?.message}>
          <Input type="date" {...register('startDate')} />
        </Field>
        <Field label={t('projects.fields.endDate')} error={errors.endDate?.message}>
          <Input type="date" {...register('endDate')} />
        </Field>
      </div>

      <Field label={t('projects.fields.status')} error={errors.status?.message}>
        <Select {...register('status')}>
          {STATUSES.map((status) => (
            <option key={status} value={status}>
              {t(`projects.status.${status}`)}
            </option>
          ))}
        </Select>
      </Field>

      {submitError && <p className="text-sm text-[var(--color-danger)]">{submitError}</p>}

      <div className="flex gap-3 pt-2">
        <Button type="submit" disabled={isSubmitting}>
          {t('projects.save')}
        </Button>
        <Button type="button" variant="secondary" onClick={onCancel}>
          {t('projects.cancel')}
        </Button>
      </div>
    </form>
  );
}

import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getProject, listActivitiesForProject } from '@ams/data-access';
import type { Project } from '@ams/types';
import { Badge, Card, projectStatusTone } from '@ams/ui';

interface ProjectDetailPageProps {
  projectId: string;
}

interface ActivityRow {
  id: string;
  name: string;
  status: string;
  activityDate: string | null;
  location: string | null;
}

export function ProjectDetailPage({ projectId }: ProjectDetailPageProps) {
  const { t } = useTranslation();
  const [project, setProject] = useState<Project | null>(null);
  const [activities, setActivities] = useState<ActivityRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    Promise.all([getProject(projectId), listActivitiesForProject(projectId)])
      .then(([projectRow, activityRows]) => {
        if (cancelled) return;
        setProject(projectRow);
        setActivities(activityRows);
      })
      .catch((err) => {
        if (!cancelled) setError(err.message ?? String(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [projectId]);

  if (loading) return <p className="text-sm text-[var(--color-text-muted)]">{t('common.loading')}</p>;
  if (error) return <p className="text-sm text-[var(--color-danger)]">{error}</p>;
  if (!project) return null;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <h1 className="text-xl font-semibold">{project.name}</h1>
        <Badge tone={projectStatusTone(project.status)}>{t(`projects.status.${project.status}`)}</Badge>
      </div>

      <Card>
        <dl className="grid grid-cols-2 gap-4 text-sm">
          <div className="col-span-2">
            <dt className="text-[var(--color-text-muted)]">{t('projects.fields.description')}</dt>
            <dd className="mt-1">{project.description ?? '—'}</dd>
          </div>
          <div className="col-span-2">
            <dt className="text-[var(--color-text-muted)]">{t('projects.fields.objectives')}</dt>
            <dd className="mt-1">{project.objectives ?? '—'}</dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('projects.fields.startDate')}</dt>
            <dd>{project.startDate ?? '—'}</dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('projects.fields.endDate')}</dt>
            <dd>{project.endDate ?? '—'}</dd>
          </div>
        </dl>
      </Card>

      <Card>
        <h2 className="mb-3 text-sm font-semibold text-[var(--color-text-muted)]">{t('projects.activitiesTitle')}</h2>
        {activities.length === 0 ? (
          <p className="text-sm text-[var(--color-text-muted)]">{t('projects.noActivities')}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {activities.map((activity) => (
              <li key={activity.id} className="flex items-center justify-between border-t border-[var(--color-border)] py-2 text-sm first:border-t-0 first:pt-0">
                <span>{activity.name}</span>
                <span className="text-[var(--color-text-muted)]">{activity.activityDate ?? '—'}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}

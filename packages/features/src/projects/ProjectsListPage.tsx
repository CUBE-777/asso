import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { listProjects } from '@ams/data-access';
import { useAuth } from '@ams/auth';
import type { Project } from '@ams/types';
import { Button, Card, Input, Badge, projectStatusTone } from '@ams/ui';

interface ProjectsListPageProps {
  onOpenProject: (id: string) => void;
  onAddProject: () => void;
}

export function ProjectsListPage({ onOpenProject, onAddProject }: ProjectsListPageProps) {
  const { t } = useTranslation();
  const { hasPermission } = useAuth();
  const [projects, setProjects] = useState<Project[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const canCreate = hasPermission('projects.manage');

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    const debounce = setTimeout(() => {
      listProjects({ search: search || undefined })
        .then((rows) => {
          if (!cancelled) setProjects(rows);
        })
        .catch((err) => {
          if (!cancelled) setError(err.message ?? String(err));
        })
        .finally(() => {
          if (!cancelled) setLoading(false);
        });
    }, 250);

    return () => {
      cancelled = true;
      clearTimeout(debounce);
    };
  }, [search]);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-xl font-semibold">{t('projects.title')}</h1>
        {canCreate && <Button onClick={onAddProject}>{t('projects.addProject')}</Button>}
      </div>

      <Input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder={t('projects.search')}
        className="max-w-sm"
      />

      <Card className="p-0 overflow-hidden">
        {loading ? (
          <p className="p-6 text-sm text-[var(--color-text-muted)]">{t('common.loading')}</p>
        ) : error ? (
          <p className="p-6 text-sm text-[var(--color-danger)]">{error}</p>
        ) : projects.length === 0 ? (
          <p className="p-6 text-sm text-[var(--color-text-muted)]">{t('projects.empty')}</p>
        ) : (
          <table className="w-full text-start text-sm">
            <thead className="bg-[var(--color-surface-raised)] text-[var(--color-text-muted)]">
              <tr>
                <th className="px-4 py-3 text-start font-medium">{t('projects.fields.name')}</th>
                <th className="px-4 py-3 text-start font-medium">{t('projects.fields.startDate')}</th>
                <th className="px-4 py-3 text-start font-medium">{t('projects.fields.endDate')}</th>
                <th className="px-4 py-3 text-start font-medium">{t('projects.fields.status')}</th>
              </tr>
            </thead>
            <tbody>
              {projects.map((project) => (
                <tr
                  key={project.id}
                  onClick={() => onOpenProject(project.id)}
                  className="cursor-pointer border-t border-[var(--color-border)] hover:bg-[var(--color-surface-raised)]"
                >
                  <td className="px-4 py-3 font-medium">{project.name}</td>
                  <td className="px-4 py-3 text-[var(--color-text-muted)]">{project.startDate ?? '—'}</td>
                  <td className="px-4 py-3 text-[var(--color-text-muted)]">{project.endDate ?? '—'}</td>
                  <td className="px-4 py-3">
                    <Badge tone={projectStatusTone(project.status)}>{t(`projects.status.${project.status}`)}</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}

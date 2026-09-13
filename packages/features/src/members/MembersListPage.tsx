import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { listMembers } from '@ams/data-access';
import { useAuth } from '@ams/auth';
import type { Member } from '@ams/types';
import { Button, Card, Input, Badge, memberStatusTone } from '@ams/ui';

interface MembersListPageProps {
  onOpenMember: (id: string) => void;
  onAddMember: () => void;
}

export function MembersListPage({ onOpenMember, onAddMember }: MembersListPageProps) {
  const { t } = useTranslation();
  const { hasPermission } = useAuth();
  const [members, setMembers] = useState<Member[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const canCreate = hasPermission('members.create');

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    const debounce = setTimeout(() => {
      listMembers({ search: search || undefined })
        .then((rows) => {
          if (!cancelled) setMembers(rows);
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
        <h1 className="text-xl font-semibold">{t('members.title')}</h1>
        {canCreate && <Button onClick={onAddMember}>{t('members.addMember')}</Button>}
      </div>

      <Input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder={t('members.search')}
        className="max-w-sm"
      />

      <Card className="p-0 overflow-hidden">
        {loading ? (
          <p className="p-6 text-sm text-[var(--color-text-muted)]">{t('common.loading')}</p>
        ) : error ? (
          <p className="p-6 text-sm text-[var(--color-danger)]">{error}</p>
        ) : members.length === 0 ? (
          <p className="p-6 text-sm text-[var(--color-text-muted)]">{t('members.empty')}</p>
        ) : (
          <table className="w-full text-start text-sm">
            <thead className="bg-[var(--color-surface-raised)] text-[var(--color-text-muted)]">
              <tr>
                <th className="px-4 py-3 text-start font-medium">{t('members.fields.membershipNumber')}</th>
                <th className="px-4 py-3 text-start font-medium">{t('members.fields.fullName')}</th>
                <th className="px-4 py-3 text-start font-medium">{t('members.fields.phone')}</th>
                <th className="px-4 py-3 text-start font-medium">{t('members.fields.status')}</th>
              </tr>
            </thead>
            <tbody>
              {members.map((member) => (
                <tr
                  key={member.id}
                  onClick={() => onOpenMember(member.id)}
                  className="cursor-pointer border-t border-[var(--color-border)] hover:bg-[var(--color-surface-raised)]"
                >
                  <td className="px-4 py-3 text-[var(--color-text-muted)]">{member.membershipNumber}</td>
                  <td className="px-4 py-3 font-medium">{member.fullName}</td>
                  <td className="px-4 py-3 text-[var(--color-text-muted)]">{member.phone ?? '—'}</td>
                  <td className="px-4 py-3">
                    <Badge tone={memberStatusTone(member.currentStatus)}>
                      {t(`members.status.${member.currentStatus}`)}
                    </Badge>
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

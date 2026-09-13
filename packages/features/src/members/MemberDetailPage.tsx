import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getMember, getMemberStatusHistory } from '@ams/data-access';
import type { Member, MemberStatusHistoryEntry } from '@ams/types';
import { Badge, Card, memberStatusTone } from '@ams/ui';

interface MemberDetailPageProps {
  memberId: string;
}

export function MemberDetailPage({ memberId }: MemberDetailPageProps) {
  const { t } = useTranslation();
  const [member, setMember] = useState<Member | null>(null);
  const [history, setHistory] = useState<MemberStatusHistoryEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    Promise.all([getMember(memberId), getMemberStatusHistory(memberId)])
      .then(([memberRow, historyRows]) => {
        if (cancelled) return;
        setMember(memberRow);
        setHistory(historyRows);
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
  }, [memberId]);

  if (loading) return <p className="text-sm text-[var(--color-text-muted)]">{t('common.loading')}</p>;
  if (error) return <p className="text-sm text-[var(--color-danger)]">{error}</p>;
  if (!member) return null;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <h1 className="text-xl font-semibold">{member.fullName}</h1>
        <Badge tone={memberStatusTone(member.currentStatus)}>{t(`members.status.${member.currentStatus}`)}</Badge>
      </div>

      <Card>
        <dl className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('members.fields.membershipNumber')}</dt>
            <dd>{member.membershipNumber}</dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('members.fields.email')}</dt>
            <dd>{member.email ?? '—'}</dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('members.fields.phone')}</dt>
            <dd>{member.phone ?? '—'}</dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('members.fields.membershipDate')}</dt>
            <dd>{member.membershipDate}</dd>
          </div>
        </dl>
      </Card>

      <Card>
        <h2 className="mb-3 text-sm font-semibold text-[var(--color-text-muted)]">
          {t('members.fields.status')}
        </h2>
        <ul className="flex flex-col gap-2">
          {history.map((entry) => (
            <li key={entry.id} className="flex items-center gap-2 text-sm">
              <span className="text-[var(--color-text-muted)]">
                {new Date(entry.changedAt).toLocaleDateString()}
              </span>
              <span>
                {entry.previousStatus ? t(`members.status.${entry.previousStatus}`) : '—'}
                {' \u2192 '}
                {t(`members.status.${entry.newStatus}`)}
              </span>
            </li>
          ))}
        </ul>
      </Card>
    </div>
  );
}

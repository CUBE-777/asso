import type { HTMLAttributes } from 'react';

export function Card({ className = '', ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={
        'rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-surface)] p-5 ' + className
      }
      {...props}
    />
  );
}

type BadgeTone = 'neutral' | 'success' | 'warning' | 'danger';

const toneClasses: Record<BadgeTone, string> = {
  neutral: 'bg-[var(--color-surface-raised)] text-[var(--color-text-muted)] border-[var(--color-border)]',
  success: 'bg-[var(--color-success-bg)] text-[var(--color-success)] border-transparent',
  warning: 'bg-[var(--color-warning-bg)] text-[var(--color-warning)] border-transparent',
  danger: 'bg-[var(--color-danger-bg)] text-[var(--color-danger)] border-transparent',
};

export function Badge({ tone = 'neutral', children }: { tone?: BadgeTone; children: React.ReactNode }) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium ${toneClasses[tone]}`}
    >
      {children}
    </span>
  );
}

// Maps a member's current_status directly to a badge tone, so every screen
// that shows member status looks the same without repeating this logic.
export function memberStatusTone(status: string): BadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'suspended':
      return 'warning';
    case 'withdrawn':
      return 'danger';
    default:
      return 'neutral';
  }
}

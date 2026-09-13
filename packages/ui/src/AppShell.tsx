import type { ReactNode } from 'react';

export interface NavItem {
  key: string;
  label: string;
  href: string;
  icon?: ReactNode;
}

interface AppShellProps {
  navItems: NavItem[];
  activeKey: string;
  onNavigate: (href: string) => void;
  appName: string;
  userLabel?: string;
  signOutLabel?: string;
  onSignOut?: () => void;
  children: ReactNode;
}

// Uses margin-inline-start / border-inline-end (logical properties) rather
// than margin-left / border-right, so the whole layout mirrors correctly
// just from <html dir="rtl">, with no per-component RTL branching (Section 38).
export function AppShell({
  navItems,
  activeKey,
  onNavigate,
  appName,
  userLabel,
  signOutLabel,
  onSignOut,
  children,
}: AppShellProps) {
  return (
    <div className="flex min-h-screen bg-[var(--color-bg)] text-[var(--color-text)]">
      <aside
        className="hidden md:flex flex-col shrink-0 border-e border-[var(--color-border)] bg-[var(--color-surface)]"
        style={{ width: 'var(--sidebar-width)' }}
      >
        <div className="px-5 py-5 border-b border-[var(--color-border)]">
          <p className="text-base font-semibold">{appName}</p>
        </div>
        <nav className="flex-1 overflow-y-auto py-3">
          <ul className="flex flex-col gap-0.5 px-3">
            {navItems.map((item) => {
              const isActive = item.key === activeKey;
              return (
                <li key={item.key}>
                  <button
                    onClick={() => onNavigate(item.href)}
                    className={
                      'w-full flex items-center gap-2.5 rounded-[var(--radius-sm)] px-3 py-2 text-sm text-start transition-colors ' +
                      (isActive
                        ? 'bg-[var(--color-accent)] text-[var(--color-accent-text)]'
                        : 'text-[var(--color-text-muted)] hover:bg-[var(--color-surface-raised)] hover:text-[var(--color-text)]')
                    }
                  >
                    {item.icon}
                    <span>{item.label}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        </nav>
        {userLabel && (
          <div className="border-t border-[var(--color-border)] px-5 py-4">
            <p className="text-sm text-[var(--color-text-muted)] truncate">{userLabel}</p>
            {onSignOut && (
              <button onClick={onSignOut} className="mt-1 text-sm text-[var(--color-accent)] hover:underline">
                {signOutLabel ?? 'Sign out'}
              </button>
            )}
          </div>
        )}
      </aside>

      <main className="flex-1 min-w-0">
        <div className="mx-auto max-w-6xl px-6 py-8">{children}</div>
      </main>
    </div>
  );
}

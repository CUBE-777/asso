import { useEffect, useMemo } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { AuthProvider, useAuth } from '@ams/auth';
import { initI18n, applyDirection } from '@ams/i18n';
import { AppShell, type NavItem } from '@ams/ui';
import { MembersListPage, MemberFormPage, MemberDetailPage } from '@ams/features';
import { LoginPage } from './pages/LoginPage';

initI18n('ar');

function AuthenticatedApp() {
  const { t, i18n } = useTranslation();
  const { profile, hasPermission, signOut } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    if (profile?.preferredLanguage) {
      i18n.changeLanguage(profile.preferredLanguage);
      applyDirection(profile.preferredLanguage);
    }
    if (profile?.preferredTheme) {
      document.documentElement.dataset.theme = profile.preferredTheme;
    }
  }, [profile, i18n]);

  const navItems: NavItem[] = useMemo(() => {
    const items: NavItem[] = [];
    // Every entry is gated by the permission that actually protects the data
    // behind it — RLS enforces this server-side regardless, but hiding links
    // to screens a role can't use keeps the UI honest about what it can do.
    if (hasPermission('members.read')) items.push({ key: 'members', label: t('nav.members'), href: '/members' });
    if (hasPermission('projects.read')) items.push({ key: 'projects', label: t('nav.projects'), href: '/projects' });
    if (hasPermission('activities.read'))
      items.push({ key: 'activities', label: t('nav.activities'), href: '/activities' });
    if (hasPermission('finance.read') || hasPermission('finance.read.summary'))
      items.push({ key: 'finance', label: t('nav.finance'), href: '/finance' });
    return items;
  }, [hasPermission, t]);

  const activeKey = navItems.find((item) => location.pathname.startsWith(item.href))?.key ?? '';

  return (
    <AppShell
      navItems={navItems}
      activeKey={activeKey}
      onNavigate={navigate}
      appName={t('app.name')}
      userLabel={profile?.fullName}
      signOutLabel={t('nav.signOut')}
      onSignOut={signOut}
    >
      <Routes>
        <Route path="/" element={<Navigate to="/members" replace />} />
        <Route
          path="/members"
          element={
            <MembersListPage
              onOpenMember={(id) => navigate(`/members/${id}`)}
              onAddMember={() => navigate('/members/new')}
            />
          }
        />
        <Route
          path="/members/new"
          element={
            <MemberFormPage
              onSaved={(id) => navigate(`/members/${id}`)}
              onCancel={() => navigate('/members')}
            />
          }
        />
        <Route path="/members/:id" element={<MemberDetailRoute />} />
      </Routes>
    </AppShell>
  );
}

function MemberDetailRoute() {
  const { pathname } = useLocation();
  const id = pathname.split('/').pop()!;
  return <MemberDetailPage memberId={id} />;
}

function AppGate() {
  const { session, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[var(--color-bg)] text-[var(--color-text-muted)]">
        …
      </div>
    );
  }

  return session ? <AuthenticatedApp /> : <LoginPage />;
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppGate />
      </AuthProvider>
    </BrowserRouter>
  );
}

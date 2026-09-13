import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '@ams/data-access';

interface Profile {
  id: string;
  fullName: string;
  email: string;
  preferredLanguage: 'ar' | 'fr' | 'en';
  preferredTheme: 'dark' | 'light';
  memberId: string | null;
}

interface AuthState {
  session: Session | null;
  profile: Profile | null;
  permissions: Set<string>;
  loading: boolean;
  hasPermission: (code: string) => boolean;
  signIn: (email: string, password: string) => Promise<{ error: string | null }>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

function rowToProfile(row: any): Profile {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    preferredLanguage: row.preferred_language,
    preferredTheme: row.preferred_theme,
    memberId: row.member_id,
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [permissions, setPermissions] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);

  async function loadProfileAndPermissions() {
    const [{ data: profileRow, error: profileError }, { data: permRows, error: permError }] = await Promise.all([
      supabase.rpc('get_my_profile').single(),
      supabase.rpc('get_my_permissions'),
    ]);

    if (profileError) {
      // A missing profile usually means the auto-provisioning trigger (0008)
      // hasn't run yet for a brand-new signup — surface it rather than
      // silently showing an empty app shell.
      console.error('Failed to load profile:', profileError.message);
    } else if (profileRow) {
      setProfile(rowToProfile(profileRow));
    }

    if (permError) {
      console.error('Failed to load permissions:', permError.message);
    } else {
      setPermissions(new Set((permRows ?? []).map((r: { code: string }) => r.code)));
    }
  }

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data }) => {
      setSession(data.session);
      if (data.session) await loadProfileAndPermissions();
      setLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      setSession(newSession);
      if (newSession) {
        await loadProfileAndPermissions();
      } else {
        setProfile(null);
        setPermissions(new Set());
      }
    });

    return () => subscription.subscription.unsubscribe();
  }, []);

  async function signIn(email: string, password: string) {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return { error: error?.message ?? null };
  }

  async function signOut() {
    await supabase.auth.signOut();
  }

  function hasPermission(code: string) {
    return permissions.has(code);
  }

  return (
    <AuthContext.Provider value={{ session, profile, permissions, loading, hasPermission, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}

import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '@ams/auth';
import { Button, Card, Field, Input } from '@ams/ui';

export function LoginPage() {
  const { t } = useTranslation();
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error: signInError } = await signIn(email, password);
    if (signInError) setError(t('auth.signInError'));
    setLoading(false);
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--color-bg)] px-4">
      <Card className="w-full max-w-sm">
        <h1 className="mb-6 text-center text-lg font-semibold">{t('app.name')}</h1>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <Field label={t('auth.email')}>
            <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus />
          </Field>
          <Field label={t('auth.password')}>
            <Input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </Field>
          {error && <p className="text-sm text-[var(--color-danger)]">{error}</p>}
          <Button type="submit" disabled={loading} className="mt-2">
            {t('auth.signIn')}
          </Button>
        </form>
      </Card>
    </div>
  );
}

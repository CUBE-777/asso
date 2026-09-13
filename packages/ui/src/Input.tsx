import { type InputHTMLAttributes, type ReactNode, forwardRef } from 'react';

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(function Input(
  { className = '', ...props },
  ref
) {
  return (
    <input
      ref={ref}
      className={
        'w-full rounded-[var(--radius-sm)] border border-[var(--color-border)] bg-[var(--color-surface)] ' +
        'px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] ' +
        'focus:outline-none focus:border-[var(--color-accent)] ' +
        className
      }
      {...props}
    />
  );
});

interface FieldProps {
  label: string;
  error?: string;
  children: ReactNode;
  htmlFor?: string;
}

export function Field({ label, error, children, htmlFor }: FieldProps) {
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={htmlFor} className="text-sm text-[var(--color-text-muted)]">
        {label}
      </label>
      {children}
      {error && <p className="text-sm text-[var(--color-danger)]">{error}</p>}
    </div>
  );
}

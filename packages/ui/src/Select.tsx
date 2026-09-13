import { type SelectHTMLAttributes, type TextareaHTMLAttributes, forwardRef } from 'react';

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(function Select(
  { className = '', children, ...props },
  ref
) {
  return (
    <select
      ref={ref}
      className={
        'w-full rounded-[var(--radius-sm)] border border-[var(--color-border)] bg-[var(--color-surface)] ' +
        'px-3 py-2 text-sm text-[var(--color-text)] focus:outline-none focus:border-[var(--color-accent)] ' +
        className
      }
      {...props}
    >
      {children}
    </select>
  );
});

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  function Textarea({ className = '', rows = 4, ...props }, ref) {
    return (
      <textarea
        ref={ref}
        rows={rows}
        className={
          'w-full rounded-[var(--radius-sm)] border border-[var(--color-border)] bg-[var(--color-surface)] ' +
          'px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] ' +
          'focus:outline-none focus:border-[var(--color-accent)] ' +
          className
        }
        {...props}
      />
    );
  }
);

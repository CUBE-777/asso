import { z } from 'zod';

// Shared between React Hook Form (frontend) and any Edge Function that needs
// to re-validate server-side (Architecture Doc Section 47: "frontend
// validation is not sufficient; important validation must also occur
// server-side"). Keep this in sync with the CHECK constraints in
// supabase/migrations/0009_members.sql.

export const memberStatusSchema = z.enum([
  'application',
  'accepted',
  'active',
  'suspended',
  'withdrawn',
]);

export const memberInputSchema = z.object({
  membershipNumber: z.string().min(1, 'membershipNumber is required'),
  fullName: z.string().min(1, 'fullName is required'),
  dateOfBirth: z.string().date().optional().nullable(),
  email: z.string().email().optional().nullable(),
  phone: z.string().min(6).optional().nullable(),
  address: z.string().optional().nullable(),
  profession: z.string().optional().nullable(),
  associationRole: z.string().optional().nullable(),
  membershipDate: z.string().date().optional(),
  currentStatus: memberStatusSchema.optional(),
  notes: z.string().optional().nullable(),
});

export type MemberInput = z.infer<typeof memberInputSchema>;

export const memberSkillInputSchema = z.object({
  memberId: z.string().uuid(),
  skillName: z.string().min(1),
  proficiency: z.enum(['basic', 'intermediate', 'advanced', 'expert']).optional().nullable(),
});

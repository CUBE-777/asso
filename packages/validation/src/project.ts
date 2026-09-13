import { z } from 'zod';

export const projectStatusSchema = z.enum(['planning', 'active', 'on_hold', 'completed', 'cancelled']);

export const projectInputSchema = z.object({
  name: z.string().min(1, 'name is required'),
  description: z.string().optional().nullable(),
  objectives: z.string().optional().nullable(),
  startDate: z.string().date().optional().nullable(),
  endDate: z.string().date().optional().nullable(),
  status: projectStatusSchema.optional(),
  notes: z.string().optional().nullable(),
}).refine(
  (data) => !data.startDate || !data.endDate || data.endDate >= data.startDate,
  { message: 'endDate must be on or after startDate', path: ['endDate'] }
);

export type ProjectInput = z.infer<typeof projectInputSchema>;

export const activityStatusSchema = z.enum(['planned', 'ongoing', 'completed', 'cancelled']);

export const activityInputSchema = z.object({
  projectId: z.string().uuid().optional().nullable(),
  name: z.string().min(1, 'name is required'),
  description: z.string().optional().nullable(),
  activityDate: z.string().date().optional().nullable(),
  startTime: z.string().optional().nullable(),
  endTime: z.string().optional().nullable(),
  location: z.string().optional().nullable(),
  status: activityStatusSchema.optional(),
  notes: z.string().optional().nullable(),
});

export type ActivityInput = z.infer<typeof activityInputSchema>;

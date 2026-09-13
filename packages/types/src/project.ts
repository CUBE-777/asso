// Mirrors public.projects — keep in sync with supabase/migrations/0012_projects.sql
export type ProjectStatus = 'planning' | 'active' | 'on_hold' | 'completed' | 'cancelled';

export interface Project {
  id: string;
  name: string;
  description: string | null;
  objectives: string | null;
  startDate: string | null;
  endDate: string | null;
  status: ProjectStatus;
  results: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface ProjectMilestone {
  id: string;
  projectId: string;
  title: string;
  description: string | null;
  dueDate: string | null;
  completedAt: string | null;
  sortOrder: number;
}

// Mirrors public.activities — keep in sync with supabase/migrations/0013_activities.sql
export type ActivityStatus = 'planned' | 'ongoing' | 'completed' | 'cancelled';

export interface Activity {
  id: string;
  projectId: string | null;
  name: string;
  description: string | null;
  activityDate: string | null;
  startTime: string | null;
  endTime: string | null;
  location: string | null;
  status: ActivityStatus;
  results: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export type AttendanceStatus = 'registered' | 'attended' | 'absent' | 'cancelled';

export interface ActivityParticipant {
  activityId: string;
  memberId: string;
  attendanceStatus: AttendanceStatus;
  registeredAt: string;
}

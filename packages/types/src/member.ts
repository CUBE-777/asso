// Mirrors public.members — keep in sync with supabase/migrations/0009_members.sql
export type MemberStatus = 'application' | 'accepted' | 'active' | 'suspended' | 'withdrawn';

export interface Member {
  id: string;
  membershipNumber: string;
  fullName: string;
  dateOfBirth: string | null;      // ISO date
  email: string | null;
  phone: string | null;
  address: string | null;
  photoPath: string | null;
  profession: string | null;
  associationRole: string | null;
  membershipDate: string;          // ISO date
  currentStatus: MemberStatus;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface MemberStatusHistoryEntry {
  id: string;
  memberId: string;
  previousStatus: MemberStatus | null;
  newStatus: MemberStatus;
  changedAt: string;
  changedBy: string | null;
  reason: string | null;
}

export interface MemberEducation {
  id: string;
  memberId: string;
  institution: string;
  degree: string | null;
  fieldOfStudy: string | null;
  startDate: string | null;
  endDate: string | null;
  notes: string | null;
}

export interface MemberEmployment {
  id: string;
  memberId: string;
  employer: string;
  position: string | null;
  startDate: string | null;
  endDate: string | null;   // null = current position
  notes: string | null;
}

export type SkillProficiency = 'basic' | 'intermediate' | 'advanced' | 'expert';

export interface MemberSkill {
  id: string;
  memberId: string;
  skillName: string;
  proficiency: SkillProficiency | null;
}

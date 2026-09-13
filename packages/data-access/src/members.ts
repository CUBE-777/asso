import { supabase } from './supabaseClient';
import type { Member, MemberStatus, MemberStatusHistoryEntry } from '@ams/types';
import type { MemberInput } from '@ams/validation';

// The DB uses snake_case; the app uses camelCase (Section 46: shared types).
// These two small mappers are the only place that translation happens.
function rowToMember(row: any): Member {
  return {
    id: row.id,
    membershipNumber: row.membership_number,
    fullName: row.full_name,
    dateOfBirth: row.date_of_birth,
    email: row.email,
    phone: row.phone,
    address: row.address,
    photoPath: row.photo_path,
    profession: row.profession,
    associationRole: row.association_role,
    membershipDate: row.membership_date,
    currentStatus: row.current_status as MemberStatus,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  };
}

function memberInputToRow(input: Partial<MemberInput>) {
  return {
    membership_number: input.membershipNumber,
    full_name: input.fullName,
    date_of_birth: input.dateOfBirth ?? null,
    email: input.email ?? null,
    phone: input.phone ?? null,
    address: input.address ?? null,
    profession: input.profession ?? null,
    association_role: input.associationRole ?? null,
    membership_date: input.membershipDate,
    current_status: input.currentStatus,
    notes: input.notes ?? null,
  };
}

export async function listMembers(params?: { search?: string }): Promise<Member[]> {
  let query = supabase
    .from('members')
    .select('*')
    .order('created_at', { ascending: false });

  if (params?.search) {
    // Uses the members.search_vector GIN index (0009_members.sql) via
    // PostgREST's full-text search operator rather than a slow ILIKE scan.
    query = query.textSearch('search_vector', params.search, { type: 'websearch' });
  }

  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []).map(rowToMember);
}

export async function getMember(id: string): Promise<Member | null> {
  const { data, error } = await supabase.from('members').select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  return data ? rowToMember(data) : null;
}

export async function createMember(input: MemberInput): Promise<Member> {
  const { data, error } = await supabase
    .from('members')
    .insert(memberInputToRow(input))
    .select('*')
    .single();
  if (error) throw error;
  return rowToMember(data);
}

export async function updateMember(id: string, input: Partial<MemberInput>): Promise<Member> {
  const { data, error } = await supabase
    .from('members')
    .update(memberInputToRow(input))
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw error;
  return rowToMember(data);
}

export async function softDeleteMember(id: string): Promise<void> {
  const { error } = await supabase
    .from('members')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', id);
  if (error) throw error;
}

export async function getMemberStatusHistory(memberId: string): Promise<MemberStatusHistoryEntry[]> {
  const { data, error } = await supabase
    .from('member_status_history')
    .select('*')
    .eq('member_id', memberId)
    .order('changed_at', { ascending: false });
  if (error) throw error;
  return (data ?? []).map((row: any) => ({
    id: row.id,
    memberId: row.member_id,
    previousStatus: row.previous_status,
    newStatus: row.new_status,
    changedAt: row.changed_at,
    changedBy: row.changed_by,
    reason: row.reason,
  }));
}

import { supabase } from './supabaseClient';
import type { Project, ProjectStatus } from '@ams/types';
import type { ProjectInput } from '@ams/validation';

function rowToProject(row: any): Project {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    objectives: row.objectives,
    startDate: row.start_date,
    endDate: row.end_date,
    status: row.status as ProjectStatus,
    results: row.results,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  };
}

function projectInputToRow(input: Partial<ProjectInput>) {
  return {
    name: input.name,
    description: input.description ?? null,
    objectives: input.objectives ?? null,
    start_date: input.startDate ?? null,
    end_date: input.endDate ?? null,
    status: input.status,
    notes: input.notes ?? null,
  };
}

export async function listProjects(params?: { search?: string }): Promise<Project[]> {
  let query = supabase.from('projects').select('*').order('created_at', { ascending: false });

  if (params?.search) {
    query = query.textSearch('search_vector', params.search, { type: 'websearch' });
  }

  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []).map(rowToProject);
}

export async function getProject(id: string): Promise<Project | null> {
  const { data, error } = await supabase.from('projects').select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  return data ? rowToProject(data) : null;
}

export async function createProject(input: ProjectInput): Promise<Project> {
  const { data, error } = await supabase.from('projects').insert(projectInputToRow(input)).select('*').single();
  if (error) throw error;
  return rowToProject(data);
}

export async function updateProject(id: string, input: Partial<ProjectInput>): Promise<Project> {
  const { data, error } = await supabase
    .from('projects')
    .update(projectInputToRow(input))
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw error;
  return rowToProject(data);
}

// Activities belonging to a project — used on the project detail page.
export async function listActivitiesForProject(projectId: string) {
  const { data, error } = await supabase
    .from('activities')
    .select('*')
    .eq('project_id', projectId)
    .order('activity_date', { ascending: false });
  if (error) throw error;
  return (data ?? []).map((row: any) => ({
    id: row.id,
    projectId: row.project_id,
    name: row.name,
    status: row.status,
    activityDate: row.activity_date,
    location: row.location,
  }));
}

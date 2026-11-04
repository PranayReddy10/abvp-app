export interface OrgUnitRef { id: number; name: string; type?: string; label?: string }

export interface Role { role: string; label: string; org_unit: OrgUnitRef }

export interface Responsibility {
  id: number; title: string; org_unit: { id: number; name: string } | null
  vibhag: { id: number; name: string } | null; starts_on: string; ends_on: string | null; is_current: boolean
}

export interface Profile {
  member_id: string | null; full_name: string; gender: string | null; date_of_birth: string | null
  photo_url: string | null; org_unit: { id: number; name: string; label: string } | null
  institution: string | null; course: string | null; study_year: string | null; bio: string | null
  languages: string[]; skills: string[]; links: { label: string; url: string }[]
  membership_status: string; approved_at: string | null; verified?: boolean; verified_at?: string | null
  vibhags: { id: number; name: string; code: string }[]
  responsibilities: Responsibility[]
}

export interface Me {
  id: number; name: string | null; mobile: string; locale: string
  profile: Profile | null; roles: Role[]; permissions: string[]
}

export interface ApplicationRow {
  id: number; status: string; submitted_at: string | null; decided_at: string | null
  decision_note: string | null; waiting_days: number | null
  org_unit: { id: number; name: string; label: string }
  applicant: { user_id: number; name: string; mobile: string; institution: string | null }
}

export interface ApplicationDetail extends ApplicationRow {
  profile: Profile | null
  history: { action: string; note: string | null; actor: string | null; at: string }[]
}

export interface Dashboard {
  scope: OrgUnitRef | null
  approved_members: number; approved_this_month: number
  pending_applications: number; pending_over_7_days: number
  returned_for_correction: number; decided_today: number
  pending_by_unit: { org_unit: { id: number; name: string }; pending: number }[]
  recent_decisions: { action: string; actor: string | null; at: string }[]
  reported_posts?: number
}

export interface Vibhag { id: number; name: string; code: string; description: string | null; is_active: boolean; members_count?: number }

export interface Me {
  id: number
  name: string | null
  mobile: string
  email: string | null
  prant: string | null
  institution: string | null
  occupation: string | null
  gender: string | null
  is_member: boolean
  has_password?: boolean
  profile: Profile | null
  application: { status: string; submitted_at: string | null; decision_note: string | null; reviewing_office: string | null } | null
}

export interface Profile {
  full_name: string
  member_id: string | null
  photo_url: string | null
  verified?: boolean
  gender?: string | null
  date_of_birth?: string | null
  org_unit?: { id: number; name: string; label: string } | null
  institution?: string | null
  course?: string | null
  study_year?: string | null
  bio?: string | null
  membership_status?: string
  vibhags?: { id: number; name: string; code: string }[]
}

export interface OrgUnit { id: number; parent_id: number | null; type: string; name: string; children_count?: number }
export interface Vibhag { id: number; name: string; code: string; description: string | null }

export interface GuideEvent {
  id: number
  title: string
  venue: string
  starts_at: string
  ends_at: string
  cover_url: string | null
  helpline: string | null
  description: string | null
  delegate_registration_open: boolean
}

export interface GuideSummary { event: GuideEvent; open_first: boolean; live: boolean }

export interface Contact { id: number; name: string; role: string | null; is_lead: boolean; phone: string | null; verified: boolean }

export interface GuideItem {
  id: number
  kind: string
  title: string
  subtitle: string | null
  region: string | null
  description: string | null
  location: string | null
  landmark: string | null
  color: string | null
  timings: string | null
  tags: string[]
  steps: string[]
  map_url: string | null
  lat: number | null
  lng: number | null
  distance_km: number | null
  distance_is_road: boolean
  travel_time: string | null
  directions_url: string | null
  photo_urls: string[]
  videos?: { url: string | null; title: string | null; kind: 'file' | 'youtube' | 'link'; thumb_url: string | null }[]
  contacts: Contact[]
}

export interface Hub extends GuideSummary {
  sections: { kind: string; title: string; hindi: string; count: number }[]
  my_region: string | null
  my_stays: GuideItem[]
  signed_in: boolean
  open_tickets: number
}

export interface Help {
  id: number
  category: string
  category_label: string
  message: string
  status: string
  at: string
  event: { id: number; title: string }
  replies: { id: number; mine: boolean; by: string | null; from_team: boolean; body: string; at: string }[]
}

export interface Pass {
  registration_id: number
  status: string
  kind: string
  name: string
  token: string | null
  checked_in_at: string | null
  event: { id: number; title: string; venue: string; starts_at: string; ends_at: string }
}

export interface Delegate {
  event: { id: number; title: string; venue: string; starts_at: string; ends_at: string }
  open: boolean
  registration: null | {
    id: number; status: string; kind: string; full_name: string; pass_token: string | null
    details: { first_name?: string; surname?: string; mobile?: string; email?: string | null; responsibility?: string; gender?: string; prant?: string; institution?: string | null; food?: string; emergency_name?: string; emergency_phone?: string }
    travel: null | { mode: string; reference: string | null; arrival_point: string; arriving_at: string; departing_at: string | null; needs_pickup: boolean; needs_stay: boolean; notes: string | null }
  }
  prefill: { full_name: string | null; first_name?: string | null; surname?: string | null; mobile?: string | null; email?: string | null; responsibility?: string | null; gender: string | null; prant: string | null; institution: string | null }
  options: { prants: string[]; arrival_points: string[]; modes: { key: string; label: string }[]; food: { key: string; label: string }[] }
}

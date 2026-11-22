const dateFmt = new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
const timeFmt = new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' })
const numFmt = new Intl.NumberFormat('en-IN')

export const fmtDate = (iso?: string | null) => (iso ? dateFmt.format(new Date(iso)) : '–')
export const fmtTime = (iso?: string | null) => (iso ? timeFmt.format(new Date(iso)) : '–')
export const fmtNum = (n?: number | null) => (n === undefined || n === null ? '–' : numFmt.format(n))
export const initials = (name?: string | null) =>
  (name ?? '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase()).join('')

export const STATUS: Record<string, { label: string; tone: 'ok' | 'warn' | 'bad' | 'info' | 'mute' }> = {
  submitted: { label: 'Waiting', tone: 'warn' },
  more_info_required: { label: 'Returned', tone: 'warn' },
  approved: { label: 'Approved', tone: 'ok' },
  rejected: { label: 'Rejected', tone: 'bad' },
  draft: { label: 'Draft', tone: 'mute' },
  suspended: { label: 'Suspended', tone: 'bad' },
}

export const ACTION_LABEL: Record<string, string> = {
  submitted: 'Submitted by applicant',
  resubmitted: 'Resubmitted with corrections',
  approved: 'Approved',
  returned: 'Returned for correction',
  rejected: 'Rejected',
}

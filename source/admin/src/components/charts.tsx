import { useState } from 'react'
import { fmtNum } from '../format'

/** Single-series column chart with a hover tooltip. One colour, one axis. */
export function Columns({ data, unit }: { data: { label: string; full: string; value: number }[]; unit: string }) {
  const [hover, setHover] = useState<number | null>(null)
  const max = Math.max(1, ...data.map((d) => d.value))
  return (
    <div>
      <div className="cols" role="img" aria-label={data.map((d) => `${d.full}: ${d.value} ${unit}`).join(', ')}>
        {data.map((d, i) => (
          <div key={d.full} className="slot" tabIndex={0}
            onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)} onFocus={() => setHover(i)} onBlur={() => setHover(null)}>
            {hover === i && <span className="tip">{d.full}: {fmtNum(d.value)} {unit}</span>}
            <div className={`colbar ${d.value === 0 ? 'zero' : ''}`} style={{ height: `${(d.value / max) * 100}%` }} />
          </div>
        ))}
      </div>
      <div className="collabels" aria-hidden>{data.map((d) => <span key={d.full}>{d.label}</span>)}</div>
    </div>
  )
}

/** Horizontal bars for magnitude by category, value printed at the end. */
export function HBars({ rows, color = 'var(--saffron)', format = fmtNum, unit = '' }: {
  rows: { label: string; value: number; hint?: string }[]; color?: string; format?: (n: number) => string; unit?: string
}) {
  const [hover, setHover] = useState<number | null>(null)
  const max = Math.max(1, ...rows.map((r) => r.value))
  if (rows.length === 0) return <p className="muted">Nothing recorded in this period.</p>
  return (
    <div className="hbars">
      {rows.map((r, i) => (
        <div className="hbar" key={r.label} onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)}>
          <span title={r.label} style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.label}</span>
          <div className="t">
            <i style={{ width: `${(r.value / max) * 100}%`, background: color, minWidth: r.value ? 2 : 0 }} />
            {hover === i && r.hint && <span className="tip" style={{ left: `${Math.min(90, (r.value / max) * 100)}%` }}>{r.hint}</span>}
          </div>
          <b>{format(r.value)}{unit}</b>
        </div>
      ))}
    </div>
  )
}

/** Parts of a whole: one tall segmented bar with a legend that carries the numbers. */
export function Split({ parts }: { parts: { label: string; value: number; color: string }[] }) {
  const total = parts.reduce((a, p) => a + p.value, 0)
  if (!total) return <p className="muted">No data yet.</p>
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <div className="seg" role="img" aria-label={parts.map((p) => `${p.label} ${p.value}`).join(', ')}>
        {parts.filter((p) => p.value > 0).map((p) => (
          <i key={p.label} title={`${p.label}: ${fmtNum(p.value)} (${Math.round((p.value / total) * 100)}%)`} style={{ flex: p.value, background: p.color }} />
        ))}
      </div>
      <div className="legend">
        {parts.map((p) => (
          <span key={p.label}><i style={{ background: p.color }} />{p.label} <b>{fmtNum(p.value)}</b> ({Math.round((p.value / total) * 100)}%)</span>
        ))}
      </div>
    </div>
  )
}

/** Download rows as a CSV file (opens in Excel). */
export function downloadCsv(filename: string, rows: Record<string, unknown>[]) {
  if (!rows.length) return
  const cols = Object.keys(rows[0])
  const esc = (v: unknown) => {
    const s = Array.isArray(v) ? v.join('; ') : v === null || v === undefined ? '' : String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const csv = [cols.join(','), ...rows.map((r) => cols.map((c) => esc(r[c])).join(','))].join('\n')
  const url = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' }))
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

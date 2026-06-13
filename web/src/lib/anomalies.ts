import { distanceMeters, LatLng } from "@/lib/geo";

export type AnomalyType =
  | "hors-rayon"
  | "gps-imprecis"
  | "photo-manquante"
  | "sans-site"
  | "doublon"
  | "horloge";
export type AnomalySeverity = "alerte" | "info";
export interface Anomaly {
  type: AnomalyType;
  severity: AnomalySeverity;
  label: string;
}

export interface PunchForAnomaly {
  id: string;
  userId: string;
  kind: "in" | "out";
  clientTimestamp: Date;
  serverTimestamp: Date | null;
  geo: { lat: number; lng: number; accuracy: number } | null;
  siteId: string | null;
  photoStatus: "pending" | "uploaded";
}
export interface SiteRef {
  geo: LatLng | null;
  radiusMeters: number | null;
}

export interface AnomalyThresholds {
  gpsAccuracyMaxMeters: number;
  photoGraceHours: number;
  duplicateWindowMinutes: number;
  clockAheadMinutes: number;
}
export const DEFAULT_THRESHOLDS: AnomalyThresholds = {
  gpsAccuracyMaxMeters: 100,
  photoGraceHours: 24,
  duplicateWindowMinutes: 5,
  clockAheadMinutes: 10,
};

const SEVERITY: Record<AnomalyType, AnomalySeverity> = {
  "hors-rayon": "alerte",
  "sans-site": "alerte",
  horloge: "alerte",
  "gps-imprecis": "info",
  "photo-manquante": "info",
  doublon: "info",
};
const LABEL: Record<AnomalyType, string> = {
  "hors-rayon": "Hors rayon",
  "gps-imprecis": "GPS imprécis",
  "photo-manquante": "Photo manquante",
  "sans-site": "Sans site",
  doublon: "Doublon",
  horloge: "Horloge",
};
function anomaly(type: AnomalyType): Anomaly {
  return { type, severity: SEVERITY[type], label: LABEL[type] };
}

export function detectAnomalies(
  punches: PunchForAnomaly[],
  sites: Map<string, SiteRef>,
  now: Date,
  opts: Partial<AnomalyThresholds> = {},
): Map<string, Anomaly[]> {
  const t = { ...DEFAULT_THRESHOLDS, ...opts };
  const out = new Map<string, Anomaly[]>();

  for (const p of punches) {
    const list: Anomaly[] = [];

    if (p.siteId == null) list.push(anomaly("sans-site"));

    const imprecise = p.geo != null && p.geo.accuracy > t.gpsAccuracyMaxMeters;
    if (imprecise) list.push(anomaly("gps-imprecis"));

    if (p.siteId != null && p.geo != null && !imprecise) {
      const site = sites.get(p.siteId);
      if (site?.geo != null && site.radiusMeters != null) {
        const dist = distanceMeters(p.geo.lat, p.geo.lng, site.geo.lat, site.geo.lng);
        const margin = Math.max(0, p.geo.accuracy);
        if (dist - margin > site.radiusMeters) list.push(anomaly("hors-rayon"));
      }
    }

    if (p.photoStatus !== "uploaded") {
      const ageMs = now.getTime() - p.clientTimestamp.getTime();
      if (ageMs > t.photoGraceHours * 3600000) list.push(anomaly("photo-manquante"));
    }

    if (p.serverTimestamp != null) {
      const aheadMs = p.clientTimestamp.getTime() - p.serverTimestamp.getTime();
      if (aheadMs > t.clockAheadMinutes * 60000) list.push(anomaly("horloge"));
    }

    if (list.length) out.set(p.id, list);
  }

  const windowMs = t.duplicateWindowMinutes * 60000;
  for (let i = 0; i < punches.length; i++) {
    for (let j = i + 1; j < punches.length; j++) {
      const a = punches[i];
      const b = punches[j];
      if (a.userId !== b.userId || a.kind !== b.kind) continue;
      if (Math.abs(a.clientTimestamp.getTime() - b.clientTimestamp.getTime()) < windowMs) {
        for (const p of [a, b]) {
          const l = out.get(p.id) ?? [];
          if (!l.some((x) => x.type === "doublon")) l.push(anomaly("doublon"));
          out.set(p.id, l);
        }
      }
    }
  }

  return out;
}

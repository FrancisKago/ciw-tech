export interface SiteInput { name: string; lat: number; lng: number; radiusMeters: number; }
export type ParseSiteResult = { ok: true; value: SiteInput } | { ok: false; error: string };

function num(s: string | undefined): number {
  if (s === undefined || s.trim() === "") return NaN;
  return Number(s);
}

export function parseSiteForm(raw: {
  name?: string; lat?: string; lng?: string; radiusMeters?: string;
}): ParseSiteResult {
  const name = (raw.name ?? "").trim();
  if (!name) return { ok: false, error: "Le nom est requis." };
  const lat = num(raw.lat);
  const lng = num(raw.lng);
  const radiusMeters = num(raw.radiusMeters);
  if (!Number.isFinite(lat) || lat < -90 || lat > 90) return { ok: false, error: "Latitude invalide (-90 à 90)." };
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) return { ok: false, error: "Longitude invalide (-180 à 180)." };
  if (!Number.isFinite(radiusMeters) || radiusMeters <= 0) return { ok: false, error: "Le rayon doit être un nombre positif." };
  return { ok: true, value: { name, lat, lng, radiusMeters } };
}

export interface PunchLite { kind: "in" | "out"; at: Date; }
export interface HoursResult { minutes: number; anomalies: string[]; }

export function computeWorkedMinutes(punches: PunchLite[]): HoursResult {
  const sorted = [...punches].sort((a, b) => a.at.getTime() - b.at.getTime());
  let minutes = 0;
  const anomalies: string[] = [];
  let openIn: Date | null = null;
  for (const p of sorted) {
    if (p.kind === "in") {
      if (openIn) anomalies.push("in sans out");
      openIn = p.at;
    } else {
      if (!openIn) { anomalies.push("out sans in"); continue; }
      minutes += (p.at.getTime() - openIn.getTime()) / 60000;
      openIn = null;
    }
  }
  if (openIn) anomalies.push("in sans out");
  return { minutes: Math.round(minutes), anomalies };
}

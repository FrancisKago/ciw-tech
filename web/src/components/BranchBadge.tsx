import { branchMeta } from "@/lib/branches";

/** Puce de branche métier (couleur + libellé). */
export default function BranchBadge({ domaine }: { domaine?: string | null }) {
  const m = branchMeta(domaine);
  return (
    <span
      style={{ backgroundColor: m.bg, color: m.fg }}
      className="inline-block rounded px-2 py-0.5 text-xs"
    >
      {m.label}
    </span>
  );
}

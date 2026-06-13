export type Domaine = "electricite" | "informatique" | "plomberie" | "autre";
export const DOMAINES: Domaine[] = ["electricite", "informatique", "plomberie", "autre"];

export interface BranchMeta { label: string; icon: string; bg: string; fg: string; }

const META: Record<Domaine, BranchMeta> = {
  electricite: { label: "Électricité", icon: "bolt", bg: "#FBF0D6", fg: "#854F0B" },
  informatique: { label: "Informatique", icon: "device-cctv", bg: "#E1F0FA", fg: "#0C447C" },
  plomberie: { label: "Plomberie", icon: "droplet", bg: "#E1F5EE", fg: "#0F6E56" },
  autre: { label: "Autre", icon: "tools", bg: "#F1EFE8", fg: "#444441" },
};
const UNSET: BranchMeta = { label: "Non précisé", icon: "help", bg: "#F1EFE8", fg: "#5F6B78" };

export function branchMeta(d: string | undefined | null): BranchMeta {
  if (d && d in META) return META[d as Domaine];
  return UNSET;
}

"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import Logo from "@/components/Logo";

const LINKS = [
  { href: "/presence", label: "Présence" },
  { href: "/tasks", label: "Tâches" },
  { href: "/board", label: "Board" },
  { href: "/stats", label: "Stats" },
  { href: "/alertes", label: "Alertes" },
  { href: "/sites", label: "Sites" },
];

export default function Sidebar() {
  const pathname = usePathname();
  return (
    <nav className="w-48 shrink-0 border-r border-gray-200 bg-[var(--brand-bleu-nuit)] p-4 min-h-screen">
      <div className="mb-6 flex items-center gap-2">
        <Logo variant="mark" />
        <span className="text-sm font-semibold text-white">Cameroon Innovation</span>
      </div>
      <ul className="space-y-1">
        {LINKS.map((l) => {
          const active = pathname === l.href || pathname.startsWith(l.href + "/");
          return (
            <li key={l.href}>
              <Link
                href={l.href}
                className={
                  "block rounded px-3 py-2 text-sm " +
                  (active ? "bg-[var(--brand-orange)] text-white" : "text-gray-200 hover:bg-white/10")
                }
              >
                {l.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}

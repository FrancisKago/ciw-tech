"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

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
    <nav className="w-48 shrink-0 border-r border-gray-200 bg-gray-50 p-4 min-h-screen">
      <div className="mb-6 text-sm font-semibold text-gray-700">Cameroon Innovation</div>
      <ul className="space-y-1">
        {LINKS.map((l) => {
          const active = pathname === l.href || pathname.startsWith(l.href + "/");
          return (
            <li key={l.href}>
              <Link
                href={l.href}
                className={
                  "block rounded px-3 py-2 text-sm " +
                  (active ? "bg-gray-900 text-white" : "text-gray-700 hover:bg-gray-200")
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

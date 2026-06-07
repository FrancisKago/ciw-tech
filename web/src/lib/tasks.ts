export interface TaskRow {
  id: string;
  title: string;
  siteId: string;
  assigneeId: string;
  status: string;
  dueAt: string | null;
  hasReport: boolean;
}

interface TaskDoc {
  title?: string;
  siteId?: string;
  assigneeId?: string;
  status?: string;
  dueAt?: { toDate(): Date } | null;
  report?: unknown | null;
}

export function mapTaskDoc(id: string, data: TaskDoc): TaskRow {
  return {
    id,
    title: data.title ?? "",
    siteId: data.siteId ?? "",
    assigneeId: data.assigneeId ?? "",
    status: data.status ?? "assigned",
    dueAt: data.dueAt ? data.dueAt.toDate().toISOString() : null,
    hasReport: data.report != null,
  };
}

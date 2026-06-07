export interface BoardTask {
  id: string;
  title: string;
  siteId: string;
  assigneeId: string;
  status: string;
  dueAt: Date | null;
  hasReport: boolean;
}

export interface BoardColumns {
  assigned: BoardTask[];
  in_progress: BoardTask[];
  done: BoardTask[];
}

/** Une tâche est en retard si son échéance est passée et qu'elle n'est pas terminée. */
export function isLate(task: { dueAt: Date | null; status: string }, now: Date): boolean {
  if (!task.dueAt) return false;
  if (task.status === "done" || task.status === "approved") return false;
  return task.dueAt.getTime() < now.getTime();
}

/** Range les tâches par colonne. done/approved → 'done' ; tout autre statut → 'assigned'. */
export function groupByStatus(tasks: BoardTask[]): BoardColumns {
  const cols: BoardColumns = { assigned: [], in_progress: [], done: [] };
  for (const t of tasks) {
    if (t.status === "in_progress") cols.in_progress.push(t);
    else if (t.status === "done" || t.status === "approved") cols.done.push(t);
    else cols.assigned.push(t);
  }
  return cols;
}

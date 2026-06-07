export interface ReportDetail {
  text: string;
  minutesSpent: number;
  photoUrls: string[];
  photoCount: number;
  submittedAt: string | null;
}

export interface TaskRow {
  id: string;
  title: string;
  siteId: string;
  assigneeId: string;
  createdBy: string;
  status: string;
  dueAt: string | null;
  hasReport: boolean;
  report: ReportDetail | null;
  approvedBy: string | null;
  approvedAt: string | null;
}

interface TimestampLike { toDate(): Date; }

interface ReportDoc {
  text?: string;
  minutesSpent?: number;
  photoUrls?: string[];
  photoCount?: number;
  submittedAt?: TimestampLike | null;
}

interface TaskDoc {
  title?: string;
  siteId?: string;
  assigneeId?: string;
  createdBy?: string;
  status?: string;
  dueAt?: TimestampLike | null;
  report?: ReportDoc | null;
  approvedBy?: string | null;
  approvedAt?: TimestampLike | null;
}

export function mapTaskDoc(id: string, data: TaskDoc): TaskRow {
  const report: ReportDetail | null = data.report
    ? {
        text: data.report.text ?? "",
        minutesSpent: data.report.minutesSpent ?? 0,
        photoUrls: data.report.photoUrls ?? [],
        photoCount: data.report.photoCount ?? 0,
        submittedAt: data.report.submittedAt
          ? data.report.submittedAt.toDate().toISOString()
          : null,
      }
    : null;

  return {
    id,
    title: data.title ?? "",
    siteId: data.siteId ?? "",
    assigneeId: data.assigneeId ?? "",
    createdBy: data.createdBy ?? "",
    status: data.status ?? "assigned",
    dueAt: data.dueAt ? data.dueAt.toDate().toISOString() : null,
    hasReport: data.report != null,
    report,
    approvedBy: data.approvedBy ?? null,
    approvedAt: data.approvedAt ? data.approvedAt.toDate().toISOString() : null,
  };
}

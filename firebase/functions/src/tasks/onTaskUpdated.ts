import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { splitInvalidTokens } from "./onTaskAssigned";

interface TaskState { status: string; createdBy: string; assigneeId: string; }

export type StatusNotice =
  | { kind: "report_submitted"; recipientId: string }
  | { kind: "approved"; recipientId: string };

/** Décide quels push émettre selon la transition de statut. Pur, testable. */
export function routeStatusChange(before: TaskState, after: TaskState): StatusNotice[] {
  const notices: StatusNotice[] = [];
  if (before.status !== "done" && after.status === "done") {
    notices.push({ kind: "report_submitted", recipientId: after.createdBy });
  }
  if (before.status !== "approved" && after.status === "approved") {
    notices.push({ kind: "approved", recipientId: after.assigneeId });
  }
  return notices;
}

export function buildReportSubmittedMessage(taskId: string, title: string) {
  return {
    notification: { title: `Tâche terminée : ${title}`, body: "À valider au backoffice." },
    data: { taskId, kind: "report_submitted" },
  };
}

export function buildApprovedMessage(taskId: string, title: string) {
  return {
    notification: { title: `Tâche validée : ${title}`, body: "Ton rapport a été approuvé ✓" },
    data: { taskId, kind: "approved" },
  };
}

interface FcmMessage {
  notification: { title: string; body: string };
  data: { taskId: string; kind: string };
}

/** Envoie un multicast au destinataire et purge ses tokens morts. */
async function notify(recipientId: string, message: FcmMessage) {
  if (!recipientId) return;
  const userSnap = await admin.firestore().doc(`users/${recipientId}`).get();
  const tokens: string[] = userSnap.get("fcmTokens") ?? [];
  if (tokens.length === 0) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens, notification: message.notification, data: message.data,
  });
  const { invalid } = splitInvalidTokens(tokens, res.responses as never);
  if (invalid.length > 0) {
    await admin.firestore().doc(`users/${recipientId}`).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
    });
  }
}

export const onTaskUpdated = onDocumentUpdated("tasks/{taskId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const taskId = event.params.taskId;
  const title = (after.title as string) ?? "";

  const notices = routeStatusChange(before as TaskState, after as TaskState);
  for (const n of notices) {
    const message =
      n.kind === "report_submitted"
        ? buildReportSubmittedMessage(taskId, title)
        : buildApprovedMessage(taskId, title);
    await notify(n.recipientId, message);
  }
});

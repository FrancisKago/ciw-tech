import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

interface TaskLite { title: string; siteId: string; priority: string; }

export function buildAssignmentMessage(taskId: string, task: TaskLite) {
  return {
    notification: {
      title: `Nouvelle tâche : ${task.title}`,
      body: `Site ${task.siteId} · priorité ${task.priority}`,
    },
    data: { taskId },
  };
}

interface SendResponse { success: boolean; error?: { code: string }; }

/** Sépare les tokens définitivement invalides (à retirer) des autres. */
export function splitInvalidTokens(tokens: string[], responses: SendResponse[]) {
  const invalid: string[] = [];
  responses.forEach((r, i) => {
    const code = r.error?.code;
    if (!r.success &&
        (code === "messaging/registration-token-not-registered" ||
         code === "messaging/invalid-registration-token")) {
      invalid.push(tokens[i]);
    }
  });
  return { invalid };
}

export const onTaskAssigned = onDocumentCreated("tasks/{taskId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const task = snap.data() as TaskLite & { assigneeId: string };
  const taskId = event.params.taskId;

  const userSnap = await admin.firestore().doc(`users/${task.assigneeId}`).get();
  const tokens: string[] = userSnap.get("fcmTokens") ?? [];
  if (tokens.length === 0) return;

  const message = buildAssignmentMessage(taskId, task);
  const res = await admin.messaging().sendEachForMulticast({
    tokens, notification: message.notification, data: message.data,
  });

  const { invalid } = splitInvalidTokens(tokens, res.responses as never);
  if (invalid.length > 0) {
    await admin.firestore().doc(`users/${task.assigneeId}`).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
    });
  }
});

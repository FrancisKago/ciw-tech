import * as admin from "firebase-admin";
admin.initializeApp();

export { mintFirebaseToken } from "./auth/mintFirebaseToken";
export { onTaskAssigned } from "./tasks/onTaskAssigned";

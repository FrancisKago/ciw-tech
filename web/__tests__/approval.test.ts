import { canApprove } from "@/lib/approval";

describe("canApprove", () => {
  it("manager + done → true", () => expect(canApprove("manager", "done")).toBe(true));
  it("admin + done → true", () => expect(canApprove("admin", "done")).toBe(true));
  it("technician + done → false", () => expect(canApprove("technician", "done")).toBe(false));
  it("manager + in_progress → false", () => expect(canApprove("manager", "in_progress")).toBe(false));
  it("manager + approved (déjà validé) → false", () => expect(canApprove("manager", "approved")).toBe(false));
  it("rôle absent + done → false", () => expect(canApprove(undefined, "done")).toBe(false));
});

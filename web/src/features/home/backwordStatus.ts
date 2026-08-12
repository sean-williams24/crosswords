import { localDateString } from "../backword/date";
import { createBackwordStorage } from "../backword/storage";

export type DashboardStatusTone = "new" | "progress" | "solved" | "failed";

export type DashboardStatus = {
  label: string;
  tone: DashboardStatusTone;
};

export function backwordDashboardStatus(
  storage: Storage = window.localStorage,
  date = localDateString(),
  userId?: string | null
): DashboardStatus {
  const progress = createBackwordStorage(storage, { userId }).loadProgress(date);

  if (progress.outcome === "won") {
    const count = progress.guesses.length;
    return {
      label: `${count} guess${count === 1 ? "" : "es"}`,
      tone: "solved"
    };
  }

  if (progress.outcome === "failed") {
    return { label: "Failed", tone: "failed" };
  }

  if (progress.guesses.length > 0) {
    return { label: "In Progress", tone: "progress" };
  }

  return { label: "New", tone: "new" };
}

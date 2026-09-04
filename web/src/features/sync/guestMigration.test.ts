import { beforeEach, describe, expect, it } from "vitest";
import { createBackwordStorage } from "../backword/storage";
import { canMigrateGuestProgress, clearGuestMigrationOwnerIfEmpty } from "./guestMigration";

describe("guest progress migration ownership", () => {
  beforeEach(() => localStorage.clear());

  it("keeps interrupted guest progress with its first account owner", () => {
    const guestStorage = createBackwordStorage(localStorage);
    guestStorage.saveProgress({
      schemaVersion: 1,
      date: "2026-09-03",
      guesses: ["PLANET"],
      outcome: "inProgress",
      completedAt: null,
      updatedAt: "2026-09-03T10:00:00.000Z"
    });

    expect(canMigrateGuestProgress(localStorage, "account-a")).toBe(true);
    expect(canMigrateGuestProgress(localStorage, "account-b")).toBe(false);
    expect(canMigrateGuestProgress(localStorage, "account-a")).toBe(true);

    guestStorage.deleteProgress("2026-09-03");
    clearGuestMigrationOwnerIfEmpty(localStorage);

    guestStorage.saveProgress({
      schemaVersion: 1,
      date: "2026-09-04",
      guesses: ["GARDEN"],
      outcome: "inProgress",
      completedAt: null,
      updatedAt: "2026-09-04T10:00:00.000Z"
    });
    expect(canMigrateGuestProgress(localStorage, "account-b")).toBe(true);
  });
});

import { createBackwordStorage } from "../backword/storage";
import { createAnagramStorage } from "../anagram/storage";
import { createCrosswordStorage } from "../crossword/storage";
import { anagramCloudRecord, backwordCloudRecord, crosswordCloudRecord, type CloudRecord } from "../sync/progressSync";

export type LocalProfileRecords = {
  backword: CloudRecord<unknown>[];
  dailyCrossword: CloudRecord<unknown>[];
  weeklyCrossword: CloudRecord<unknown>[];
  anagram: CloudRecord<unknown>[];
};

/**
 * Builds the same account-scoped record set used by Player Profile. Keeping
 * this local means a just-completed game is reflected before cloud sync ends.
 */
export function loadLocalProfileRecords(userId?: string): LocalProfileRecords {
  const backwordStorage = createBackwordStorage(window.localStorage, { userId });
  const anagramStorage = createAnagramStorage(window.localStorage, { userId });
  const dailyCrosswordStorage = createCrosswordStorage(window.localStorage, { userId });
  const weeklyCrosswordStorage = createCrosswordStorage(window.localStorage, {
    kind: "weekly",
    userId
  });

  return {
    backword: backwordStorage.loadAllProgress().map(backwordCloudRecord),
    anagram: anagramStorage.loadAllProgress().map(anagramCloudRecord),
    dailyCrossword: dailyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress)),
    weeklyCrossword: weeklyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress, "weekly"))
  };
}

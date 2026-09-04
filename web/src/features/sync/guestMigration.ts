import { createBackwordStorage } from "../backword/storage";
import { createCrosswordStorage } from "../crossword/storage";

const guestMigrationOwnerKey = "backword:web:sync:guest-migration-owner:v1";

function hasGuestProgress(storage: Storage) {
  return createBackwordStorage(storage).loadAllProgress().length > 0
    || createCrosswordStorage(storage).loadAllProgress().length > 0;
}

/**
 * Gives a guest save namespace one account owner before it can be uploaded.
 * If a migration is interrupted, only its original owner may retry it; a
 * second sign-in on the same browser cannot copy those saves into another
 * account.
 */
export function canMigrateGuestProgress(storage: Storage, userId: string) {
  if (!hasGuestProgress(storage)) {
    storage.removeItem(guestMigrationOwnerKey);
    return false;
  }

  const owner = storage.getItem(guestMigrationOwnerKey);
  if (owner) return owner === userId;

  storage.setItem(guestMigrationOwnerKey, userId);
  return true;
}

/** Clears the ownership marker only after every migrated guest record is gone. */
export function clearGuestMigrationOwnerIfEmpty(storage: Storage) {
  if (!hasGuestProgress(storage)) storage.removeItem(guestMigrationOwnerKey);
}

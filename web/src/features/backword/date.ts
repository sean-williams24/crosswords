export function localDateString(date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function localDateOffset(dateString: string, offset: number): string {
  const [year, month, day] = dateString.split("-").map(Number);
  const date = new Date(year, month - 1, day + offset, 12);
  return localDateString(date);
}

export function isCompletedOnReleaseDate(
  date: string,
  completedAt: string | null
): boolean {
  if (!completedAt) {
    return false;
  }
  const completionDate = new Date(completedAt);
  return !Number.isNaN(completionDate.getTime()) && localDateString(completionDate) === date;
}

export function localWeekStartString(date = new Date()): string {
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate() - date.getDay(), 12);
  return localDateString(start);
}

export function localWeekOffset(dateString: string, offset: number): string {
  return localDateOffset(dateString, offset * 7);
}

export function isCompletedInWeeklyReleaseWindow(date: string, completedAt: string | null): boolean {
  if (!completedAt) return false;
  const completionDate = new Date(completedAt);
  return !Number.isNaN(completionDate.getTime()) && localWeekStartString(completionDate) === date;
}

export function secondsUntilNextLocalMidnight(now = new Date()): number {
  const midnight = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate() + 1,
    0,
    0,
    0,
    0
  );
  return Math.max(0, Math.ceil((midnight.getTime() - now.getTime()) / 1000));
}

export function secondsUntilNextLocalSunday(now = new Date()): number {
  const nextSunday = new Date(now.getFullYear(), now.getMonth(), now.getDate() + (7 - now.getDay()), 0, 0, 0, 0);
  return Math.max(0, Math.ceil((nextSunday.getTime() - now.getTime()) / 1000));
}

export function countdownText(secondsRemaining: number): string {
  const seconds = Math.max(0, Math.ceil(secondsRemaining));
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainder = seconds % 60;
  return [hours, minutes, remainder]
    .map((value) => String(value).padStart(2, "0"))
    .join(":");
}

export function weeklyCountdownText(secondsRemaining: number): string {
  const seconds = Math.max(0, Math.ceil(secondsRemaining));
  const days = Math.floor(seconds / 86_400);
  return `${days}d ${countdownText(seconds % 86_400)}`;
}

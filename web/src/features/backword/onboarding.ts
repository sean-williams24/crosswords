import type { BackwordMode, BackwordOnboardingStep, BackwordSettings } from "./types";

export const BACKWORD_ONBOARDING_STEPS: readonly BackwordOnboardingStep[] = [
  "clue",
  "connectedLetters",
  "freeReveals",
  "scoring",
  "stuckHint"
];

export function pendingBackwordOnboardingSteps(settings: BackwordSettings): BackwordOnboardingStep[] {
  if (settings.hasSeenOnboarding) return [];
  return BACKWORD_ONBOARDING_STEPS.filter((step) => !settings.dismissedOnboardingSteps.includes(step));
}

export function backwordOnboardingText(step: BackwordOnboardingStep, mode: BackwordMode): string {
  switch (step) {
    case "clue":
      return "The clue is a word associated with the answer, or something connected to it";
    case "connectedLetters":
      return "Correctly placed letters reveal when they form an unbroken chain from the back of the word.";
    case "freeReveals":
      return mode === "normal"
        ? "If your guesses do not extend that chain, the second and third wrong guesses each reveal one more letter from the end."
        : "If your guesses do not extend that chain, each wrong guess reveals one more letter from the back of the word.";
    case "scoring":
      return "The fewer guesses you need, the more points you score.";
    case "stuckHint":
      return "If you're stuck, guess any word to reveal a letter.";
  }
}

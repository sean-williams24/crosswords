import { describe, expect, it } from "vitest";
import { functionFailureDiagnostic } from "../../../../Backend/supabase/functions/_shared/functionFailure.ts";

describe("functionFailureDiagnostic", () => {
  it("keeps a Supabase-style plain-object error message and code for server logs", () => {
    expect(functionFailureDiagnostic({
      code: "23505",
      details: "must not be logged",
      hint: "must not be logged",
      message: "duplicate key value violates unique constraint"
    })).toEqual({
      code: "23505",
      message: "duplicate key value violates unique constraint"
    });
  });

  it("uses a non-Error fallback when no safe message is available", () => {
    expect(functionFailureDiagnostic(null)).toEqual({ message: "Unknown non-Error failure" });
  });
});

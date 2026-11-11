import { readFileSync } from "node:fs";
import { parse } from "postcss";
import { describe, expect, it } from "vitest";

describe("crossword completion grid layout", () => {
  it("centres both grid sizes and lets the sheet show through empty cells", () => {
    const stylesheet = parse(readFileSync("src/styles.css", "utf8"));
    const declarations = (selector: string) => {
      const properties = new Map<string, string>();
      stylesheet.walkRules(selector, (rule) => {
        if (rule.selector === selector) {
          rule.walkDecls((declaration) => properties.set(declaration.prop, declaration.value));
        }
      });
      return properties;
    };

    const grid = declarations(".cw-completion-grid");
    const weekly = declarations(".cw-completion-grid--weekly");
    const blackCell = declarations(".cw-completion-grid > .is-black");

    expect(grid.get("align-self")).toBe("center");
    expect(weekly.has("align-self")).toBe(false);
    expect(grid.has("background")).toBe(false);
    expect(blackCell.get("background")).toBe("transparent");
  });
});

# Project Guidelines

## Architecture

This is a SwiftUI iOS app (minimum iOS 16) following the **MVVM pattern**.

- **Views** (`Crosswords/Views/`) — SwiftUI views only; no business logic
- **ViewModels** (`Crosswords/ViewModels/`) — `@MainActor ObservableObject` classes; owns state and async logic
- **Models** (`Crosswords/Models/`) — Plain data types (`Codable`, `Identifiable`)
- **Services** (`Crosswords/Services/`) — Network/persistence layer; injected as `@EnvironmentObject`
- **Backend** (`Backend/`) — Python scripts for puzzle generation and Supabase uploads; has its own `.venv`

## Code Style

- **Extract components to their own files.** If a view or sub-component can be reused, or is non-trivial, put it in its own `.swift` file in the appropriate folder — do not keep adding new components inline to existing views.
- Keep `View` bodies small. Extract sub-views into `private` computed properties or dedicated `struct`s, then move to a separate file when they grow.
- Use `AppFont`, `AppLayout`, and semantic colors (`appAccent`, `appTextPrimary`, etc.) from the theme — never hardcode fonts, sizes, or raw `Color` values.
- Prefer `@EnvironmentObject` for services over passing them through initialisers.

## Build & Run

**VS Code (recommended shortcut):** `⌘⇧R` — runs the "Run on Simulator" task (builds with `xcodebuild` and launches on iPhone 17 Pro simulator `BB3AB980-D434-4D78-9FAB-AA2C277F5C1F`).

**Xcode:** Open `Crosswords.xcodeproj`, select the `Crosswords` scheme, and run on any simulator or device.

**Backend scripts:**
```bash
cd Backend
source .venv/bin/activate
set -a && source .env && set +a
python3 <script>.py
```

## Testing

- All new code and changes **must include unit tests**.
- Test files go in `CrosswordsTests/` (create if it doesn't exist yet).
- Use Swift Testing (`@Test`, `@Suite`) for new test files; XCTest is acceptable for expansions to existing files.
- Test ViewModels and Services directly; do not write UI tests unless testing a specific interaction.
- Run tests via `⌘U` in Xcode or `xcodebuild test` from the terminal.

## Commits

Use **Conventional Commits** format:

```
feat: add weekly puzzle streak tracking
fix: correct progress bar cell count excluding black cells
refactor: extract PuzzleCardView to its own file
chore: update Supabase API key
```

Types: `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `style`

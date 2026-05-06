# App Conventions

Key logic decisions, rules, and non-obvious behaviours across the codebase. Add a section whenever a meaningful decision is made that future contributors (or AI) should understand.

---

## Timezone & Date Handling

### Puzzle dates are plain calendar dates

All puzzle dates are stored and queried as plain `yyyy-MM-dd` strings with no time or timezone component. Supabase stores them as a Postgres `date` column. The `lte` filter in queries is a pure calendar-date string comparison — no timestamp arithmetic involved.

### UTC as the canonical "today"

All services (`PuzzleService`, `WOTDService`, `BackwordService`, `OverallRatingService`) derive "today's" date string using a `DateFormatter` with `timeZone = TimeZone(identifier: "UTC")`. This means:

- The app's concept of "today" flips at **UTC midnight**, not local midnight.
- For a BST (UTC+1) user, new content becomes available at **1:00 AM local time**.
- For users behind UTC (e.g. EDT, UTC−4), content is already available before their local midnight.

**Why UTC?** The Supabase query sends `date=lte.<today>` where `<today>` is the UTC date string. A BST user querying at 00:30 local (= 23:30 UTC) must send `2026-05-06`, not `2026-05-07`, otherwise the server returns the next day's puzzle before it's intended to be live. Using local time would create this mismatch.

### Midnight refresh task (`HomeView`)

`HomeView` runs a background `Task` that sleeps until UTC midnight then triggers a full refresh of all content. The `secondsUntilMidnight()` helper **must** use a UTC calendar — `Calendar.current` would fire at local midnight, one hour too early for BST users:

```swift
private func secondsUntilMidnight() -> TimeInterval? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    guard let midnight = calendar.nextDate(
        after: Date(),
        matching: DateComponents(hour: 0, minute: 0, second: 0),
        matchingPolicy: .nextTime
    ) else { return nil }
    return midnight.timeIntervalSinceNow
}
```

### "TODAY" label vs. "Until X:XX AM" hint (`RatingDetailSheet`)

Scores are stored against UTC date keys, but the "TODAY" label uses the **device's local timezone** so it matches what the user's clock shows:

```swift
private static let localDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    // No timeZone — uses device local timezone
    return f
}()

let isToday = day.date == Self.localDateFormatter.string(from: Date())
```

During the UTC-ahead window (e.g. 00:00–01:00 BST), local-today and UTC-today differ. In this case no row shows "TODAY"; instead the UTC-today row shows an "Until X:XX AM" hint. This is computed by finding the next UTC midnight and formatting it in local time — iOS handles the timezone conversion automatically:

```swift
private var deadlineTime: String? {
    guard Self.localDateFormatter.string(from: Date()) != OverallRating.dateFormatter.string(from: Date())
    else { return nil }
    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(identifier: "UTC")!
    guard let utcMidnight = utcCal.nextDate(
        after: Date(),
        matching: DateComponents(hour: 0, minute: 0, second: 0),
        matchingPolicy: .nextTime
    ) else { return nil }
    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm a"
    return fmt.string(from: utcMidnight) // Displayed in device local time
}
```

### Formatter reference table

| Use case | Timezone |
|---|---|
| Querying Supabase / cache keys | UTC |
| Storing scores (`OverallRating`) | UTC |
| "TODAY" label detection | Local (device) |
| "Until X:XX AM" deadline display | Local (DateFormatter default) |
| Human-readable date strings (e.g. "Wed, May 6") | Local (DateFormatter default) |

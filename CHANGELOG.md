## 1.0.0

- Initial version.

## 1.0.1

- Add Comment.

## 1.0.2

- Optimization function.

## 1.0.3

- Fix bug.

## 1.0.5

- Add caller-provided App version support for traffic snapshots.
    - Added `FlutterTrafficStats.setAppVersion(String? appVersion)` so host apps can attach their
      own version string to generated traffic statistics.
    - Added the top-level `appVersion` field to `TrafficStatsSnapshot.toJson()`, placed alongside
      `generatedAt`, `totals`, and `items`.
    - Kept `TrafficStatsSnapshot.fromJson()` compatible with older locally persisted snapshots that
      do not contain `appVersion`.
- Improve snapshot generation consistency.
    - Reuse the snapshot generation time when calculating snapshot size and creating the final
      `TrafficStatsSnapshot`.
    - Include `appVersion` in the estimated `snapshotBytes` payload size.
- Document App version usage.
    - Updated README and example startup code to show
      `FlutterTrafficStats.setAppVersion('1.0.0+100')`.
- Add regression coverage.
    - Added a snapshot test to verify trimming, serialization, and deserialization of the
      caller-provided App version.

## 1.0.6

- Traffic Consumption Diagnosis Details.
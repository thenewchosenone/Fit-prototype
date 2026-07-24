# Product Consistency Checklist

LiftRank should show the same product concept with the same source of truth everywhere. If two screens disagree, the bug is usually duplicated formatting, duplicated derivation, or asymmetric save/load mapping.

## Profile identity

- Username is the stable handle and should display as `@username` outside editable forms.
- Display name is the primary human-readable name and should not be duplicated as a second unlabeled username field.
- Profile photo is account-backed for authenticated users: image bytes live in Supabase Storage, `profiles.avatar_path` stores the storage path, and the local file cache is only a cache.
- Age group is derived from birth date with `ProfileDisplayFormatting.ageGroup(for:)`.
- Division uses `SexCategory`; user-facing labels should say `Division` unless the context is specifically category selection.
- Experience is earned from verified lifts and relative total; users should not manually choose it.

## Location

- Country, region, and city are selected from canonical location data.
- Free-typed city text must resolve to an available canonical city before save.
- Display city/state as `City, Region` when visible.
- If hidden or missing, use explicit hidden/missing copy instead of demo placeholders.

## Strength and ranking

- Strength score tier uses `RankingFormatting.strengthTier(for:)`.
- Earned experience uses `RankingFormatting.earnedExperienceLevel(...)`.
- Empty real leaderboards should show `Unranked`, not fake ranks or percentiles.
- Percentile copy is only allowed when backed by leaderboard data.
- Hidden gym/launch-hidden gym features must not show `Gym #` remnants.
- Gym search, gym filters, and `My gym` shortcuts are shown only when `FeatureAvailability.gymFeeds` is enabled.
- Gym privacy controls are shown only when `FeatureAvailability.gymFeeds` is enabled.
- Profile rank cards must never show placeholder percentiles such as `Top 9%`; use `Unranked` until backed by ranking data.

## Training

- Workout set weights are recorded-unit values. Display with `MeasurementFormatting.formatRecordedWeight(...)`.
- Ranking, PR, and leaderboard weights are normalized kilograms internally and converted only at display boundaries.
- Bodyweight is stored as pounds on profile/bodyweight logs; onboarding, edit profile, Home, Profile, and Progress must display/edit it through the user’s preferred unit.
- Bodyweight logged from Home and Progress must use the same `BodyweightEntryEditor` and repository upsert path.
- Workout calendar, weekly cards, summary, and completed details must all read from completed workout/set sources consistently.

## Media

- Profile avatars: Supabase Storage is authoritative for authenticated accounts; local cache is disposable.
- Lift videos: server/storage state is authoritative for submitted public evidence; local URLs are temporary until uploaded.
- Removing media must clear both the account-backed reference and local cache when applicable.

## Implementation rules

- Prefer shared formatters over inline string math.
- Prefer one save/load mapper per concept.
- If a field appears in onboarding and edit profile, verify it round-trips through the same domain field.
- If a number can be pounds or kilograms, function names must say whether the input is recorded, pounds, or kilograms.
- Settings privacy shortcuts must preserve the granular `ProfilePrivacySettings` audiences used by Edit Profile and Supabase.

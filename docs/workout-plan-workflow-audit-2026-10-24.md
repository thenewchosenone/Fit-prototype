# Workout plan creation audit — October 24, 2026

## Request and verified result

Create Winter Volume V2 on Robert's personal iPhone, using his latest three freestyle workouts, for 12 weeks and six training days per week. User authorized continuing with supported parts while documenting blockers.

Used iPhone Mirroring and the installed production Release build from c01d8ba. Created and selected Winter Volume V2, then used Clone Week eleven times. The app visibly shows 12 scheduled weeks. Week 12's overview shows three workouts and 49 planned working sets. Returned the selected week to Week 1.

Source workouts shown by Latest 3:

| Source date shown on phone | Routine | Exercises | Working sets |
| --- | --- | --- | --- |
| Oct 22, 2026, 2:17 AM | Pull | 5 | 16 |
| Oct 22, 2026, 9:51 PM | Push | 8 | 22 |
| Oct 23, 2026, 2:41 AM | Legs | 4 | 11 |

Saved schedule is Monday Pull — Back & Biceps, Tuesday Push — Chest, Shoulders & Triceps, Friday Workout 3 (legs). This is a partial result: six days per week is **not implemented**. Intended final schedule is pull/push/legs Monday through Saturday, Sunday off. The 12 weeks repeat the same prescriptions; no progressive loading or deload schedule was configured. Server-side sync and persistence after relaunch were not independently verified.

## Findings and recommended changes

1. **High: no duration control when creating from history.** Creation silently makes one week. Achieving 12 weeks required eleven separate Clone Week operations. Add a duration field and generate the repeated schedule once, with a summary before save. The existing phase-duration state is not exposed or passed through the history-creation path.
2. **High: no repeat/duplicate workout control.** A source workout can be selected only once. The review has rename, weekday, order, and prescription editing; the saved workout menu offers edit and delete, without duplicate. A six-day split from three source workouts requires manually reconstructing the other three sessions. Add duplication in review and saved workout options, including destination weekdays.
3. **Medium: source dates become the schedule without conflict feedback.** The initial review put both upper-body sessions on Thursday. Add duplicate-day feedback and offer to distribute selected workouts over chosen weekdays. Preserve manual scheduling choices.
4. **Medium: plan activation and week selection are implicit.** Saving immediately selects the new plan; cloning switches to the new last week. The overview then labels Week 12 as the current week even though none were started. Distinguish the viewed week from the next unfinished training week, and make activation explicit in the save summary.
5. **Medium: review omits the complete plan summary.** There is no prominent summary of weeks, days per week, total workouts, weekly sets, progression, or start date. Show these before saving, particularly for repeated routines.
6. **Medium: progression is unavailable in this custom-plan flow.** Repeating a week copies the prescriptions; it does not establish a progression policy. Offer an explicit repeat-as-written choice or supported progression settings rather than implying progression exists.
7. **Automation limitation: text replacement through Mirroring was unreliable.** Pull/push names and the plan title saved correctly, but the attempted leg rename produced malformed text and subsequent replacement did not apply. Removed that draft from the selection, reviewed, then reselected the original source to restore the default Workout 3 name before saving. This was not established as an app defect. Do not confuse it with workout-data corruption.

## What worked

- Latest 3 selected the three most recent eligible freestyle workouts.
- Source cards showed dates, duration, exercise previews, and working-set counts.
- Review allowed names and weekday changes before saving.
- Back preserved the retained draft workouts and their edited names/schedule.
- Week cloning preserved the routine; Week 12 showed three workouts and 49 planned sets, matching the source totals.
- The overview's Review unfinished week action returned to Week 1.

No application source, dependencies, migrations, or original workout records were intentionally modified during this audit. This report is the only new workspace file.

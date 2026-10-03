# To-do

- [x] Finish the exercise-library icon audit and validate replacements for 45-Degree Linear Leg Press, Back Extension Machine, Band Face Pull, Band Lat Pulldown, and Barbell Overhead Press.
- [x] Review the tracker screen for first-time-user clarity after the icon pass: no-plan guidance, program browsing, and accessible plan controls are now explicit.
- [x] Clarify the tracker home header: “Workout Plan” should explain or guide users when no program has been selected.
- [x] Audit every workout plan against its title and intended training style: exercise selection, rep ranges, RIR guidance, percentage work, progression, and powerlifting specificity.
- [x] Fix the workout calendar to support navigating to any prior/future month, preserve empty months, and align every day to the real calendar grid; verify October 2026 includes October 1–31 correctly.
- [x] Audit bodyweight entry validation and copy: clarify why actual bodyweight is marked optional, or make it required when saving a bodyweight entry.
- [x] Verify “Find Your Gym” in both demo and production: demo behavior is covered by the mock directory and location-filter regression; the production catalog currently has 991 active gyms, including 10 in Miami, so an empty state indicates loading/error state rather than missing catalog data.
- [x] Condense the Submit a Lift flow: required lift, context, and video controls remain visible while estimated-max and plate-loading details are grouped behind one collapsed “More details” section.
- [x] Audit the Privacy Notice, Terms of Use, and Fitness Disclaimer against the production feature set: current in-app copies cover the implemented data/features and pass the coverage test. Legal sign-off remains an external release gate.
- [x] Enable forum browsing in the simulator/demo build without requiring production account services; verify read-only forum access in the next build.
- [x] Expand the awards catalog from roughly 100–105 to about 200: audit existing awards, remove overlap, and add balanced milestones for consistency, strength, volume, technique, exploration, and community engagement.
- [x] Fix RPE chip contrast in the workout tracker, especially RPE 7: the number must remain readable in both selected and unselected states and meet accessible contrast expectations.
- [x] Remove the ambiguous “Best set” card from workout summary; a bare weight × reps result lacks exercise context and unclear scoring criteria.
- [x] Restore workout-completion celebrations for meaningful milestones, including new PRs, volume PRs, and other unlocked achievements.

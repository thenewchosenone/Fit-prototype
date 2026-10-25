import { describe, expect, it } from "vitest";
import { seedState } from "../src/data";
import { exerciseMatchesFilters, searchExercises } from "../src/exerciseSearch";
import { primaryMuscleForExercise, secondaryMusclesForExercise } from "../src/platform";

describe("exercise discovery", () => {
  it("orders exact names, aliases, prefixes, and metadata matches by relevance", () => {
    const exact = searchExercises(seedState.exercises, "Back Squat");
    expect(exact[0]).toMatchObject({ exercise: { id: "back-squat" }, score: 700, reason: "Exact exercise name" });

    const alias = searchExercises(seedState.exercises, "Hammer Strength D.Y. Row");
    expect(alias[0]).toMatchObject({ exercise: { name: "Iso-Lateral Underhand Row" }, score: 650 });
    expect(alias[0].reason).toContain("Known as");

    const prefix = searchExercises(seedState.exercises, "Dumbbell Bench");
    expect(prefix[0].exercise.name).toBe("Dumbbell Bench Press");
    expect(prefix[0].score).toBe(600);

    const equipment = searchExercises(seedState.exercises, "Cable");
    expect(equipment.length).toBeGreaterThan(10);
    expect(equipment.every((match) => match.exercise.equipment === "Cable" || match.exercise.name.toLowerCase().includes("cable") || match.exercise.searchAliases?.some((aliasName) => aliasName.toLowerCase().includes("cable")))).toBe(true);
  });

  it("uses OR within filter groups and AND between groups", () => {
    const filters = {
      bodyRegions: ["Back", "Chest"],
      primaryMuscles: [],
      equipment: ["Cable", "Bodyweight"],
      movementTypes: ["Vertical Pull"],
      trackingTypes: []
    };
    const matches = seedState.exercises.filter((exercise) => exerciseMatchesFilters(exercise, filters));
    expect(matches.map((exercise) => exercise.name)).toEqual(expect.arrayContaining(["Lat Pulldown", "Pull-Up"]));
    expect(matches.every((exercise) => ["Back", "Chest"].some((region) => (exercise.bodyRegions ?? [exercise.bodyPart]).includes(region)))).toBe(true);
    expect(matches.every((exercise) => ["Cable", "Bodyweight"].includes(exercise.equipment))).toBe(true);
    expect(matches.every((exercise) => exercise.movementType === "Vertical Pull")).toBe(true);
  });

  it("never repeats a primary muscle as an also-worked muscle", () => {
    for (const exercise of seedState.exercises) {
      const primary = primaryMuscleForExercise(exercise).toLowerCase();
      expect(secondaryMusclesForExercise(exercise).map((muscle) => muscle.toLowerCase())).not.toContain(primary);
    }
  });
});

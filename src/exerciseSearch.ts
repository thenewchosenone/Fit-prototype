import { primaryMuscleForExercise, secondaryMusclesForExercise } from "./platform";
import type { Exercise } from "./types";

export interface ExerciseSearchMatch {
  exercise: Exercise;
  score: number;
  reason: string | null;
}

const normalize = (value: string) => value
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, " ")
  .trim()
  .replace(/\s+/g, " ");

const words = (value: string) => normalize(value).split(" ").filter(Boolean);

export function scoreExerciseSearch(exercise: Exercise, rawQuery: string): ExerciseSearchMatch | null {
  const query = normalize(rawQuery);
  if (!query) return { exercise, score: 0, reason: null };

  const name = normalize(exercise.name);
  const aliases = (exercise.searchAliases ?? []).map((alias) => ({ raw: alias, normalized: normalize(alias) }));
  const queryWords = words(query);

  if (name === query) return { exercise, score: 700, reason: "Exact exercise name" };
  const exactAlias = aliases.find((alias) => alias.normalized === query);
  if (exactAlias) return { exercise, score: 650, reason: `Known as ${exactAlias.raw}` };
  if (name.startsWith(query)) return { exercise, score: 600, reason: "Name starts with your search" };
  if (queryWords.every((word) => name.split(" ").some((token) => token.startsWith(word)))) {
    return { exercise, score: 550, reason: "All search words match the name" };
  }

  const aliasMatch = aliases.find((alias) =>
    alias.normalized.startsWith(query) || queryWords.every((word) => alias.normalized.split(" ").some((token) => token.startsWith(word)))
  );
  if (aliasMatch) return { exercise, score: 500, reason: `Alias match: ${aliasMatch.raw}` };

  const primary = normalize(primaryMuscleForExercise(exercise));
  const equipment = normalize(exercise.equipment);
  const movement = normalize(exercise.movementType);
  const bodyRegions = (exercise.bodyRegions ?? [exercise.bodyPart]).map(normalize);
  if ([primary, equipment, movement, ...bodyRegions].some((value) => value.includes(query) || query.includes(value))) {
    const label = primary.includes(query) ? "primary muscle" : equipment.includes(query) ? "equipment" : movement.includes(query) ? "movement pattern" : "body region";
    return { exercise, score: 400, reason: `Matches ${label}` };
  }

  const secondary = secondaryMusclesForExercise(exercise).find((muscle) => normalize(muscle).includes(query));
  if (secondary) return { exercise, score: 300, reason: `Secondary muscle: ${secondary}` };

  return null;
}

export function searchExercises(exercises: Exercise[], query: string): ExerciseSearchMatch[] {
  return exercises
    .map((exercise, index) => ({ match: scoreExerciseSearch(exercise, query), index }))
    .filter((item): item is { match: ExerciseSearchMatch; index: number } => item.match !== null)
    .sort((a, b) => b.match.score - a.match.score || a.index - b.index)
    .map((item) => item.match);
}

export function exerciseMatchesFilters(exercise: Exercise, filters: {
  bodyRegions: string[];
  primaryMuscles: string[];
  equipment: string[];
  movementTypes: string[];
  trackingTypes: string[];
}): boolean {
  const regions = exercise.bodyRegions?.length ? exercise.bodyRegions : [exercise.bodyPart];
  return (
    (!filters.bodyRegions.length || filters.bodyRegions.some((region) => regions.includes(region))) &&
    (!filters.primaryMuscles.length || filters.primaryMuscles.includes(primaryMuscleForExercise(exercise))) &&
    (!filters.equipment.length || filters.equipment.includes(exercise.equipment)) &&
    (!filters.movementTypes.length || filters.movementTypes.includes(exercise.movementType)) &&
    (!filters.trackingTypes.length || filters.trackingTypes.includes(exercise.trackingType))
  );
}

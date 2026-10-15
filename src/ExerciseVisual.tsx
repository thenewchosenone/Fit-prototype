import type { Exercise } from "./types";

const muscleAssets = import.meta.glob<string>("./assets/muscles/*.{avif,png}", {
  eager: true,
  query: "?url",
  import: "default"
});

function muscleAsset(name: string, extension: "avif" | "png") {
  return muscleAssets[`./assets/muscles/${name}.${extension}`];
}

export function muscleVisualKey(exercise: Pick<Exercise, "bodyPart" | "bodyRegions">): string {
  const region = `${exercise.bodyPart} ${(exercise.bodyRegions ?? []).join(" ")}`.toLowerCase();
  if (region.includes("chest")) return "chest";
  if (region.includes("back")) return "back";
  if (region.includes("shoulder")) return "shoulders";
  if (region.includes("arm") || region.includes("bicep") || region.includes("tricep") || region.includes("forearm")) return "arms";
  if (region.includes("quad")) return "quads";
  if (region.includes("hamstring")) return "hamstrings";
  if (region.includes("glute")) return "glutes";
  if (region.includes("calf") || region.includes("calves")) return "calves";
  if (region.includes("core") || region.includes("ab")) return "core";
  return "full-body";
}

export function BodyRegionGlyph({ exercise }: { exercise: Exercise }) {
  const key = muscleVisualKey(exercise);
  return <picture>
    <source srcSet={muscleAsset(key, "avif")} type="image/avif" />
    <img className="exercise-glyph muscle-visual" src={muscleAsset(key, "png")} alt={`${exercise.name}: ${exercise.bodyPart} muscles highlighted`} width="512" height="512" loading="lazy" decoding="async" />
  </picture>;
}

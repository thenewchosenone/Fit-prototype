import { Maximize2, Pause, Play } from "lucide-react";
import { useRef, useState } from "react";
import demoCore from "../LiftRankApp/Resources/DemoMedia/demo-core.gif";
import demoCurl from "../LiftRankApp/Resources/DemoMedia/demo-curl.gif";
import demoExtension from "../LiftRankApp/Resources/DemoMedia/demo-extension.gif";
import demoHinge from "../LiftRankApp/Resources/DemoMedia/demo-hinge.gif";
import demoHorizontalPress from "../LiftRankApp/Resources/DemoMedia/demo-horizontal-press.gif";
import demoHorizontalPull from "../LiftRankApp/Resources/DemoMedia/demo-horizontal-pull.gif";
import demoLunge from "../LiftRankApp/Resources/DemoMedia/demo-lunge.gif";
import demoShoulder from "../LiftRankApp/Resources/DemoMedia/demo-shoulder.gif";
import demoSquat from "../LiftRankApp/Resources/DemoMedia/demo-squat.gif";
import demoVerticalPress from "../LiftRankApp/Resources/DemoMedia/demo-vertical-press.gif";
import demoVerticalPull from "../LiftRankApp/Resources/DemoMedia/demo-vertical-pull.gif";
import demoBench from "../LiftRankApp/Resources/DemoMedia/demo-leaderboard-bench.gif";
import demoDeadlift from "../LiftRankApp/Resources/DemoMedia/demo-leaderboard-deadlift.gif";
import demoCompetitionSquat from "../LiftRankApp/Resources/DemoMedia/demo-leaderboard-squat.gif";
import { BodyRegionGlyph } from "./ExerciseVisual";
import type { Exercise } from "./types";

export function exerciseDemoSource(exercise: Exercise): string {
  const name = exercise.name.toLowerCase();
  if (exercise.id === "barbell-bench") return demoBench;
  if (exercise.id === "back-squat") return demoCompetitionSquat;
  if (exercise.id === "deadlift") return demoDeadlift;
  if (/curl/.test(name)) return demoCurl;
  if (/extension|pushdown|skull crusher/.test(name)) return demoExtension;
  if (/lunge|step-up|split squat/.test(name)) return demoLunge;
  if (exercise.movementType === "Squat") return demoSquat;
  if (exercise.movementType === "Hinge") return demoHinge;
  if (exercise.movementType === "Horizontal Push") return demoHorizontalPress;
  if (/horizontal pull|row/i.test(exercise.movementType) || /row/.test(name)) return demoHorizontalPull;
  if (/vertical pull/i.test(exercise.movementType) || /pulldown|pull-up|chin-up/.test(name)) return demoVerticalPull;
  if (/vertical push/i.test(exercise.movementType)) return demoVerticalPress;
  if (exercise.bodyPart === "Shoulders") return demoShoulder;
  return demoCore;
}

export function ExerciseDemo({ exercise }: { exercise: Exercise }) {
  const figureRef = useRef<HTMLElement>(null);
  const [paused, setPaused] = useState(() => typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches);
  const source = exerciseDemoSource(exercise);
  const enterFullscreen = async () => {
    if (figureRef.current?.requestFullscreen) await figureRef.current.requestFullscreen();
  };
  return (
    <figure ref={figureRef} className="exercise-demo">
      <div className="demo-media-stage">
        {paused ? <BodyRegionGlyph exercise={exercise} /> : <img src={source} alt={`${exercise.name} movement demonstration`} loading="lazy" decoding="async" />}
        <span className="demo-media-label">Demo Media</span>
      </div>
      <figcaption><div><strong>{exercise.name} demonstration</strong><small>Illustrative movement reference—not verification evidence.</small></div><div><button type="button" className="quiet-button compact" onClick={() => setPaused((value) => !value)}>{paused ? <Play size={15} /> : <Pause size={15} />}{paused ? "Play" : "Pause"}</button><button type="button" className="icon-button" aria-label="View demonstration full screen" onClick={() => void enterFullscreen()}><Maximize2 size={17} /></button></div></figcaption>
    </figure>
  );
}

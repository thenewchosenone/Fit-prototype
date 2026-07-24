import { Maximize2 } from "lucide-react";
import { useRef } from "react";
import { BodyRegionGlyph } from "./ExerciseVisual";
import type { Exercise } from "./types";

export function ExerciseDemo({ exercise }: { exercise: Exercise }) {
  const figureRef = useRef<HTMLElement>(null);
  const enterFullscreen = async () => {
    if (figureRef.current?.requestFullscreen) await figureRef.current.requestFullscreen();
  };
  return (
    <figure ref={figureRef} className="exercise-demo">
      <div className="demo-media-stage">
        <BodyRegionGlyph exercise={exercise} />
        <span className="demo-media-label">Anatomy Reference</span>
      </div>
      <figcaption><div><strong>{exercise.name} anatomy</strong><small>Muscle-group reference—not movement or verification evidence.</small></div><button type="button" className="icon-button" aria-label="View anatomy reference full screen" onClick={() => void enterFullscreen()}><Maximize2 size={17} /></button></figcaption>
    </figure>
  );
}

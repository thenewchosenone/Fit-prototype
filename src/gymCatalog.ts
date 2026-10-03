import type { Gym } from "./types";
import { withLegacyDemoMetrics } from "./platformData";

let catalogPromise: Promise<Gym[]> | null = null;

export function loadGymCatalog(): Promise<Gym[]> {
  catalogPromise ??= import("./gymCatalog.json")
    .then(({ default: catalog }) => catalog.gyms.map((gym) => withLegacyDemoMetrics({ ...gym, countryCode: "US" as const })))
    .catch((error: unknown) => {
      catalogPromise = null;
      throw error;
    });
  return catalogPromise;
}

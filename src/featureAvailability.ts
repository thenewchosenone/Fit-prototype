export interface WebFeatureAvailability {
  community: boolean;
  messaging: boolean;
}

export function resolveWebFeatureAvailability(
  deferredFeaturesValue: string | undefined,
  mode: string
): WebFeatureAvailability {
  const normalizedValue = deferredFeaturesValue?.trim().toLowerCase();
  const explicitlyEnabled = ["1", "true", "yes"].includes(normalizedValue ?? "");
  const enabledForExistingFeatureTests = mode === "test" && normalizedValue === undefined;
  const deferredFeaturesEnabled = explicitlyEnabled || enabledForExistingFeatureTests;

  return {
    community: deferredFeaturesEnabled,
    messaging: deferredFeaturesEnabled
  };
}

export const webFeatures = resolveWebFeatureAvailability(
  import.meta.env.VITE_ENABLE_DEFERRED_FEATURES,
  import.meta.env.MODE
);

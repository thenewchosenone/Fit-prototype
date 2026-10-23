export function profileAvatarCleanupPaths(ownerID, persistedAvatarPath) {
  if (typeof persistedAvatarPath !== "string" || persistedAvatarPath.length === 0) return [];

  const ownerPath = `${ownerID.toLowerCase()}/avatar`;
  return [
    `${ownerPath}/avatar-full.jpg`,
    `${ownerPath}/avatar-thumb.jpg`,
  ];
}

export function ownedLiftEvidenceCleanupPaths(ownerID, liftID, paths) {
  const prefix = `${ownerID.toLowerCase()}/${liftID.toLowerCase()}/`;
  return [...new Set(paths.filter((path) => {
    if (typeof path !== "string" || !path.startsWith(prefix)) return false;
    const segments = path.slice(prefix.length).split("/");
    return segments.every((segment) => segment.length > 0 && segment !== "." && segment !== "..");
  }))];
}


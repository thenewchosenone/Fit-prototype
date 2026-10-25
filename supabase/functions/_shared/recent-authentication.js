export function hasRecentAuthentication(accessToken, nowSeconds = Date.now() / 1000, maxAgeSeconds = 600) {
  const tokenParts = accessToken.split(".");
  if (tokenParts.length !== 3 || !tokenParts[1]) return false;

  try {
    const payload = tokenParts[1].replaceAll("-", "+").replaceAll("_", "/")
      .padEnd(Math.ceil(tokenParts[1].length / 4) * 4, "=");
    const claims = JSON.parse(atob(payload));
    if (!Array.isArray(claims.amr)) return false;

    const authenticationTimes = claims.amr
      .filter((entry) => entry && typeof entry === "object"
        && typeof entry.method === "string"
        && entry.method !== "token_refresh"
        && entry.method !== "anonymous"
        && Number.isFinite(entry.timestamp)
        && entry.timestamp <= nowSeconds + 30)
      .map((entry) => entry.timestamp);

    const latestAuthentication = Math.max(...authenticationTimes);
    return Number.isFinite(latestAuthentication)
      && nowSeconds - latestAuthentication <= maxAgeSeconds;
  } catch {
    return false;
  }
}

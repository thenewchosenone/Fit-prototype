const STATE_NAMES = {
  AL: "Alabama", AK: "Alaska", AZ: "Arizona", AR: "Arkansas", CA: "California",
  CO: "Colorado", CT: "Connecticut", DE: "Delaware", FL: "Florida", GA: "Georgia",
  HI: "Hawaii", ID: "Idaho", IL: "Illinois", IN: "Indiana", IA: "Iowa",
  KS: "Kansas", KY: "Kentucky", LA: "Louisiana", ME: "Maine", MD: "Maryland",
  MA: "Massachusetts", MI: "Michigan", MN: "Minnesota", MS: "Mississippi", MO: "Missouri",
  MT: "Montana", NE: "Nebraska", NV: "Nevada", NH: "New Hampshire", NJ: "New Jersey",
  NM: "New Mexico", NY: "New York", NC: "North Carolina", ND: "North Dakota", OH: "Ohio",
  OK: "Oklahoma", OR: "Oregon", PA: "Pennsylvania", RI: "Rhode Island", SC: "South Carolina",
  SD: "South Dakota", TN: "Tennessee", TX: "Texas", UT: "Utah", VT: "Vermont",
  VA: "Virginia", WA: "Washington", WV: "West Virginia", WI: "Wisconsin", WY: "Wyoming",
  DC: "District of Columbia"
};

const STATE_CODES = Object.fromEntries(Object.entries(STATE_NAMES).map(([code, name]) => [name.toLowerCase(), code]));

export function stateName(value) {
  const clean = String(value ?? "").trim();
  return STATE_NAMES[clean.toUpperCase()] ?? STATE_NAMES[STATE_CODES[clean.toLowerCase()]] ?? clean;
}

export function slug(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}

export function cleanText(value) {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

export function normalizePostalCode(value) {
  return cleanText(value).match(/\b\d{5}(?:-\d{4})?\b/)?.[0] ?? "";
}

export function catalogId(location) {
  if (location.sourceId) return `gym-${slug(location.brand)}-${slug(location.sourceId)}`;
  return `gym-${slug(location.brand)}-${slug(location.address)}-${slug(location.postalCode)}`;
}

export function normalizedAddressKey(location) {
  return [location.brand, location.address, location.city, location.state, location.postalCode]
    .map((value) => slug(value))
    .join("|");
}

export { STATE_NAMES };

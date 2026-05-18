export function toIso(value) {
  return new Date(value).toISOString();
}

export function addMs(iso, deltaMs) {
  const base = typeof iso === "number" ? iso : new Date(iso).getTime();
  return new Date(base + deltaMs).toISOString();
}

export function clone(value) {
  if (value === null || value === undefined) return value;
  return JSON.parse(JSON.stringify(value));
}

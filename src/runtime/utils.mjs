export function toIso(value) {
  return new Date(value).toISOString();
}

export function addMs(iso, deltaMs) {
  return new Date(new Date(iso).getTime() + deltaMs).toISOString();
}

export function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

import { clone } from "./utils.mjs";

export class InMemoryTraceSink {
  constructor() {
    this.events = [];
  }

  emit(traceEvent) {
    this.events.push(clone(traceEvent));
  }

  toJsonl() {
    return this.events.map((trace_event) => JSON.stringify({ trace_event })).join("\n");
  }
}

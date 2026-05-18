export class InMemoryTraceSink {
  constructor() {
    this.events = [];
  }

  emit(traceEvent) {
    // CaPU emits a freshly constructed event on every call; storing the
    // reference directly avoids a per-event deep clone on the hot path.
    this.events.push(traceEvent);
  }

  toJsonl() {
    return this.events.map((trace_event) => JSON.stringify({ trace_event })).join("\n");
  }
}

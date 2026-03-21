import { clone } from "./utils.mjs";

export class InMemoryStorage {
  constructor({ failCauseIds = [] } = {}) {
    this.records = new Map();
    this.commits = [];
    this.failCauseIds = new Set(failCauseIds);
  }

  commit(causeRecord) {
    const causeId = causeRecord.cause_id;
    if (!causeId) throw new Error("cause_id is required for commit");
    if (this.failCauseIds.has(causeId)) throw new Error(`simulated commit failure: ${causeId}`);
    if (this.records.has(causeId)) throw new Error(`cause already committed: ${causeId}`);
    const committed = clone(causeRecord);
    this.records.set(causeId, committed);
    this.commits.push(committed);
    return causeId;
  }

  get(causeId) {
    return this.records.get(causeId) || null;
  }

  exists(causeId) {
    return this.records.has(causeId);
  }
}

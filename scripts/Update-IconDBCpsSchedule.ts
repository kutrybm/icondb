interface IssueStatusInput {
  key: string;
  statusCategory: "To Do" | "In Progress" | "Done";
  statusName: string;
}

interface RunInput {
  mode: "initialize" | "preview" | "apply";
  runId: string;
  exportedAt: string;
  statusSourceComplete: boolean;
  issues: IssueStatusInput[];
}

interface MapEntry {
  mapRow: number;
  recoveryId: string;
  jiraKey: string;
  taskName: string;
  baselineStart: number;
  baselineEnd: number;
  estimatedDays: number;
  predecessorIds: string[];
  dependencyMode: "ANY" | "ALL";
}

interface PlannedChange {
  kind: "status" | "recovery";
  row: number;
  taskName: string;
  oldStatus: string;
  newStatus: string;
  recoveryId: string;
  estimatedDays: number;
  startFormula: string;
  endFormula: string;
}

interface RunResult {
  mode: string;
  status: "complete" | "failed";
  runId: string;
  exportedAt: string;
  changes: PlannedChange[];
  insertedRecoveryIds: string[];
  warnings: string[];
  errors: string[];
}

const SCHEDULE_SHEET = "Project schedule";
const MAP_SHEET = "Automation Map";
const LOG_SHEET = "Automation Log";
const MAP_TABLE = "IconDBCpsAutomationMap";
const LOG_TABLE = "IconDBCpsAutomationLog";
const HEADER_ROW = 7;
const FIRST_TASK_ROW = 10;
const LAST_COLUMN = "FA";
const ALLOWED_STATUSES = ["Done", "In Progress", "Not Started", "Late"];
const MAP_HEADERS = [
  "Recovery ID", "Jira Key", "Exact CPS Task", "Baseline Start", "Baseline End",
  "Estimated Workdays", "Predecessor Recovery IDs", "Dependency Mode", "Active", "Notes"
];
const LOG_HEADERS = [
  "Exported At", "Run ID", "Mode", "Status", "Changed Cells",
  "Inserted Recovery IDs", "Warnings", "Errors"
];

function main(workbook: ExcelScript.Workbook, inputJson: string): string {
  const result: RunResult = {
    mode: "unknown", status: "failed", runId: "", exportedAt: "",
    changes: [], insertedRecoveryIds: [], warnings: [], errors: []
  };

  try {
    const input = parseInput(inputJson);
    result.mode = input.mode;
    result.runId = input.runId;
    result.exportedAt = input.exportedAt;

    const schedule = workbook.getWorksheet(SCHEDULE_SHEET);
    if (!schedule) throw new Error(`Required worksheet '${SCHEDULE_SHEET}' is missing.`);
    if (!workbook.getWorksheet("Holidays")) {
      throw new Error("Required worksheet 'Holidays' is missing.");
    }

    if (input.mode === "initialize") {
      initializeControlSheets(workbook);
      result.status = "complete";
      return JSON.stringify(result);
    }

    if (!input.statusSourceComplete) {
      throw new Error("Status-source retrieval is not complete; no workbook changes are permitted.");
    }

    const mapSheet = workbook.getWorksheet(MAP_SHEET);
    if (!mapSheet) throw new Error(`Run initialize first: '${MAP_SHEET}' is missing.`);
    const logSheet = workbook.getWorksheet(LOG_SHEET);
    if (!logSheet) throw new Error(`Run initialize first: '${LOG_SHEET}' is missing.`);

    const entries = readMap(mapSheet);
    const issueByKey = buildIssueIndex(input.issues);
    const used = schedule.getUsedRange(true);
    if (!used || used.getRowCount() < FIRST_TASK_ROW) {
      throw new Error("Project schedule has no task rows.");
    }

    const lastRow = used.getRowIndex() + used.getRowCount();
    const taskValues = schedule.getRange(`E${FIRST_TASK_ROW}:L${lastRow}`).getValues();
    const taskRows = indexSchedule(taskValues, FIRST_TASK_ROW);
    validateMap(entries, taskRows, issueByKey);
    const runDateSerial = toExcelSerial(new Date(input.exportedAt));
    const plan = buildPlan(entries, taskRows, issueByKey, runDateSerial, schedule);
    result.changes = plan;

    if (input.mode === "preview") {
      result.status = "complete";
      return JSON.stringify(result);
    }

    applyPlan(schedule, plan, result);
    result.status = "complete";
    appendLog(logSheet, result);
    return JSON.stringify(result);
  } catch (error) {
    result.errors.push(error instanceof Error ? error.message : String(error));
    return JSON.stringify(result);
  }
}

function parseInput(inputJson: string): RunInput {
  let input: RunInput;
  try {
    input = JSON.parse(inputJson) as RunInput;
  } catch {
    throw new Error("Input is not valid JSON.");
  }
  if (!input || !["initialize", "preview", "apply"].includes(input.mode)) {
    throw new Error("Mode must be initialize, preview, or apply.");
  }
  if (!input.runId || !input.exportedAt || Number.isNaN(Date.parse(input.exportedAt))) {
    throw new Error("runId and an ISO exportedAt value are required.");
  }
  if (!Array.isArray(input.issues)) throw new Error("issues must be an array.");
  return input;
}

function initializeControlSheets(workbook: ExcelScript.Workbook): void {
  let map = workbook.getWorksheet(MAP_SHEET);
  if (!map) map = workbook.addWorksheet(MAP_SHEET);
  if (!map.getUsedRange(true)) {
    map.getRange("A1:J1").setValues([MAP_HEADERS]);
    formatHeader(map.getRange("A1:J1"));
    map.getFreezePanes().freezeRows(1);
  }
  if (!workbook.getTable(MAP_TABLE)) map.addTable("A1:J1", true).setName(MAP_TABLE);

  let log = workbook.getWorksheet(LOG_SHEET);
  if (!log) log = workbook.addWorksheet(LOG_SHEET);
  if (!log.getUsedRange(true)) {
    log.getRange("A1:H1").setValues([LOG_HEADERS]);
    formatHeader(log.getRange("A1:H1"));
    log.getFreezePanes().freezeRows(1);
  }
  if (!workbook.getTable(LOG_TABLE)) log.addTable("A1:H1", true).setName(LOG_TABLE);
}

function formatHeader(range: ExcelScript.Range): void {
  range.getFormat().getFont().setBold(true);
  range.getFormat().getFill().setColor("#D9EAF7");
  range.getFormat().autofitColumns();
}

function readMap(sheet: ExcelScript.Worksheet): MapEntry[] {
  const used = sheet.getUsedRange(true);
  if (!used || used.getRowCount() < 2) throw new Error("Automation Map has no approved entries.");
  const values = used.getValues();
  const entries: MapEntry[] = [];
  const ids = new Set<string>();
  for (let index = 1; index < values.length; index++) {
    const row = values[index];
    const active = String(row[8] ?? "").trim().toLowerCase();
    if (!["yes", "true", "1"].includes(active)) continue;
    const recoveryId = String(row[0] ?? "").trim().toUpperCase();
    const jiraKey = String(row[1] ?? "").trim().toUpperCase();
    const taskName = String(row[2] ?? "").trim();
    const baselineStart = Number(row[3]);
    const baselineEnd = Number(row[4]);
    const estimatedDays = Number(row[5]);
    const predecessorIds = String(row[6] ?? "").split(/[;,]/)
      .map(value => value.trim().toUpperCase()).filter(Boolean);
    const dependencyMode = String(row[7] ?? "ALL").trim().toUpperCase();
    if (!/^[A-Z][A-Z0-9_-]*$/.test(recoveryId)) {
      throw new Error(`Automation Map row ${index + 1} has an invalid Recovery ID.`);
    }
    if (ids.has(recoveryId)) throw new Error(`Duplicate Recovery ID '${recoveryId}'.`);
    ids.add(recoveryId);
    if (!/^[A-Z][A-Z0-9_]+-\d+$/.test(jiraKey)) {
      throw new Error(`Automation Map row ${index + 1} has an invalid Jira key.`);
    }
    if (!taskName) throw new Error(`Automation Map row ${index + 1} has no exact task name.`);
    if (!Number.isFinite(baselineStart) || !Number.isFinite(baselineEnd)) {
      throw new Error(`Automation Map row ${index + 1} has invalid baseline dates.`);
    }
    if (!Number.isInteger(estimatedDays) || estimatedDays < 1 || estimatedDays > 260) {
      throw new Error(`Automation Map row ${index + 1} has invalid estimated workdays.`);
    }
    if (!["ANY", "ALL"].includes(dependencyMode)) {
      throw new Error(`Automation Map row ${index + 1} dependency mode must be ANY or ALL.`);
    }
    entries.push({
      mapRow: index + 1, recoveryId, jiraKey, taskName, baselineStart, baselineEnd, estimatedDays,
      predecessorIds, dependencyMode: dependencyMode as "ANY" | "ALL"
    });
  }
  if (!entries.length) throw new Error("Automation Map has no active approved entries.");
  return entries;
}

interface ScheduleRow {
  row: number;
  taskName: string;
  status: string;
  start: string | number | boolean;
  end: string | number | boolean;
  duration: string | number | boolean;
  recoveryId: string;
}

function indexSchedule(values: (string | number | boolean)[][], firstRow: number): ScheduleRow[] {
  return values.map((value, index) => {
    const taskName = String(value[0] ?? "").trim();
    const recoveryMatch = taskName.match(/^\[Recovery ([A-Z][A-Z0-9_-]*)\]/i);
    return {
      row: firstRow + index,
      taskName,
      status: normalizeStatus(String(value[1] ?? "").trim()),
      start: value[5], end: value[6], duration: value[7],
      recoveryId: recoveryMatch ? recoveryMatch[1].toUpperCase() : ""
    };
  }).filter(row => row.taskName);
}

function normalizeStatus(status: string): string {
  const match = ALLOWED_STATUSES.find(value => value.toLowerCase() === status.toLowerCase());
  return match ?? status;
}

function buildIssueIndex(issues: IssueStatusInput[]): Map<string, IssueStatusInput> {
  const result = new Map<string, IssueStatusInput>();
  for (const issue of issues) {
    const key = String(issue.key ?? "").trim().toUpperCase();
    if (!key || result.has(key)) throw new Error(`Missing or duplicate Jira issue '${key}'.`);
    if (!["To Do", "In Progress", "Done"].includes(issue.statusCategory)) {
      throw new Error(`Jira issue ${key} has unsupported status category '${issue.statusCategory}'.`);
    }
    result.set(key, issue);
  }
  return result;
}

function validateMap(
  entries: MapEntry[], rows: ScheduleRow[], issues: Map<string, IssueStatusInput>
): void {
  const activeIds = new Set(entries.map(entry => entry.recoveryId));
  const existingIds = new Set<string>();
  for (const row of rows.filter(value => value.recoveryId)) {
    if (existingIds.has(row.recoveryId)) throw new Error(`Duplicate recovery row '${row.recoveryId}'.`);
    existingIds.add(row.recoveryId);
  }
  for (const entry of entries) {
    if (!issues.has(entry.jiraKey)) throw new Error(`Jira result is missing ${entry.jiraKey}.`);
    const matches = rows.filter(row =>
      row.taskName === entry.taskName && !row.recoveryId &&
      Number(row.start) === entry.baselineStart && Number(row.end) === entry.baselineEnd
    );
    if (matches.length !== 1) {
      throw new Error(
        `Task '${entry.taskName}' with baseline ${entry.baselineStart}-${entry.baselineEnd} ` +
        `must match exactly one row; found ${matches.length}.`
      );
    }
    for (const predecessor of entry.predecessorIds) {
      if (predecessor === entry.recoveryId) throw new Error(`${entry.recoveryId} depends on itself.`);
      if (!activeIds.has(predecessor) && !existingIds.has(predecessor)) {
        throw new Error(`${entry.recoveryId} has missing predecessor '${predecessor}'.`);
      }
    }
  }
  detectCycles(entries);
}

function detectCycles(entries: MapEntry[]): void {
  const graph = new Map(entries.map(entry => [entry.recoveryId, entry.predecessorIds]));
  const visiting = new Set<string>();
  const visited = new Set<string>();
  const visit = (id: string): void => {
    if (visiting.has(id)) throw new Error(`Circular dependency detected at '${id}'.`);
    if (visited.has(id) || !graph.has(id)) return;
    visiting.add(id);
    for (const predecessor of graph.get(id) ?? []) visit(predecessor);
    visiting.delete(id);
    visited.add(id);
  };
  for (const id of graph.keys()) visit(id);
}

function buildPlan(
  entries: MapEntry[], rows: ScheduleRow[], issues: Map<string, IssueStatusInput>,
  runDateSerial: number, sheet: ExcelScript.Worksheet
): PlannedChange[] {
  const changes: PlannedChange[] = [];
  const recoveryRows = new Map(rows.filter(row => row.recoveryId).map(row => [row.recoveryId, row]));
  const plannedRows = new Map<string, number>();
  for (const entry of entries) {
    const baseline = rows.find(row =>
      row.taskName === entry.taskName && !row.recoveryId &&
      Number(row.start) === entry.baselineStart && Number(row.end) === entry.baselineEnd
    ) as ScheduleRow;
    const issue = issues.get(entry.jiraKey) as IssueStatusInput;
    const sourceStatus = issue.statusCategory === "Done" ? "Done" :
      issue.statusCategory === "In Progress" ? "In Progress" : "Not Started";
    const endSerial = typeof baseline.end === "number" ? baseline.end : 0;
    const targetStatus = sourceStatus !== "Done" && endSerial > 0 && endSerial < runDateSerial
      ? "Late" : sourceStatus;
    if (baseline.status !== targetStatus) {
      changes.push({
        kind: "status", row: baseline.row, taskName: baseline.taskName,
        oldStatus: baseline.status, newStatus: targetStatus, recoveryId: "",
        estimatedDays: 0,
        startFormula: "", endFormula: ""
      });
    }
    if (targetStatus !== "Late") continue;

    const existing = recoveryRows.get(entry.recoveryId);
    const targetRow = existing ? existing.row : baseline.row + 1;
    plannedRows.set(entry.recoveryId, targetRow);
    const predecessorRows = entry.predecessorIds.map(id => {
      const row = recoveryRows.get(id)?.row ?? plannedRows.get(id);
      if (!row) throw new Error(`Predecessor '${id}' must appear before '${entry.recoveryId}' in the map.`);
      return row;
    });
    const startFormula = predecessorRows.length === 0
      ? "=WORKDAY(TODAY()-1,1,Holidays!$C:$C)"
      : `=WORKDAY(${entry.dependencyMode === "ANY" ? "MIN" : "MAX"}(${predecessorRows.map(row => `K${row}`).join(",")}),1,Holidays!$C:$C)`;
    const endFormula = `=WORKDAY(J${targetRow},L${targetRow}-1,Holidays!$C:$C)`;
    if (!existing) {
      changes.push({
        kind: "recovery", row: targetRow,
        taskName: `[Recovery ${entry.recoveryId}] ${entry.taskName}`,
        oldStatus: "", newStatus: "Not Started", recoveryId: entry.recoveryId,
        estimatedDays: entry.estimatedDays,
        startFormula, endFormula
      });
    } else {
      const expectedName = `[Recovery ${entry.recoveryId}] ${entry.taskName}`;
      if (existing.taskName !== expectedName) {
        throw new Error(`Existing recovery row '${entry.recoveryId}' does not match the approved task.`);
      }
      if (!ALLOWED_STATUSES.includes(existing.status)) {
        throw new Error(`Recovery row '${entry.recoveryId}' has invalid status '${existing.status}'.`);
      }
    }
  }
  return changes;
}

function applyPlan(sheet: ExcelScript.Worksheet, plan: PlannedChange[], result: RunResult): void {
  for (const change of plan.filter(value => value.kind === "status")) {
    sheet.getRange(`F${change.row}`).setValue(change.newStatus);
  }

  const insertions = plan.filter(value => value.kind === "recovery")
    .sort((left, right) => right.row - left.row);
  for (const change of insertions) {
    const row = change.row;
    sheet.getRange(`${row}:${row}`).insert(ExcelScript.InsertShiftDirection.down);
    const sourceRow = row > FIRST_TASK_ROW ? row - 1 : row + 1;
    sheet.getRange(`A${row}:${LAST_COLUMN}${row}`).copyFrom(
      sheet.getRange(`A${sourceRow}:${LAST_COLUMN}${sourceRow}`), ExcelScript.RangeCopyType.all
    );
    sheet.getRange(`E${row}`).setValue(change.taskName);
    sheet.getRange(`F${row}`).setValue(change.newStatus);
    sheet.getRange(`I${row}`).setFormula(`=IF(F${row}="Done",100%,"")`);
    sheet.getRange(`J${row}`).setFormula(change.startFormula);
    sheet.getRange(`K${row}`).setFormula(change.endFormula);
    sheet.getRange(`L${row}`).setValue(change.estimatedDays);
    sheet.getRange(`M${row}`).setFormula(`=K${row}-J${row}+1`);
    result.insertedRecoveryIds.push(change.recoveryId);
  }
}

function appendLog(sheet: ExcelScript.Worksheet, result: RunResult): void {
  const used = sheet.getUsedRange(true);
  const row = used ? used.getRowCount() + 1 : 1;
  sheet.getRange(`A${row}:H${row}`).setValues([[
    result.exportedAt, result.runId, result.mode, result.status,
    result.changes.length, result.insertedRecoveryIds.join(";"),
    result.warnings.join(" | "), result.errors.join(" | ")
  ]]);
}

function toExcelSerial(date: Date): number {
  return (Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()) -
    Date.UTC(1899, 11, 30)) / 86400000;
}

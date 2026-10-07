export type AnalyticsSegment = {
  id: string;
  url: string;
  checksum: string;
};

export type AnalyticsDeps = {
  now: () => number;
  budgetMs: number;
  listRequests: () => Promise<Array<{ id: string; stoppedDueToInactivity: boolean }>>;
  listReports: (requestId: string) => Promise<Array<{ id: string }>>;
  listInstances: (reportId: string, granularity: string) => Promise<Array<{ id: string }>>;
  listSegments: (instanceId: string) => Promise<AnalyticsSegment[]>;
  alreadyImported: (checksum: string) => Promise<boolean>;
  download: (segment: AnalyticsSegment) => Promise<Record<string, string>[]>;
  insertRows: (rows: Record<string, string>[]) => Promise<void>;
  markImported: (segment: AnalyticsSegment) => Promise<void>;
  startRun: () => Promise<string>;
  finishRun: (runId: string, status: string, detail?: string) => Promise<void>;
};

const granularities = ["DAILY", "WEEKLY", "MONTHLY"];

export async function importAnalytics(deps: AnalyticsDeps): Promise<{ inserted: number; status: string }> {
  const started = deps.now();
  const runId = await deps.startRun();
  let inserted = 0;
  try {
    const requests = await deps.listRequests();
    for (const request of requests) {
      if (request.stoppedDueToInactivity) {
        await deps.finishRun(runId, "failed", "stoppedDueToInactivity");
        return { inserted, status: "failed" };
      }
      const reports = await deps.listReports(request.id);
      for (const report of reports) {
        for (const granularity of granularities) {
          const instances = await deps.listInstances(report.id, granularity);
          for (const instance of instances) {
            const segments = await deps.listSegments(instance.id);
            for (const segment of segments) {
              if (deps.now() - started > deps.budgetMs) {
                await deps.finishRun(runId, "partial", "time budget");
                return { inserted, status: "partial" };
              }
              if (await deps.alreadyImported(segment.checksum)) {
                continue;
              }
              const rows = await deps.download(segment);
              for (let offset = 0; offset < rows.length; offset += 500) {
                await deps.insertRows(rows.slice(offset, offset + 500));
              }
              await deps.markImported(segment);
              inserted += rows.length;
            }
          }
        }
      }
    }
    await deps.finishRun(runId, "success");
    return { inserted, status: "success" };
  } catch (error) {
    await deps.finishRun(runId, "failed", String(error));
    return { inserted, status: "failed" };
  }
}

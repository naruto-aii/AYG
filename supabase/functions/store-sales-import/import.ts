export type SalesFile = {
  reportType: string;
  frequency: string;
  reportDate: string;
  version: string;
};

export type SalesDeps = {
  dates: () => string[];
  fetchReport: (file: SalesFile) => Promise<{ status: number; rows: Record<string, string>[] }>;
  alreadyImported: (key: string) => Promise<boolean>;
  mark: (key: string, status: string) => Promise<void>;
  insertRows: (rows: Record<string, string>[]) => Promise<void>;
};

const kinds = [
  { reportType: "SALES", version: "1_0", subtype: "SUMMARY" },
  { reportType: "SUBSCRIPTION", version: "1_3", subtype: "SUMMARY" },
  { reportType: "SUBSCRIPTION_EVENT", version: "1_3", subtype: "SUMMARY" },
  { reportType: "SUBSCRIBER", version: "1_3", subtype: "DETAILED" },
];

const frequencies = ["DAILY", "WEEKLY", "MONTHLY", "YEARLY"];

export async function importSales(deps: SalesDeps): Promise<{ inserted: number; notAvailable: number }> {
  let inserted = 0;
  let notAvailable = 0;
  for (const kind of kinds) {
    for (const frequency of frequencies) {
      const dates = frequency === "DAILY" ? deps.dates().slice(0, 14) : deps.dates().slice(0, 1);
      for (const reportDate of dates) {
        const file: SalesFile = {
          reportType: kind.reportType,
          frequency,
          reportDate,
          version: kind.version,
        };
        const key = `${file.reportType}:${file.frequency}:${file.reportDate}:${file.version}`;
        if (await deps.alreadyImported(key)) {
          continue;
        }
        const response = await deps.fetchReport(file);
        if (response.status === 404) {
          notAvailable += 1;
          await deps.mark(key, "not_available");
          continue;
        }
        if (response.status >= 200 && response.status < 300) {
          await deps.insertRows(response.rows);
          await deps.mark(key, "imported");
          inserted += response.rows.length;
        }
      }
    }
  }
  return { inserted, notAvailable };
}

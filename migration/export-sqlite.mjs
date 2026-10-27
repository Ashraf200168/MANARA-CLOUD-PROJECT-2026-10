import { DatabaseSync } from 'node:sqlite';
import { cpSync, existsSync, mkdirSync, chmodSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';

const databasePath = resolve(process.argv[2] || process.env.MANARA_SQLITE || '/app/data/manara.db');
const uploadsPath = resolve(process.argv[3] || process.env.MANARA_UPLOADS || '/app/data/uploads');
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/T/, '-').slice(0, 15);
const outputPath = resolve(process.argv[4] || `cloud-export-${stamp}`);
if (!existsSync(databasePath)) throw new Error(`Database not found: ${databasePath}`);
if (existsSync(outputPath)) throw new Error(`Refusing to overwrite existing export: ${outputPath}`);

mkdirSync(outputPath, { recursive: false, mode: 0o700 });
const db = new DatabaseSync(databasePath, { readOnly: true });
const integrity = db.prepare('PRAGMA integrity_check').get().integrity_check;
if (integrity !== 'ok') throw new Error(`SQLite integrity check failed: ${integrity}`);

const tables = [
  'admins','settings','books','advice','exams','questions','students','question_bank',
  'assignments','attempts','answers','inquiry_topics','inquiries','support_tickets','site_visits'
];
const data = {};
const available = new Set(db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(row => row.name));
const missing = [];
for (const table of tables) {
  if (!available.has(table)) { data[table] = []; missing.push(table); continue; }
  data[table] = db.prepare(`SELECT * FROM ${table}`).all();
}
db.close();

const exportFile = join(outputPath, 'manara-data.json');
writeFileSync(exportFile, JSON.stringify({
  format: 'manara-sqlite-export-v1',
  exportedAt: new Date().toISOString(),
  sourceDatabase: basename(databasePath),
  integrity,
  missingTables: missing,
  tables: data
}, null, 2), { mode: 0o600 });

if (existsSync(uploadsPath)) cpSync(uploadsPath, join(outputPath, 'uploads'), { recursive: true, force: false });
writeFileSync(join(outputPath, 'README.txt'), [
  'Sensitive Manara migration export.',
  'It contains student records and administrator password hashes.',
  'Keep it private, transfer it securely, and delete it after verification.',
  `Created: ${new Date().toISOString()}`
].join('\n'), { mode: 0o600 });
try { chmodSync(outputPath, 0o700); } catch {}

console.log(JSON.stringify({ outputPath, integrity, missingTables: missing, counts: Object.fromEntries(tables.map(name => [name, data[name].length])) }, null, 2));

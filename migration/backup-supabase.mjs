import { createClient } from '@supabase/supabase-js';
import { createHash } from 'node:crypto';
import {
  appendFileSync,
  chmodSync,
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';

const outputPath = resolve(process.argv[2] || '');
const projectRoot = resolve(process.argv[3] || process.cwd());
const url = process.env.SUPABASE_URL;
const secret = process.env.SUPABASE_SECRET_KEY;

if (!outputPath) throw new Error('Backup output path is required');
if (!url || !secret) throw new Error('SUPABASE_URL and SUPABASE_SECRET_KEY are required');
if (existsSync(outputPath)) throw new Error(`Refusing to overwrite existing backup: ${outputPath}`);

const projectRef = new URL(url).hostname.split('.')[0];
const client = createClient(url, secret, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const tableDefinitions = [
  ['admins', 'id'],
  ['settings', 'key'],
  ['books', 'id'],
  ['advice', 'id'],
  ['exams', 'id'],
  ['questions', 'id'],
  ['students', 'id'],
  ['question_bank', 'id'],
  ['assignments', 'id'],
  ['attempts', 'id'],
  ['answers', 'id'],
  ['inquiry_topics', 'id'],
  ['inquiries', 'id'],
  ['support_tickets', 'id'],
  ['site_visits', 'id'],
  ['certificates', 'id'],
];

const tableDirectory = join(outputPath, 'tables');
const storageDirectory = join(outputPath, 'storage', 'manara-books');
mkdirSync(tableDirectory, { recursive: true, mode: 0o700 });
mkdirSync(storageDirectory, { recursive: true, mode: 0o700 });

function hashFile(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function safeStoragePath(storagePath) {
  const segments = storagePath.split('/').filter(Boolean);
  if (!segments.length || segments.some((segment) => segment === '.' || segment === '..')) {
    throw new Error(`Unsafe storage object path: ${storagePath}`);
  }
  const target = resolve(storageDirectory, ...segments);
  const prefix = `${resolve(storageDirectory)}${sep}`.toLowerCase();
  if (!target.toLowerCase().startsWith(prefix)) {
    throw new Error(`Storage object escaped backup directory: ${storagePath}`);
  }
  return target;
}

async function exportTable(table, orderColumn) {
  const destination = join(tableDirectory, `${table}.jsonl`);
  writeFileSync(destination, '', { mode: 0o600 });
  const countResult = await client.from(table).select(orderColumn, { count: 'exact', head: true });
  if (countResult.error) throw new Error(`${table} count: ${countResult.error.message}`);
  const expected = countResult.count || 0;
  let exported = 0;
  const pageSize = 1000;

  while (exported < expected) {
    const result = await client
      .from(table)
      .select('*')
      .order(orderColumn, { ascending: true })
      .range(exported, Math.min(exported + pageSize - 1, expected - 1));
    if (result.error) throw new Error(`${table} export: ${result.error.message}`);
    const rows = result.data || [];
    if (!rows.length) throw new Error(`${table}: export ended at ${exported} of ${expected} rows`);
    appendFileSync(destination, `${rows.map((row) => JSON.stringify(row)).join('\n')}\n`, 'utf8');
    exported += rows.length;
  }

  if (exported !== expected) throw new Error(`${table}: expected ${expected}, exported ${exported}`);
  return { rows: exported, file: relative(outputPath, destination), sha256: hashFile(destination) };
}

async function listStorage(prefix = '') {
  const files = [];
  for (let offset = 0; ; offset += 1000) {
    const result = await client.storage.from('manara-books').list(prefix, {
      limit: 1000,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    });
    if (result.error) throw new Error(`storage list ${prefix || '/'}: ${result.error.message}`);
    const entries = result.data || [];
    for (const entry of entries) {
      if (entry.name === '.emptyFolderPlaceholder') continue;
      const path = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.id || entry.metadata) files.push(path);
      else files.push(...(await listStorage(path)));
    }
    if (entries.length < 1000) break;
  }
  return files;
}

async function downloadStorageObject(path) {
  const result = await client.storage.from('manara-books').download(path);
  if (result.error) throw new Error(`storage download ${path}: ${result.error.message}`);
  const target = safeStoragePath(path);
  mkdirSync(dirname(target), { recursive: true, mode: 0o700 });
  const bytes = Buffer.from(await result.data.arrayBuffer());
  writeFileSync(target, bytes, { mode: 0o600 });
  return {
    path,
    bytes: bytes.length,
    sha256: createHash('sha256').update(bytes).digest('hex'),
  };
}

const probe = await client.from('students').select('id', { count: 'exact', head: true });
if (probe.error) throw new Error(`Supabase connection failed: ${probe.error.message}`);

const tables = {};
for (const [table, orderColumn] of tableDefinitions) {
  tables[table] = await exportTable(table, orderColumn);
  console.log(`${table}: ${tables[table].rows}`);
}

const storageFiles = await listStorage();
const storage = [];
for (const path of storageFiles) {
  const record = await downloadStorageObject(path);
  storage.push(record);
  console.log(`book: ${path} (${record.bytes} bytes)`);
}

const sourceDirectory = join(outputPath, 'deployment-source');
mkdirSync(sourceDirectory, { recursive: true, mode: 0o700 });
for (const name of ['migrations', 'functions']) {
  const source = join(projectRoot, 'supabase', name);
  if (existsSync(source)) cpSync(source, join(sourceDirectory, name), { recursive: true });
}
const configPath = join(projectRoot, 'supabase', 'config.toml');
if (existsSync(configPath)) copyFileSync(configPath, join(sourceDirectory, 'config.toml'));

const manifest = {
  format: 'manara-supabase-backup-v1',
  exportedAt: new Date().toISOString(),
  projectRef,
  tables,
  storage: {
    bucket: 'manara-books',
    count: storage.length,
    bytes: storage.reduce((sum, item) => sum + item.bytes, 0),
    files: storage,
  },
  intentionallyOmitted: [
    'sessions',
    'student_sessions',
    'Live login sessions are excluded. Users sign in again after a disaster recovery.',
  ],
};

writeFileSync(join(outputPath, 'manifest.json'), JSON.stringify(manifest, null, 2), { mode: 0o600 });
writeFileSync(
  join(outputPath, 'README-RECOVERY.txt'),
  [
    'MANARA CLOUD ENCRYPTED BACKUP CONTENT',
    '',
    'This snapshot contains private student records and password hashes.',
    'Keep it encrypted. Use RESTORE-MANARA-BACKUP.cmd to decrypt a copy for recovery.',
    'The live session tables are intentionally omitted; users sign in again after recovery.',
    `Created: ${manifest.exportedAt}`,
    `Project: ${projectRef}`,
  ].join('\r\n'),
  { mode: 0o600 },
);

try { chmodSync(outputPath, 0o700); } catch {}
console.log(JSON.stringify({ ok: true, projectRef, tables: Object.fromEntries(Object.entries(tables).map(([name, value]) => [name, value.rows])), storage: manifest.storage }, null, 2));

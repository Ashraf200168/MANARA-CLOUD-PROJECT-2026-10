import { createClient } from '@supabase/supabase-js';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const exportPath = resolve(process.argv[2] || process.env.MANARA_EXPORT_DIR || '');
const url = process.env.SUPABASE_URL;
const secret = process.env.SUPABASE_SECRET_KEY;
if (!url || !secret) throw new Error('SUPABASE_URL and SUPABASE_SECRET_KEY are required');
const exportFile = join(exportPath, 'manara-data.json');
if (!exportPath || !existsSync(exportFile)) throw new Error('Pass the cloud export directory as the first argument');

const payload = JSON.parse(readFileSync(exportFile, 'utf8'));
const client = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
const tables = [
  'admins','settings','books','advice','exams','questions','students','question_bank',
  'assignments','attempts','answers','inquiry_topics','inquiries','support_tickets','site_visits'
];
const expected = Object.fromEntries(tables.map(table => [table, (payload.tables[table] || []).length]));
const actual = {};
const mismatches = [];

for (const table of tables) {
  const result = await client.from(table).select(table === 'settings' ? 'key' : 'id', { count: 'exact', head: true });
  if (result.error) throw new Error(`${table}: ${result.error.message}`);
  actual[table] = result.count || 0;
  if (table === 'site_visits') {
    if (actual[table] < expected[table]) mismatches.push(`${table}: expected at least ${expected[table]}, got ${actual[table]}`);
  } else if (actual[table] !== expected[table]) {
    mismatches.push(`${table}: expected ${expected[table]}, got ${actual[table]}`);
  }
}

const uploadsPath = join(exportPath, 'uploads');
const expectedUploads = existsSync(uploadsPath) ? readdirSync(uploadsPath).sort() : [];
const storage = await client.storage.from('manara-books').list('', { limit: 1000, sortBy: { column: 'name', order: 'asc' } });
if (storage.error) throw new Error(`storage: ${storage.error.message}`);
const actualUploads = (storage.data || []).filter(item => item.name !== '.emptyFolderPlaceholder').map(item => item.name).sort();
for (const name of expectedUploads) if (!actualUploads.includes(name)) mismatches.push(`storage: missing ${name}`);

const approved = await client.from('students').select('id', { count: 'exact', head: true }).eq('is_test', false).eq('status', 'approved');
const pending = await client.from('students').select('id', { count: 'exact', head: true }).eq('is_test', false).eq('status', 'pending');
const testAccounts = await client.from('students').select('id', { count: 'exact', head: true }).eq('is_test', true);
for (const result of [approved, pending, testAccounts]) if (result.error) throw result.error;

console.log(JSON.stringify({
  ok: mismatches.length === 0,
  expected,
  actual,
  students: { approved: approved.count || 0, pending: pending.count || 0, testAccounts: testAccounts.count || 0 },
  storage: { expected: expectedUploads.length, actual: actualUploads.length, files: actualUploads },
  mismatches
}, null, 2));

if (mismatches.length) process.exitCode = 1;

import { createClient } from '@supabase/supabase-js';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const exportPath = resolve(process.argv[2] || process.env.MANARA_EXPORT_DIR || '');
const url = process.env.SUPABASE_URL;
const secret = process.env.SUPABASE_SECRET_KEY;
if (!url || !secret) throw new Error('SUPABASE_URL and SUPABASE_SECRET_KEY are required');
if (!exportPath || !existsSync(join(exportPath, 'manara-data.json'))) throw new Error('Pass the cloud export directory as the first argument');
const payload = JSON.parse(readFileSync(join(exportPath, 'manara-data.json'), 'utf8'));
if (payload.format !== 'manara-sqlite-export-v1') throw new Error('Unsupported export format');
const client = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });

const probe = await client.from('students').select('id', { count: 'exact', head: true });
if (probe.error) throw probe.error;
if (probe.count) throw new Error(`Target Supabase already contains ${probe.count} students. Import is intentionally refused.`);
for (const table of ['attempts','assignments','questions','exams','books','admins']) {
  const check = await client.from(table).select('id', { count: 'exact', head: true });
  if (check.error) throw check.error;
  if (check.count) throw new Error(`Target Supabase table ${table} is not empty. Import is intentionally refused.`);
}
// The initial migration installs display defaults only. Remove them before
// restoring the authoritative values and IDs from the running installation.
for (const table of ['site_visits','inquiry_topics','settings']) {
  const removed = await client.from(table).delete().not(table === 'settings' ? 'key' : 'id', 'is', null);
  if (removed.error) throw removed.error;
}

const booleanFields = {
  advice:['active'],students:['is_test'],question_bank:['active'],inquiry_topics:['active'],inquiries:['publish_public']
};
const jsonFields = { questions:['data_json'],students:['profile_json'],question_bank:['data_json'],answers:['answer_json'] };
const skipTables = new Set(['sessions','student_sessions']);
const order = ['admins','settings','books','advice','exams','questions','students','question_bank','assignments','attempts','answers','inquiry_topics','inquiries','support_tickets','site_visits'];

function convert(table, row) {
  const copy = { ...row };
  for (const field of booleanFields[table] || []) copy[field] = Boolean(copy[field]);
  for (const field of jsonFields[table] || []) if (typeof copy[field] === 'string') copy[field] = JSON.parse(copy[field] || '{}');
  return copy;
}

for (const table of order) {
  if (skipTables.has(table)) continue;
  const rows = (payload.tables[table] || []).map(row => convert(table, row));
  for (let offset = 0; offset < rows.length; offset += 250) {
    const { error } = await client.from(table).upsert(rows.slice(offset, offset + 250), { onConflict: table === 'settings' ? 'key' : 'id' });
    if (error) throw new Error(`${table}: ${error.message}`);
  }
  console.log(`${table}: ${rows.length}`);
}

const uploads = join(exportPath, 'uploads');
if (existsSync(uploads)) {
  for (const name of readdirSync(uploads)) {
    const bytes = readFileSync(join(uploads, name));
    const { error } = await client.storage.from('manara-books').upload(name, bytes, { contentType: 'application/pdf', upsert: false });
    if (error && !error.message.toLowerCase().includes('already exists')) throw new Error(`upload ${name}: ${error.message}`);
    console.log(`upload: ${name}`);
  }
}
const reset = await client.rpc('manara_reset_sequences');
if (reset.error) throw reset.error;
console.log('Import completed. Sessions were intentionally not migrated; everyone must sign in again.');

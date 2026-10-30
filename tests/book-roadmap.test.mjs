import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import test from 'node:test';
import vm from 'node:vm';

// Exercise the actual Edge Function aggregation with a paginated database double.
const source = readFileSync(new URL('../supabase/functions/manara-api/index.ts', import.meta.url), 'utf8');
const functions = stripTypeScriptTypes(source.slice(source.indexOf('function positiveInteger('), source.indexOf('function publicQuestion(')));
const person = { id: 8, name: 'طالب', student_code: 'ST-TEST', status: 'approved', is_test: false };
const exam = (id, points, extra = {}) => ({
  id, title: `امتحان ${id}`, book_id: 3, access_mode: 'private', status: 'published',
  roadmap_position: id, is_book_final: false, questions: [{ id, points }], ...extra,
});
const assignment = (examId, score, max, extra = {}) => ({
  id: examId, exam_id: examId, student_id: person.id, status: 'submitted', students: person,
  attempts: [{ submitted_at: '2026-10-29T10:00:00Z', score, max_score: max }], ...extra,
});

function contextFor(exams, assignments, failAssignments = false) {
  let pages = 0;
  const data = { books: [{ id: 3, title: 'كتاب' }], exams, assignments };
  const db = { from(table) {
    let rows = [...data[table]];
    const query = {
      select() { return this; },
      eq(key, value) { rows = rows.filter(row => row[key] === value); return this; },
      in(key, values) { rows = rows.filter(row => values.includes(row[key])); return this; },
      order() { return this; },
      range(start, end) { pages++; rows = rows.slice(start, end + 1); return this; },
      limit(count) { rows = rows.slice(0, count); return this; },
      maybeSingle() { return Promise.resolve({ data: rows[0] ?? null, error: null }); },
      then(resolve, reject) {
        return Promise.resolve({ data: rows, error: table === 'assignments' && failAssignments ? { message: 'database unavailable' } : null }).then(resolve, reject);
      },
    };
    return query;
  } };
  const context = vm.createContext({ db, one: async query => {
    const result = await query;
    if (result.error) throw new Error(result.error.message);
    if (!result.data) throw new Error('missing');
    return result.data;
  } });
  vm.runInContext(functions, context);
  return { run: () => context.bookRoadmap(3), pages: () => pages };
}

test('book rate is weighted by marks, while completion remains separate', async () => {
  const { run } = contextFor(
    [exam(1, 10), exam(2, 90), exam(3, 100, { is_book_final: true }), exam(4, 10, { status: 'draft' }), exam(5, 10, { access_mode: 'public' })],
    [assignment(1, 10, 10), assignment(2, 45, 90), assignment(3, 0, 100, { status: 'ready', attempts: [] })],
  );
  const result = await run();
  assert.equal(result.summary.activeExams, 3);
  assert.equal(result.exams.length, 4);
  assert.equal(result.students[0].averagePercentage, 55);
  assert.equal(result.students[0].completionRate, 67);
  assert.equal(result.students[0].earnedScore, 55);
  assert.equal(result.students[0].assessedMaxScore, 100);
  assert.equal(result.students[0].finalStatus, 'ready');
  assert.equal(result.students[0].exams[2].percentage, null);
});

test('unsubmitted, invalid, and integrity-violation attempts cannot count as completion', async () => {
  const { run } = contextFor([exam(1, 10), exam(2, 10), exam(3, 10), exam(4, 10)], [
    assignment(1, 10, 10, { status: 'started', attempts: [{ score: 10, max_score: 10 }] }),
    assignment(2, 10, 10, { attempts: [{ submitted_at: '2026-10-29', score: 10, max_score: 10, violation_type: 'tab_hidden' }] }),
    assignment(3, 0, 0),
    assignment(4, null, 10),
  ]);
  const result = await run();
  assert.equal(result.students[0].completedExams, 0);
  assert.equal(result.students[0].averagePercentage, null);
  assert.equal(result.students[0].exams[0].percentage, null);
  assert.equal(result.students[0].exams[1].status, 'violation');
});

test('zero earned marks still count as a completed exam; test and rejected students do not appear', async () => {
  const { run } = contextFor([exam(1, 10, { is_book_final: true })], [
    assignment(1, 0, 10),
    assignment(1, 10, 10, { students: { ...person, id: 9, is_test: true } }),
    assignment(1, 10, 10, { students: { ...person, id: 10, status: 'rejected' } }),
  ]);
  const result = await run();
  assert.equal(result.students.length, 1);
  assert.equal(result.students[0].completionRate, 100);
  assert.equal(result.students[0].averagePercentage, 0);
  assert.equal(result.summary.completedStudents, 1);
});

test('all assignment pages are read instead of truncating at the API row limit', async () => {
  const rows = Array.from({ length: 1001 }, (_, i) => assignment(1, 8, 10, {
    id: i + 1, students: { ...person, id: i + 1 }, student_id: i + 1,
  }));
  const context = contextFor([exam(1, 10)], rows);
  const result = await context.run();
  assert.equal(context.pages(), 2);
  assert.equal(result.students.length, 1001);
});

test('database errors do not produce a misleading empty roadmap', async () => {
  await assert.rejects(contextFor([exam(1, 10)], [], true).run(), /database unavailable/);
});

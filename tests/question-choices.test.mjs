import assert from 'node:assert/strict';
import test from 'node:test';
import { ChoiceAnswerDraft, validateChoiceAnswers } from '../frontend/admin-question-choices.js';

test('new questions have exactly three empty, unselected answer boxes', () => {
  const draft = new ChoiceAnswerDraft();
  assert.deepEqual(draft.options, ['', '', '']);
  assert.equal(draft.correct, null);
});

test('editing preserves all old answers, multiline content, and correct index', () => {
  const options = ['a', 'b', 'long\nanswer', 'd', 'e'];
  const draft = new ChoiceAnswerDraft({ options, correct: 2 });
  assert.deepEqual(draft.read(), { options, correct: 2 });
  draft.options[0] = 'edited';
  assert.equal(options[0], 'a');
});

test('adding and removing keep the selected answer tied to the same text', () => {
  const draft = new ChoiceAnswerDraft({ options: ['a', 'b', 'correct'], correct: 2 });
  draft.add();
  draft.remove(0);
  assert.equal(draft.correct, 1);
  assert.equal(draft.options[draft.correct], 'correct');
  draft.remove(1);
  assert.equal(draft.correct, null);
  draft.remove(0);
  assert.equal(draft.options.length, 2);
});

test('blank, duplicate, and missing/out-of-range correct answers are rejected', () => {
  assert.throws(() => validateChoiceAnswers(['a', ''], 0), /أكمل/);
  assert.throws(() => validateChoiceAnswers(['a', ' A '], 0), /مكررة/);
  assert.throws(() => validateChoiceAnswers(['a', 'b'], null), /الصحيحة/);
  assert.throws(() => validateChoiceAnswers(['a', 'b'], 2), /الصحيحة/);
  assert.deepEqual(validateChoiceAnswers([' a ', 'b'], 0), { options: ['a', 'b'], correct: 0 });
});

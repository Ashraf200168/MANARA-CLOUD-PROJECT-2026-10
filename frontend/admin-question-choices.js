export function validateChoiceAnswers(values, correct) {
  const options = values.map(value => String(value ?? '').trim());
  if (options.length < 2) throw new Error('أضف إجابتين على الأقل.');
  if (options.some(value => !value)) throw new Error('أكمل جميع الإجابات أو احذف الخانات الفارغة.');
  if (new Set(options.map(value => value.toLowerCase())).size !== options.length) {
    throw new Error('توجد إجابات مكررة. اجعل كل إجابة مختلفة.');
  }
  if (!Number.isInteger(correct) || correct < 0 || correct >= options.length) {
    throw new Error('حدّد الإجابة الصحيحة قبل الحفظ.');
  }
  return { options, correct };
}

export class ChoiceAnswerDraft {
  constructor(data = {}) {
    this.options = Array.isArray(data.options) && data.options.length
      ? data.options.map(value => String(value ?? ''))
      : ['', '', ''];
    while (this.options.length < 2) this.options.push('');
    this.correct = Number.isInteger(data.correct) && data.correct >= 0 && data.correct < this.options.length
      ? data.correct : null;
  }
  add() { this.options.push(''); }
  remove(index) {
    if (this.options.length <= 2 || !Number.isInteger(index) || index < 0 || index >= this.options.length) return;
    this.options.splice(index, 1);
    if (this.correct === index) this.correct = null;
    else if (this.correct > index) this.correct--;
  }
  read() { return validateChoiceAnswers(this.options, this.correct); }
}

let editorSequence = 0;

export function createChoiceAnswerEditor(container, data = {}) {
  if (!document.querySelector('link[data-choice-editor-styles]')) {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = '/admin-question-choices.css?v=1.9.1';
    link.dataset.choiceEditorStyles = '';
    document.head.append(link);
  }
  const draft = new ChoiceAnswerDraft(data);
  const group = `question-choice-${++editorSequence}`;
  let showErrors = false;
  function capture() {
    container.querySelectorAll('[data-choice-input]').forEach((input, index) => {
      draft.options[index] = input.value;
    });
  }
  function updateSelection() {
    container.querySelectorAll('[data-choice-row]').forEach((row, index) => {
      const selected = draft.correct === index;
      row.classList.toggle('is-correct', selected);
      row.querySelector('[data-correct-label]').textContent = selected ? 'هذه هي الإجابة الصحيحة' : 'تحديد كإجابة صحيحة';
    });
  }
  function draw(focusIndex) {
    container.replaceChildren();
    const fieldset = document.createElement('fieldset');
    fieldset.className = 'choice-answer-editor';
    fieldset.innerHTML = '<legend>الإجابات</legend><p class="muted">اكتب كل إجابة في خانتها وحدّد الصحيحة. يمكنك حذف خانة للاكتفاء بإجابتين.</p>';
    draft.options.forEach((value, index) => {
      const row = document.createElement('div');
      row.className = 'choice-answer-row';
      row.dataset.choiceRow = '';
      row.innerHTML = `<div class="choice-answer-heading"><b>الإجابة ${index + 1}</b><button type="button" class="button ghost small" data-remove-choice aria-label="حذف الإجابة ${index + 1}" ${draft.options.length <= 2 ? 'disabled' : ''}>حذف</button></div>
        <label>نص الإجابة ${index + 1}<textarea data-choice-input rows="2" required></textarea></label>
        <label class="choice-correct-selector"><input type="radio" name="${group}" value="${index}" aria-label="الإجابة ${index + 1} هي الصحيحة"><span data-correct-label></span></label>`;
      const input = row.querySelector('[data-choice-input]');
      input.value = value;
      input.setAttribute('aria-invalid', String(showErrors && !value.trim()));
      input.addEventListener('input', () => {
        draft.options[index] = input.value;
        input.setAttribute('aria-invalid', String(showErrors && !input.value.trim()));
      });
      const radio = row.querySelector('input[type="radio"]');
      radio.checked = draft.correct === index;
      radio.addEventListener('change', () => { draft.correct = index; updateSelection(); });
      row.querySelector('[data-remove-choice]').onclick = () => {
        capture();
        draft.remove(index);
        draw(Math.min(index, draft.options.length - 1));
      };
      fieldset.append(row);
    });
    const add = document.createElement('button');
    add.type = 'button';
    add.className = 'button ghost';
    add.textContent = '+ إضافة إجابة';
    add.onclick = () => { capture(); draft.add(); draw(draft.options.length - 1); };
    fieldset.append(add);
    const feedback = document.createElement('p');
    feedback.className = 'form-message error';
    feedback.dataset.choiceError = '';
    feedback.setAttribute('role', 'alert');
    fieldset.append(feedback);
    container.append(fieldset);
    updateSelection();
    if (focusIndex !== undefined) container.querySelectorAll('[data-choice-input]')[focusIndex]?.focus();
  }
  draw();
  return {
    getDraft() { capture(); return { options: [...draft.options], correct: draft.correct }; },
    read() {
      capture();
      try {
        const result = draft.read();
        container.querySelector('[data-choice-error]').textContent = '';
        return result;
      } catch (error) {
        showErrors = true;
        container.querySelectorAll('[data-choice-input]').forEach(input => {
          input.setAttribute('aria-invalid', String(!input.value.trim()));
        });
        container.querySelector('[data-choice-error]').textContent = error.message;
        throw error;
      }
    },
  };
}

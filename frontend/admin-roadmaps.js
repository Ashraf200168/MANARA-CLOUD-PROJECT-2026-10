export function installBookRoadmaps({ api, esc, viewMeta, viewLoaders }) {
  const stylesheet = document.createElement('link');
  stylesheet.rel = 'stylesheet';
  stylesheet.href = '/admin-roadmaps.css?v=1.9.0';
  document.head.append(stylesheet);
  const nav = document.querySelector('#adminNav');
  const button = document.createElement('button');
  button.dataset.view = 'book-roadmaps';
  button.innerHTML = '<span>↝</span>مسارات الكتب';
  nav.insertBefore(button, nav.querySelector('[data-view="books"]'));
  const section = document.createElement('section');
  section.id = 'view-book-roadmaps';
  section.className = 'admin-view';
  document.querySelector('.admin-main').append(section);
  viewMeta['book-roadmaps'] = ['مسارات الكتب', 'درجة كل امتحان ومعدل الكتاب ونسبة الإنجاز لكل طالب'];
  viewLoaders['book-roadmaps'] = loadOverview;

  const labels = { completed: 'مكتمل', violation: 'مخالفة — لا تُحتسب', started: 'قيد الحل', ready: 'بانتظار الحل', not_assigned: 'غير مرتبط', not_configured: 'لم يُحدّد' };
  const statusLabel = status => labels[status] || 'غير مكتمل';
  const number = value => Number.isFinite(Number(value)) ? Number(value) : 0;
  const progress = value => `<progress class="book-roadmap-progress" max="100" value="${Math.max(0, Math.min(100, number(value)))}" aria-label="نسبة الإنجاز"></progress>`;
  const note = '<p class="muted">المعدل = مجموع درجات الامتحانات المسلّمة بلا مخالفة ÷ مجموع درجاتها الكلية. الإنجاز = عدد الامتحانات المسلّمة ÷ امتحانات الكتاب المنشورة والمغلقة. المسودات والمسابقات العامة لا تُحتسب.</p>';
  function errorState(error) {
    section.innerHTML = `<div class="panel"><p role="alert">${esc(error.message)}</p><button class="button ghost" data-roadmap-retry>إعادة المحاولة</button></div>`;
    section.querySelector('[data-roadmap-retry]').onclick = loadOverview;
  }

  async function loadOverview() {
    section.innerHTML = '<p role="status">جارٍ تحميل مسارات الكتب…</p>';
    try {
      const books = await api('/api/admin/book-roadmaps');
      section.innerHTML = `${note}<div class="stack">${books.length ? books.map(({ book, summary, finalExam }) => `<article class="panel">
        <h2>${esc(book.title)}</h2><p>${number(summary.activeExams)} امتحان · ${number(summary.students)} طالب · أكملوا المسار: ${number(summary.completedStudents)}</p>
        ${progress(summary.averageCompletion)}<p>متوسط الإنجاز ${number(summary.averageCompletion)}٪</p>
        <p class="muted">النهائي: ${finalExam ? esc(finalExam.title) : 'لم يُحدّد بعد'}</p>
        <button class="button primary" data-book-roadmap="${number(book.id)}">عرض خارطة الطلاب</button>
      </article>`).join('') : '<p class="empty-card">أضف كتابًا واربط به الامتحانات لبدء المسار.</p>'}</div>`;
      section.querySelectorAll('[data-book-roadmap]').forEach(button => {
        button.onclick = () => loadDetail(number(button.dataset.bookRoadmap));
      });
    } catch (error) { errorState(error); }
  }

  async function loadDetail(id) {
    section.innerHTML = '<p role="status">جارٍ تحميل درجات الطلاب…</p>';
    try {
      const { book, exams, students } = await api(`/api/admin/books/${id}/roadmap`);
      section.innerHTML = `<div class="toolbar"><h2>${esc(book.title)}</h2><div><button class="button ghost small" data-roadmap-back>كل الكتب</button> <button class="button ghost small" data-roadmap-refresh>تحديث</button></div></div>
        ${note}<p>${exams.map(exam => `${number(exam.roadmapPosition)}. ${esc(exam.title)}${exam.isFinal ? ' 🏆 نهائي' : ''}${exam.status === 'draft' ? ' (مسودة)' : ''}`).join(' ← ') || 'لا توجد امتحانات لهذا الكتاب بعد.'}</p>
        <div class="stack">${students.map(student => {
          const results = new Map(student.exams.map(result => [number(result.examId), result]));
          return `<article class="panel"><h3>${esc(student.name)}</h3><code dir="ltr">${esc(student.studentCode)}</code>
            <p><strong>معدل الكتاب حتى الآن: ${student.averagePercentage == null ? 'لم تُسلّم درجات بعد' : `${number(student.averagePercentage)}٪ (${number(student.earnedScore)} من ${number(student.assessedMaxScore)})`}</strong></p>
            ${progress(student.completionRate)}<p>الإنجاز ${number(student.completionRate)}٪ · ${number(student.completedExams)} من ${number(student.totalExams)} امتحان · النهائي: ${esc(statusLabel(student.finalStatus))}</p>
            <div class="book-roadmap-results" role="region" aria-label="درجات الطالب في مسار الكتاب" tabindex="0"><table><thead><tr><th>المحطة / الامتحان</th><th>الدرجة</th><th>النسبة</th><th>الحالة</th></tr></thead><tbody>
            ${exams.map(exam => {
              const result = results.get(number(exam.id));
              return `<tr><td>${number(exam.roadmapPosition)}. ${esc(exam.title)}${exam.isFinal ? ' 🏆' : ''}${exam.status === 'draft' ? ' (مسودة)' : ''}</td><td>${result?.percentage == null ? '—' : `<bdi>${number(result.score)} / ${number(result.maxScore)}</bdi>`}</td><td>${result?.percentage == null ? '—' : `${number(result.percentage)}٪`}</td><td>${esc(statusLabel(result?.status))}</td></tr>`;
            }).join('')}</tbody></table></div></article>`;
        }).join('') || '<p class="empty-card">لم يُربط طلاب بامتحانات هذا الكتاب بعد.</p>'}</div>`;
      section.querySelector('[data-roadmap-back]').onclick = loadOverview;
      section.querySelector('[data-roadmap-refresh]').onclick = () => loadDetail(id);
    } catch (error) { errorState(error); }
  }
}

export function roadmapExamFields(exam, esc) {
  return `<label>ترتيب الامتحان في الكتاب<input name="roadmapPosition" type="number" min="1" step="1" value="${esc(exam.roadmap_position ?? '')}" placeholder="تلقائي بعد آخر امتحان"></label>
    <label>الامتحان النهائي للكتاب<select name="isBookFinal"><option value="false" ${!exam.is_book_final ? 'selected' : ''}>امتحان مرحلي</option><option value="true" ${exam.is_book_final ? 'selected' : ''}>هذا هو النهائي</option></select><small>اختيار نهائي جديد يستبدل علامة النهائي السابقة لهذا الكتاب.</small></label>`;
}

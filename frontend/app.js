const $ = (s,root=document)=>root.querySelector(s);
const $$ = (s,root=document)=>[...root.querySelectorAll(s)];
const escapeHtml = (v='') => String(v).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const apiUrl=url=>window.manaraCloudApi.apiUrl(url);
const api=(url,options={})=>window.manaraCloudApi.request(url,options);
const toast = message => { const e=$('#toast'); e.textContent=message;e.classList.add('show');setTimeout(()=>e.classList.remove('show'),2600); };
const dateText = value => value ? new Intl.DateTimeFormat('ar-SY',{dateStyle:'medium',timeStyle:'short'}).format(new Date(value)) : 'غير محدد';
const arabicNumber = value => Number(value).toLocaleString('ar-SY',{useGrouping:false});
const examCountText = count => count===0?'لا توجد امتحانات':count===1?'امتحان واحد':count===2?'امتحانان':count<=10?`${arabicNumber(count)} امتحانات`:`${arabicNumber(count)} امتحانًا`;
let home,currentStudentExamId=null,studentProfileData=null,timerId,publicQuizId=null,answerTopic='all',examIntegrityCleanup=()=>{},examFinalizing=false,activeDraftKey='';
const manaraChannel='BroadcastChannel' in window?new BroadcastChannel('manara-updates'):null;

const FONT_SIZE_KEY='reading-program-font-size';
function initFontControls(){
  const allowed=['small','normal','large'];
  const apply=size=>{
    const selected=allowed.includes(size)?size:'normal';
    document.documentElement.dataset.fontSize=selected;
    localStorage.setItem(FONT_SIZE_KEY,selected);
    $$('[data-font-size]').forEach(button=>{
      const active=button.dataset.fontSize===selected;
      button.classList.toggle('active',active);
      button.setAttribute('aria-pressed',String(active));
    });
  };
  $$('[data-font-size]').forEach(button=>button.addEventListener('click',()=>apply(button.dataset.fontSize)));
  apply(localStorage.getItem(FONT_SIZE_KEY)||'normal');
}
initFontControls();
delete document.documentElement.dataset.theme;
localStorage.removeItem('reading-program-theme');

const PUBLIC_VIEWS=new Set(['home','books','lantern','exam','ask']);
const PUBLIC_VIEW_TITLES={home:'',books:'المكتبة',lantern:'المسابقات',exam:'صفحة الطالب',ask:'الأسئلة الشرعية'};
let platformTitle='برنامج القراءة الفردية';
function showPublicView(){
  const requested=location.hash.replace(/^#/,'');
  const view=PUBLIC_VIEWS.has(requested)?requested:'home';
  delete document.body.dataset.publicView;
  document.body.dataset.currentView=view;
  document.title=view==='home'?platformTitle:`${PUBLIC_VIEW_TITLES[view]} — ${platformTitle}`;
  $$('[data-public-view]').forEach(section=>section.classList.toggle('active',section.dataset.publicView===view));
  $$('[data-public-route]').forEach(link=>{
    const active=link.dataset.publicRoute===view;
    link.classList.toggle('active',active);
    if(active)link.setAttribute('aria-current','page');else link.removeAttribute('aria-current');
  });
  $('#publicNav').classList.remove('open');
  $('#menuButton').setAttribute('aria-expanded','false');
  window.scrollTo(0,0);
  requestAnimationFrame(()=>requestAnimationFrame(()=>window.scrollTo(0,0)));
  if(view==='books')refreshBooks();
}
window.addEventListener('hashchange',showPublicView);
showPublicView();
function examIsActive(){return Boolean($('#examForm')&&!examFinalizing)}
document.addEventListener('click',event=>{const link=event.target.closest('a[href^="#"]');if(link&&examIsActive()){event.preventDefault();toast('التنقل متوقف أثناء الامتحان لحماية الإجابات.')}},true);

function renderBooks(){
  if(!home)return;
  $('#booksGrid').innerHTML=home.books.length?home.books.map(b=>`<article class="book-card"><div class="book-icon">۞</div><h3>${escapeHtml(b.title)}</h3><p>${escapeHtml(b.description||'كتاب من مكتبة البرنامج')}</p><a class="button ghost small" href="/api/public/book/${b.id}" data-book="${b.id}">قراءة الكتاب</a></article>`).join(''):'<div class="empty-card">ستُضاف الكتب هنا قريبًا.</div>';
  $$('[data-book]').forEach(a=>a.addEventListener('click',async e=>{e.preventDefault();try{const r=await api(`/api/public/book/${a.dataset.book}`);if(r.url){window.open(r.url,'_blank','noopener');return}if(r instanceof Response){const blob=await r.blob();window.open(URL.createObjectURL(blob),'_blank');return}throw new Error();}catch{toast('تعذر فتح الكتاب');}}));
}
async function refreshBooks(){
  try{const latest=await api('/api/public/home');if(!home)home=latest;else home.books=latest.books;renderBooks();}catch(error){console.warn('تعذر تحديث المكتبة',error)}
}

async function loadHome(){
  try{
    home=await api('/api/public/home'); const s=home.settings;
    platformTitle=s.page_title||'برنامج القراءة الفردية'; $('#brandTitle').textContent=platformTitle;$('#footerTitle').textContent=platformTitle;$('#brandSheikh').textContent=s.sheikh_name;$('#welcomeTitle').textContent=s.welcome;$('#bioText').textContent=s.bio;showPublicView();
    renderBooks();
    $('#topicsGrid').innerHTML=home.topics.length?home.topics.map(t=>`<label class="topic-door"><input type="radio" name="topicId" value="${t.id}" required><span class="topic-door-card"><b class="topic-icon">${escapeHtml(t.icon||'◈')}</b><strong>${escapeHtml(t.name)}</strong><small>${escapeHtml(t.description||'')}</small><em dir="ltr">${escapeHtml(t.code)}</em></span></label>`).join(''):'<div class="muted">لا توجد أبواب متاحة الآن.</div>';
    $('#answerFilters').innerHTML=[`<button class="topic-filter active" data-answer-topic="all">كل الأبواب</button>`,...home.topics.map(t=>`<button class="topic-filter" data-answer-topic="${escapeHtml(t.code)}">${escapeHtml(t.icon||'◈')} ${escapeHtml(t.name)}</button>`)].join('');
    $$('[data-answer-topic]').forEach(button=>button.addEventListener('click',()=>{answerTopic=button.dataset.answerTopic;$$('[data-answer-topic]').forEach(item=>item.classList.toggle('active',item===button));renderAnswers()}));
    renderAnswers();
    $('#publicQuizList').innerHTML=home.exams.length?home.exams.map(q=>`<button class="button ghost public-quiz-button" data-public-quiz="${q.id}">${escapeHtml(q.title)} · ${q.duration_minutes} دقيقة</button>`).join(''):'<p class="muted">لا توجد مسابقة عامة منشورة الآن.</p>';
    $$('[data-public-quiz]').forEach(b=>b.addEventListener('click',()=>startPublicQuiz(Number(b.dataset.publicQuiz))));
    const social=[]; if(s.whatsapp)social.push(`<a class="wa" target="_blank" rel="noopener" href="${safeSocial(s.whatsapp,'https://wa.me/')}">و</a>`);if(s.telegram)social.push(`<a class="tg" target="_blank" rel="noopener" href="${safeSocial(s.telegram,'https://t.me/')}">ت</a>`);if(s.instagram)social.push(`<a class="ig" target="_blank" rel="noopener" href="${safeSocial(s.instagram,'https://instagram.com/')}">ا</a>`);$('#socialFloat').innerHTML=social.join('');
    startAyahRotation();
    if(home.advice.length){let i=0;$('#adviceTicker').textContent=home.advice[0].text;setInterval(()=>{$('#adviceTicker').textContent=home.advice[++i%home.advice.length].text},6000)}
  }catch(e){toast(e.message)}
}
let ayahRotationStarted=false;
function startAyahRotation(){
  if(ayahRotationStarted)return;ayahRotationStarted=true;
  const ayat=[
    ['وَقُلْ رَبِّ زِدْنِي عِلْمًا','طه: ١١٤'],
    ['يَرْفَعِ اللَّهُ الَّذِينَ آمَنُوا مِنكُمْ وَالَّذِينَ أُوتُوا الْعِلْمَ دَرَجَاتٍ','المجادلة: ١١'],
    ['إِنَّمَا يَخْشَى اللَّهَ مِنْ عِبَادِهِ الْعُلَمَاءُ','فاطر: ٢٨'],
    ['فَاسْأَلُوا أَهْلَ الذِّكْرِ إِن كُنتُمْ لَا تَعْلَمُونَ','النحل: ٤٣']
  ];let index=0;
  setInterval(()=>{index=(index+1)%ayat.length;const text=$('#rotatingAyah'),source=$('#rotatingAyahSource');text.classList.add('changing');source.classList.add('changing');setTimeout(()=>{text.textContent=ayat[index][0];source.textContent=ayat[index][1];text.classList.remove('changing');source.classList.remove('changing')},260)},8500);
}
manaraChannel?.addEventListener('message',event=>{if(event.data?.type==='books-updated')refreshBooks()});
window.addEventListener('focus',refreshBooks);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)refreshBooks()});
function renderAnswers(){
  const answers=(home?.answers||[]).filter(answer=>answerTopic==='all'||answer.topic_code===answerTopic);
  $('#answersList').innerHTML=answers.length?answers.map(a=>`<article class="answer-item"><div class="answer-meta"><span>${escapeHtml(a.topic_icon||'◈')} ${escapeHtml(a.topic_name||'أخرى')}</span><small>${a.gender==='woman'?'سؤال من امرأة':'سؤال من رجل'} · <b dir="ltr">${escapeHtml(a.public_code)}</b></small></div><p>${escapeHtml(a.question)}</p><p class="answer"><b>جواب الشيخ:</b> ${escapeHtml(a.answer)}</p></article>`).join(''):'<div class="answer-item">لا توجد إجابات منشورة في هذا الباب حتى الآن.</div>';
}
function safeSocial(value,prefix){return /^https:\/\//i.test(value)?escapeHtml(value):prefix+encodeURIComponent(value.replace(/^@|\D/g,m=>prefix.includes('wa')?'':m));}

$('#menuButton').addEventListener('click',()=>{const open=$('#publicNav').classList.toggle('open');$('#menuButton').setAttribute('aria-expanded',String(open))});
$$('#publicNav a').forEach(a=>a.addEventListener('click',()=>{$('#publicNav').classList.remove('open');$('#menuButton').setAttribute('aria-expanded','false')}));

const STUDENT_CODE_KEY='reading-program-student-code';
const savedStudentCode=()=>String(localStorage.getItem(STUDENT_CODE_KEY)||'').trim().toUpperCase();
function showSavedRegistration(){const code=savedStudentCode();if(!code)return false;$('#studentCode').value=code;$('#studentLoginMessage').className='form-message waiting';$('#studentLoginMessage').innerHTML=`<b>لديك طلب مسجل بهذا المتصفح.</b><br>استخدم المعرّف <code dir="ltr">${escapeHtml(code)}</code> لمتابعة الموافقة، ولا تُرسل طلبًا جديدًا.`;$('#showRegistration').textContent='متابعة طلبي السابق';return true}
$('#showRegistration').addEventListener('click',()=>{if(showSavedRegistration()){document.querySelector('#studentLoginForm')?.scrollIntoView({behavior:'smooth',block:'center'});$('#studentCode').focus();return}$('#studentEntry').classList.add('hidden');$('#studentRegistrationForm').classList.remove('hidden');$('#studentRegistrationForm [name="name"]').focus()});
$('#cancelRegistration').addEventListener('click',()=>{$('#studentRegistrationForm').classList.add('hidden');$('#studentEntry').classList.remove('hidden')});
$('#studentRegistrationForm').addEventListener('submit',async event=>{
  event.preventDefault();const message=$('#studentRegistrationMessage'),body=Object.fromEntries(new FormData(event.target)),button=event.submitter;message.className='form-message';message.textContent='جارٍ إرسال الطلب…';if(button)button.disabled=true;
  try{const result=await api('/api/student/register',{method:'POST',body:JSON.stringify(body)});localStorage.setItem(STUDENT_CODE_KEY,result.code);event.target.innerHTML=`<section class="registration-success"><span aria-hidden="true">✓</span><h3>${result.existing?'طلبك مسجل مسبقًا':'تم استلام طلبك'}</h3><p>${escapeHtml(result.message)}</p><div class="permanent-code"><small>معرّفك الدائم</small><code dir="ltr">${escapeHtml(result.code)}</code><button id="copyStudentCode" class="button ghost small" type="button">نسخ المعرّف</button></div><p>احتفظ بهذا المعرّف واستخدمه لمتابعة الموافقة والدخول إلى جميع امتحاناتك.</p><button id="returnToStudentLogin" class="button primary" type="button">متابعة حالة الطلب</button></section>`;$('#copyStudentCode').onclick=async()=>{await navigator.clipboard?.writeText(result.code);toast('تم نسخ المعرّف')};$('#returnToStudentLogin').onclick=()=>{location.reload()};}catch(error){message.textContent=error.message;message.className='form-message error';if(button)button.disabled=false}
});
$('#studentLoginForm').addEventListener('submit',async event=>{event.preventDefault();const message=$('#studentLoginMessage'),studentCode=$('#studentCode').value.trim().toUpperCase();message.className='form-message';message.textContent='جارٍ فتح صفحتك…';try{const result=await api('/api/student/login',{method:'POST',body:JSON.stringify({code:studentCode})});localStorage.setItem(STUDENT_CODE_KEY,studentCode);if(result.status==='pending'){message.className='form-message waiting';message.innerHTML='<b>طلبك قيد المراجعة.</b><br>لم تُنشأ صفحتك بعد، وستتمكن من الدخول بهذا المعرّف نفسه بعد موافقة الشيخ.';return}if(result.status==='rejected'){message.className='form-message error';message.innerHTML=`تعذر قبول الطلب حاليًا.${result.reviewNote?`<br>ملاحظة الشيخ: ${escapeHtml(result.reviewNote)}`:''}`;return}renderStudentDashboard(result)}catch(error){message.textContent=error.message;message.className='form-message error'}});
function renderStudentDashboard(data){
  studentProfileData=data;
  $('#studentEntry').classList.add('hidden');
  $('#studentRegistrationForm').classList.add('hidden');
  $('#examWorkspace').classList.add('hidden');
  const dashboard=$('#studentDashboard'),states={open:'متاح الآن',upcoming:'قادم',ended:'انتهت فترة الدخول',closed:'غير منشور'},assignments=data.assignments||[],next=data.nextExam;
  const rows=assignments.length?assignments.map(item=>`<article class="student-exam-row">
    <span class="student-exam-status ${item.violation_type?'violation':item.state}">${item.violation_type?'مخالفة نزاهة':item.submitted_at?'تم التسليم':states[item.state]||'غير متاح'}</span>
    <span class="student-exam-copy"><b>${escapeHtml(item.title)}</b><small>${item.book_title?escapeHtml(item.book_title)+' · ':''}${arabicNumber(item.duration_minutes)} دقيقة</small>${item.submitted_at&&!item.reviewAvailable?`<small class="review-wait">تتاح مراجعة الإجابات بعد اكتمال مدة محاولتك: ${dateText(item.reviewAvailableAt)}</small>`:''}</span>
    <div class="student-row-actions"><strong>${item.submitted_at?`${arabicNumber(item.score??0)} من ${arabicNumber(item.max_score??0)}`:'فتح الامتحان'}</strong>${item.reviewAvailable?`<button class="button gold small" data-exam-review="${item.exam_id}" type="button">مراجعة الإجابات</button>`:`<button class="button ghost small" data-student-exam="${item.exam_id}" type="button">التفاصيل</button>`}</div>
  </article>`).join(''):'<div class="empty-card">لم يربط الشيخ أي امتحان بصفحتك بعد.</div>';
  dashboard.classList.remove('hidden');
  dashboard.innerHTML=`<section class="student-welcome-card"><div><span class="eyebrow">صفحتك الخاصة</span><h2>مرحبًا ${escapeHtml(data.student.name)}</h2><p>معرّفك الدائم: <code dir="ltr">${escapeHtml(data.student.code)}</code></p></div><div class="student-welcome-actions"><button id="openStudentSupport" class="button primary small" type="button">الدعم الفني</button><button id="studentLogout" class="button ghost small" type="button">تسجيل الخروج</button></div></section>
  ${next?`<section class="next-student-exam"><div><span>الامتحان القادم</span><h3>${escapeHtml(next.title)}</h3><p>${next.state==='open'?'الامتحان متاح الآن':`تبدأ فترة الدخول ${dateText(next.starts_at)}`} · المدة ${arabicNumber(next.duration_minutes)} دقيقة</p></div><button class="button gold" data-student-exam="${next.exam_id}" type="button">${next.state==='open'?'فتح الامتحان':'عرض التفاصيل'}</button></section>`:`<section class="student-empty-next"><span>✓</span><div><h3>لا يوجد امتحان قادم الآن</h3><p>سيظهر هنا تلقائيًا بعد أن يضيفك الشيخ إلى امتحان جديد.</p></div></section>`}
  <section class="student-history"><div class="section-mini-heading"><h3>امتحاناتي ونتائجي</h3><span>${examCountText(assignments.length)}</span></div><div class="student-exam-list">${rows}</div></section><section id="studentSupportPanel" class="student-support-panel hidden"></section>`;
  $$('[data-student-exam]',dashboard).forEach(button=>button.onclick=()=>openStudentExam(Number(button.dataset.studentExam)));$$('[data-exam-review]',dashboard).forEach(button=>button.onclick=()=>openExamReview(Number(button.dataset.examReview)));$('#openStudentSupport').onclick=showStudentSupport;$('#studentLogout').onclick=async()=>{await api('/api/student/logout',{method:'POST'});studentProfileData=null;dashboard.classList.add('hidden');$('#studentEntry').classList.remove('hidden');$('#studentLoginMessage').textContent='تم تسجيل الخروج.'};
}
async function showStudentSupport(){const panel=$('#studentSupportPanel');panel.classList.remove('hidden');panel.innerHTML='<div class="empty-card">جارٍ تحميل طلبات الدعم…</div>';panel.scrollIntoView({behavior:'smooth',block:'start'});try{const tickets=await api('/api/student/support');panel.innerHTML=`<div class="section-mini-heading"><div><span class="eyebrow">الدعم الفني</span><h3>أرسل المشكلة وتابع الرد هنا</h3></div><button id="closeStudentSupport" class="icon-button" type="button" aria-label="إغلاق">×</button></div><form id="studentSupportForm" class="panel stack"><label>عنوان المشكلة<input name="subject" maxlength="120" placeholder="مثال: تعذر فتح السؤال"></label><label>وصف المشكلة<textarea name="message" maxlength="2000" required placeholder="اشرح ما حدث، والجهاز والمتصفح إن أمكن…"></textarea></label><button class="button primary" type="submit">إرسال إلى الدعم الفني</button><p id="studentSupportMessage" class="form-message"></p></form><div class="student-support-list">${tickets.length?tickets.map(ticket=>`<article class="support-ticket ${ticket.status}"><header><b>${escapeHtml(ticket.subject)}</b><span>${ticket.status==='new'?'بانتظار الرد':ticket.status==='answered'?'تم الرد':'مغلق'}</span></header><p>${escapeHtml(ticket.message)}</p>${ticket.reply?`<div class="support-answer"><b>رد الدعم:</b><p>${escapeHtml(ticket.reply)}</p></div>`:''}<small>${dateText(ticket.created_at)}</small></article>`).join(''):'<div class="empty-card">لا توجد طلبات دعم سابقة.</div>'}</div>`;$('#closeStudentSupport').onclick=()=>panel.classList.add('hidden');$('#studentSupportForm').onsubmit=async event=>{event.preventDefault();const message=$('#studentSupportMessage');try{const result=await api('/api/student/support',{method:'POST',body:JSON.stringify(Object.fromEntries(new FormData(event.target))) });message.textContent=result.message;message.className='form-message success';event.target.reset();setTimeout(showStudentSupport,700)}catch(error){message.textContent=error.message;message.className='form-message error'}}}catch(error){panel.innerHTML=`<div class="empty-card">${escapeHtml(error.message)}</div>`}}
async function openExamReview(examId){const dashboard=$('#studentDashboard'),workspace=$('#examWorkspace');dashboard.classList.add('hidden');workspace.classList.remove('hidden');workspace.innerHTML='<div class="empty-card">جارٍ إعداد مراجعة الامتحان…</div>';try{const data=await api(`/api/student/exams/${examId}/review`);workspace.innerHTML=`<button id="backFromReview" class="button ghost small" type="button">→ العودة إلى صفحتي</button><section class="completed-review-summary"><span class="eyebrow">مراجعة بعد اكتمال مدة المحاولة</span><h2>${escapeHtml(data.exam.title)}</h2><strong>${data.result.violationType?'مخالفة نزاهة':`${arabicNumber(data.result.score)} من ${arabicNumber(data.result.maxScore)}`}</strong><p>تظهر إجابتك بجانب الإجابة الصحيحة لتستفيد من مواضع الخطأ.</p></section><div class="exam-review-list">${data.questions.map(q=>`<article class="exam-review-card ${q.correct?'correct':'wrong'}"><header><span>السؤال ${arabicNumber(q.position)}</span><b>${q.correct?'✓ إجابة صحيحة':'× إجابة غير صحيحة'}</b><small>${arabicNumber(q.awarded)} من ${arabicNumber(q.points)}</small></header><h3>${escapeHtml(q.prompt)}</h3><div class="review-answer student"><b>إجابتك</b><p>${escapeHtml(q.studentAnswer?.label||'لم تُجب')}</p></div><div class="review-answer correct"><b>الإجابة الصحيحة</b><p>${escapeHtml(q.correctAnswer?.label||'—')}</p></div>${q.explanation?`<p class="review-note"><b>التوضيح:</b> ${escapeHtml(q.explanation)}</p>`:''}${q.evidence?`<p class="review-note"><b>الدليل أو المصدر:</b> ${escapeHtml(q.evidence)}</p>`:''}</article>`).join('')}</div>`;$('#backFromReview').onclick=()=>renderStudentDashboard(studentProfileData)}catch(error){workspace.innerHTML=`<button id="backFromReview" class="button ghost small" type="button">→ العودة إلى صفحتي</button><div class="empty-card">${escapeHtml(error.message)}</div>`;$('#backFromReview').onclick=()=>renderStudentDashboard(studentProfileData)}}
function openStudentExam(examId){
  const item=studentProfileData?.assignments.find(exam=>exam.exam_id===examId);if(!item)return;currentStudentExamId=examId;const states={open:'متاح الآن',upcoming:'لم تبدأ فترة الدخول',ended:'انتهت فترة الدخول',closed:'غير منشور'},workspace=$('#examWorkspace');$('#studentDashboard').classList.add('hidden');workspace.classList.remove('hidden');workspace.innerHTML=`<button id="backToStudentPage" class="button ghost small" type="button">→ العودة إلى صفحتي</button><div class="exam-header exam-details-header"><div><span class="eyebrow">${escapeHtml(studentProfileData.student.name)}</span><h2>${escapeHtml(item.title)}</h2></div><span class="badge ${item.state}">${item.submitted_at?'تم التسليم':states[item.state]}</span></div>${item.book_title?`<p><b>الكتاب:</b> ${escapeHtml(item.book_title)}</p>`:''}<p>${escapeHtml(item.instructions||'اقرأ الأسئلة بعناية، وتوكّل على الله.')}</p><div class="exam-availability"><p><b>بداية إتاحة الدخول</b><span>${dateText(item.starts_at)}</span></p><p><b>نهاية إتاحة الدخول</b><span>${dateText(item.ends_at)}</span></p><p><b>مدة المحاولة بعد البدء</b><span>${arabicNumber(item.duration_minutes)} دقيقة كاملة</span></p></div>${item.submitted_at?`<div class="lookup-result ${item.violation_type?'integrity-failed':''}"><b>${item.violation_type?'أُنهيت المحاولة لمخالفة ضوابط الامتحان':'تم التسليم'}</b><br>درجتك: ${arabicNumber(item.score??0)} من ${arabicNumber(item.max_score??0)}</div>`:item.state==='open'?`<section class="integrity-warning"><b>تنبيه مهم قبل البدء</b><span>يُسمح بثلاث مغادرات اضطرارية فقط أثناء الامتحان. يجب العودة خلال 30 ثانية في كل مرة؛ المغادرة الرابعة أو تجاوز المهلة يُنهي المحاولة بدرجة صفر. تشمل المغادرة المكالمة، أو تغيير التطبيق، أو تحديث الصفحة، أو فتح تبويب آخر.</span></section><section class="integrity-pledge"><span class="pledge-icon">◇</span><div><h3>قسم الأمانة العلمية</h3><p>أقسم بالله العظيم، وأتعهد أمام الله، أن أجيب عن هذا الامتحان بنفسي، وألّا أستعمل أي وسيلة غش أو أستعين بأي شخص أو مصدر أو جهاز أو وسيلة إلكترونية.</p><label class="pledge-check"><input id="integrityPledge" type="checkbox"><span>قرأتُ القسم وضابط المغادرة وأوافق عليهما وأتحمّل مسؤوليتي أمام الله.</span></label></div></section><button id="startExam" class="button primary" disabled>${item.started_at?'متابعة الامتحان':'بدء الامتحان الآن'}</button>`:'<p class="danger-text">لا يمكن بدء الامتحان خارج فترة إتاحة الدخول.</p>'}`;$('#backToStudentPage').onclick=()=>{workspace.classList.add('hidden');renderStudentDashboard(studentProfileData)};if($('#startExam')){const pledge=$('#integrityPledge'),start=$('#startExam');pledge.onchange=()=>start.disabled=!pledge.checked;start.onclick=startExam}
}
async function refreshStudentProfile(){try{const data=await api('/api/student/profile');renderStudentDashboard(data)}catch{} }
async function startExam(){try{document.documentElement.requestFullscreen?.().catch(()=>{});const data=await api(`/api/student/exams/${currentStudentExamId}/start`,{method:'POST',body:JSON.stringify({pledge:$('#integrityPledge')?.checked===true})});renderExam(data)}catch(error){toast(error.message);if(error.message.includes('صفر'))refreshStudentProfile()}}
function stopExamIntegrity(){examIntegrityCleanup();examIntegrityCleanup=()=>{};}
function activateExamIntegrity(examId,initialState={}){
  stopExamIntegrity();examFinalizing=false;
  const tabId=crypto.randomUUID?.()||`${Date.now()}-${Math.random()}`,lockKey=`manara-exam-lock:${examId}`,channel='BroadcastChannel' in window?new BroadcastChannel(`manara-exam:${examId}`):null,leaveUrl=apiUrl(`/api/student/exams/${examId}/integrity/leave`),returnUrl=apiUrl(`/api/student/exams/${examId}/integrity/return`);
  let leaving=false,returning=false,lockTimer,exitCount=Number(initialState.exitCount)||0;
  const updateStatus=(message='')=>{const status=$('#integrityGraceStatus');if(!status)return;status.classList.toggle('warning',exitCount>0);status.innerHTML=`<b>فرص المغادرة: <span>${Math.max(0,3-exitCount)}</span> من 3 متبقية</b><small>${escapeHtml(message||'لكل مغادرة مهلة عودة قدرها 30 ثانية.')}</small>`};
  const showViolation=result=>{
    examFinalizing=true;clearInterval(timerId);stopExamIntegrity();if(activeDraftKey)localStorage.removeItem(activeDraftKey);document.body.classList.remove('modal-open');$('#examReviewModal')?.remove();
    const reason=result?.reason==='exit_limit'?'تم تجاوز عدد المغادرات الثلاث المسموح بها.':'تم تجاوز مهلة العودة البالغة 30 ثانية.';
    const workspace=$('#examWorkspace');if(workspace)workspace.innerHTML=`<section class="exam-violation-result"><span aria-hidden="true">!</span><h2>أُنهيت المحاولة</h2><p>${reason} لذلك سُجِّلت الدرجة <b>صفرًا</b> وفق ضابط الامتحان.</p></section>`;
  };
  const beginDeparture=async reason=>{
    if(examFinalizing||leaving)return;leaving=true;
    try{const result=await api(leaveUrl,{method:'POST',body:JSON.stringify({reason})});exitCount=Number(result.exitCount)||exitCount;if(result.violation){showViolation(result);return}updateStatus(`سُجّلت المغادرة ${exitCount} من 3؛ عُد خلال 30 ثانية.`)}catch{leaving=false}
  };
  const resumeExam=async()=>{
    if(examFinalizing||returning||!leaving)return;returning=true;
    try{const result=await api(returnUrl,{method:'POST',body:'{}'});exitCount=Number(result.exitCount)||0;if(result.violation){showViolation(result);return}leaving=false;updateStatus(`تمت العودة في الوقت المسموح. استُخدمت ${exitCount} من 3.`);toast('تم استئناف الامتحان ضمن مهلة الأمان')}catch(error){toast(error.message)}finally{returning=false}
  };
  const visibility=()=>{if(document.hidden)beginDeparture('page_hidden');else resumeExam()},pageHide=()=>{if(examFinalizing)return;leaving=true;void api(`/api/student/exams/${examId}/integrity/leave`,{method:'POST',body:JSON.stringify({reason:'page_unloaded'}),keepalive:true}).catch(()=>{})},storage=event=>{if(event.key!==lockKey||!event.newValue)return;try{if(JSON.parse(event.newValue).tabId!==tabId)beginDeparture('duplicate_tab')}catch{}};
  document.addEventListener('visibilitychange',visibility);window.addEventListener('pagehide',pageHide);window.addEventListener('pageshow',resumeExam);window.addEventListener('focus',resumeExam);window.addEventListener('storage',storage);
  channel?.addEventListener('message',event=>{if(event.data?.type==='exam-active'&&event.data.tabId!==tabId)beginDeparture('duplicate_tab')});channel?.postMessage({type:'exam-active',tabId});
  const writeLock=()=>localStorage.setItem(lockKey,JSON.stringify({tabId,at:Date.now()}));writeLock();lockTimer=setInterval(writeLock,3000);
  const block=event=>{event.preventDefault();toast('النسخ واللصق غير متاحين أثناء الامتحان')};const workspace=$('#examWorkspace');['copy','cut','paste','contextmenu'].forEach(type=>workspace?.addEventListener(type,block));
  examIntegrityCleanup=()=>{document.removeEventListener('visibilitychange',visibility);window.removeEventListener('pagehide',pageHide);window.removeEventListener('pageshow',resumeExam);window.removeEventListener('focus',resumeExam);window.removeEventListener('storage',storage);clearInterval(lockTimer);channel?.close();['copy','cut','paste','contextmenu'].forEach(type=>workspace?.removeEventListener(type,block));try{const lock=JSON.parse(localStorage.getItem(lockKey)||'{}');if(lock.tabId===tabId)localStorage.removeItem(lockKey)}catch{}};
  updateStatus();
}
function renderExam(data){
  $('#examReviewModal')?.remove();
  const workspace=$('#examWorkspace'),total=data.questions.length;
  workspace.innerHTML=`<div class="exam-header live-exam-header"><div><span class="eyebrow">${escapeHtml(data.student)}</span><h2>${escapeHtml(data.title)}</h2></div><div class="exam-clock"><span>الوقت المتبقي</span><strong class="timer" id="timer" aria-live="polite">--:--</strong></div></div>
    <section id="integrityGraceStatus" class="exam-integrity-status" aria-live="polite"></section>
    <section class="exam-progress-panel" aria-label="تقدّم الامتحان">
      <div class="exam-progress-copy"><b id="questionProgress">السؤال ١ من ${arabicNumber(total)}</b><span id="answeredProgress">تمت الإجابة عن ٠ من ${arabicNumber(total)}</span></div>
      <div class="exam-progress-track" aria-hidden="true"><span id="examProgressBar"></span></div>
      <div id="questionNavigator" class="question-navigator" aria-label="أرقام الأسئلة">${data.questions.map((_,i)=>`<button type="button" data-go-question="${i}" aria-label="الانتقال إلى السؤال ${i+1}">${arabicNumber(i+1)}</button>`).join('')}</div>
      <p class="navigator-key"><span><i class="answered"></i> مُجاب</span><span><i class="current"></i> الحالي</span><span><i></i> غير مُجاب</span></p>
    </section>
    <form id="examForm" novalidate>
      <div id="questionStage" class="question-stage">${data.questions.map((q,i)=>renderQuestion(q,i)).join('')}</div>
      <div class="exam-nav-actions"><button id="previousQuestion" class="button ghost" type="button">→ السؤال السابق</button><button id="nextQuestion" class="button primary" type="button">السؤال التالي ←</button></div>
      <p class="form-message" id="submitMessage"></p>
    </form>
    <div id="examReviewModal" class="exam-review-modal hidden" role="dialog" aria-modal="true" aria-labelledby="reviewTitle">
      <section class="exam-review-card">
        <div class="review-title"><div><span class="eyebrow">المراجعة النهائية</span><h2 id="reviewTitle">تأكّد قبل تسليم الامتحان</h2></div><button id="closeExamReview" class="icon-button" type="button" aria-label="إغلاق المراجعة">×</button></div>
        <div id="reviewSummary" class="review-summary final-review-summary"></div>
        <div id="unansweredReview" class="unanswered-review"></div>
        <label class="review-confirm"><input id="finalSubmitConsent" type="checkbox"><span>راجعتُ إجاباتي وأفهم أن التسليم نهائي ولا يمكن تعديله بعد ذلك.</span></label>
        <div class="review-actions"><button id="returnToExam" class="button ghost" type="button">العودة إلى الامتحان</button><button id="confirmExamSubmission" class="button gold" type="button" disabled>تأكيد التسليم النهائي</button></div>
      </section>
    </div>`;
  const reviewModal=$('#examReviewModal');document.body.append(reviewModal);
  const form=$('#examForm'),questions=$$('.question-block',form),navButtons=$$('#questionNavigator button'),draftKey=`manara-exam-draft:${currentStudentExamId}:${data.startedAt}`;activeDraftKey=draftKey;activateExamIntegrity(currentStudentExamId,data.integrity||{});
  let currentQuestion=0,draftTimer;
  const isAnswered=question=>{
    const type=question.dataset.type;
    if(type==='matching')return $$('select',question).every(select=>select.value!=='');
    const radio=$('input[type="radio"]:checked',question);if(radio)return true;
    const field=$('input:not([type="radio"]),textarea',question);return Boolean(field?.value.trim());
  };
  const saveDraft=()=>{clearTimeout(draftTimer);draftTimer=setTimeout(()=>{try{localStorage.setItem(draftKey,JSON.stringify(collectAnswers(form)))}catch{}},120)};
  const restoreDraft=()=>{try{const answers=JSON.parse(localStorage.getItem(draftKey)||'{}');questions.forEach(question=>{const id=question.dataset.question,value=answers[id];if(value==null)return;if(question.dataset.type==='matching'){for(let i=0;i<Number(question.dataset.leftCount);i++){const select=$(`[name=q${id}_${i}]`,question);if(select)select.value=value[i]||''}}else{const radios=$$('input[type="radio"]',question);if(radios.length){const radio=radios.find(item=>item.value===String(value));if(radio)radio.checked=true}else{const field=$(`[name=q${id}]`,question);if(field)field.value=value}}})}catch{localStorage.removeItem(draftKey)}};
  const updateProgress=()=>{
    const answered=questions.filter(isAnswered).length;
    $('#questionProgress').textContent=`السؤال ${arabicNumber(currentQuestion+1)} من ${arabicNumber(total)}`;
    $('#answeredProgress').textContent=`تمت الإجابة عن ${arabicNumber(answered)} من ${arabicNumber(total)}`;
    $('#examProgressBar').style.width=`${total?((currentQuestion+1)/total)*100:0}%`;
    navButtons.forEach((button,index)=>{button.classList.toggle('current',index===currentQuestion);button.classList.toggle('answered',isAnswered(questions[index]));button.setAttribute('aria-current',index===currentQuestion?'step':'false')});
  };
  const goToQuestion=(index,moveViewport=false)=>{
    saveDraft();currentQuestion=Math.max(0,Math.min(total-1,index));
    questions.forEach((question,i)=>{const visible=i===currentQuestion;question.classList.toggle('question-hidden',!visible);question.setAttribute('aria-hidden',String(!visible))});
    $('#previousQuestion').disabled=currentQuestion===0;
    const nextButton=$('#nextQuestion'),atLast=currentQuestion===total-1;
    nextButton.textContent=atLast?'مراجعة وتسليم الامتحان':'السؤال التالي ←';
    nextButton.classList.toggle('gold',atLast);nextButton.classList.toggle('primary',!atLast);
    updateProgress();const navigator=$('#questionNavigator'),navButton=navButtons[currentQuestion];if(navigator.scrollHeight>navigator.clientHeight){const top=Math.max(0,navButton.offsetTop-(navigator.clientHeight-navButton.offsetHeight)/2);navigator.scrollTo({top,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'})}
    const firstControl=$('input,select,textarea',questions[currentQuestion]);if(firstControl)firstControl.focus({preventScroll:true});
    if(moveViewport)requestAnimationFrame(()=>{const stage=$('#questionStage'),header=$('.public-header'),top=window.scrollY+stage.getBoundingClientRect().top-(header?.offsetHeight||0)-12;window.scrollTo({top:Math.max(0,top),left:0,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'})});
  };
  const closeReview=()=>{$('#examReviewModal').classList.add('hidden');document.body.classList.remove('modal-open');$('#finalSubmitConsent').checked=false;$('#confirmExamSubmission').disabled=true};
  const openReview=()=>{
    saveDraft();const unanswered=[];questions.forEach((question,index)=>{if(!isAnswered(question))unanswered.push(index)});const answered=total-unanswered.length;
    $('#reviewSummary').innerHTML=`<article><strong>${arabicNumber(total)}</strong><span>إجمالي الأسئلة</span></article><article class="done"><strong>${arabicNumber(answered)}</strong><span>تمت الإجابة</span></article><article class="${unanswered.length?'warning':'done'}"><strong>${arabicNumber(unanswered.length)}</strong><span>بلا إجابة</span></article>`;
    $('#unansweredReview').innerHTML=unanswered.length?`<h3>أسئلة تحتاج إلى مراجعة</h3><p>اضغط على رقم السؤال للعودة إليه:</p><div>${unanswered.map(index=>`<button type="button" data-review-question="${index}">${index+1}</button>`).join('')}</div>`:'<div class="review-complete"><b>أحسنت، أجبت عن جميع الأسئلة.</b><span>يمكنك الآن تأكيد التسليم النهائي.</span></div>';
    $$('[data-review-question]',$('#unansweredReview')).forEach(button=>button.addEventListener('click',()=>{closeReview();goToQuestion(Number(button.dataset.reviewQuestion),true)}));
    $('#examReviewModal').classList.remove('hidden');document.body.classList.add('modal-open');
  };
  restoreDraft();
  form.addEventListener('input',()=>{saveDraft();updateProgress()});form.addEventListener('change',()=>{saveDraft();updateProgress()});
  navButtons.forEach(button=>button.addEventListener('click',()=>goToQuestion(Number(button.dataset.goQuestion),true)));
  $('#previousQuestion').addEventListener('click',()=>goToQuestion(currentQuestion-1,true));$('#nextQuestion').addEventListener('click',()=>currentQuestion===total-1?openReview():goToQuestion(currentQuestion+1,true));
  $('#closeExamReview').addEventListener('click',closeReview);$('#returnToExam').addEventListener('click',closeReview);$('#examReviewModal').addEventListener('click',event=>{if(event.target===$('#examReviewModal'))closeReview()});
  $('#finalSubmitConsent').addEventListener('change',event=>$('#confirmExamSubmission').disabled=!event.target.checked);
  $('#confirmExamSubmission').addEventListener('click',()=>{clearTimeout(draftTimer);submitExam(form,draftKey)});
  goToQuestion(0);
  const deadline=Date.parse(data.deadline);clearInterval(timerId);const tick=()=>{const left=Math.max(0,deadline-Date.now()),m=Math.floor(left/60000),s=Math.floor((left%60000)/1000),clock=`${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;$('#timer').textContent=clock.replace(/\d/g,d=>'٠١٢٣٤٥٦٧٨٩'[Number(d)]);if(!left){clearInterval(timerId);clearTimeout(draftTimer);closeReview();submitExam(form,draftKey,true)}};tick();timerId=setInterval(tick,1000);
}
async function startPublicQuiz(id){
  try{const data=await api(`/api/public/quiz/${id}`);publicQuizId=id;const out=$('#publicQuizWorkspace');out.classList.remove('hidden');out.innerHTML=`<div class="exam-header"><div><span class="eyebrow">مسابقة عامة</span><h2>${escapeHtml(data.title)}</h2><p>${escapeHtml(data.instructions||'اختبر معلوماتك واستفد من النتيجة.')}</p></div></div><form id="publicQuizForm">${data.questions.map((q,i)=>renderQuestion(q,i)).join('')}<button class="button gold">عرض النتيجة</button><p id="publicQuizMessage" class="form-message"></p></form>`;$('#publicQuizForm').addEventListener('submit',submitPublicQuiz);out.scrollIntoView({behavior:'smooth',block:'start'});}catch(e){toast(e.message)}
}
async function submitPublicQuiz(e){e.preventDefault();const answers=collectAnswers(e.target);const msg=$('#publicQuizMessage');try{const r=await api(`/api/public/quiz/${publicQuizId}/submit`,{method:'POST',body:JSON.stringify({answers})});e.target.innerHTML=`<div class="section-heading"><span>النتيجة</span><h2>${r.score} من ${r.maxScore}</h2><p>نسبتك ${r.percentage}٪. يمكنك إعادة المسابقة لتثبيت المعلومة.</p><button type="button" id="repeatQuiz" class="button primary">إعادة المحاولة</button></div>`;$('#repeatQuiz').onclick=()=>startPublicQuiz(publicQuizId);}catch(err){msg.textContent=err.message;msg.className='form-message error'}}
function renderQuestion(q,i){
  let input=''; if(q.type==='choice')input=`<div class="options">${q.options.map((o,x)=>`<label class="option"><input type="radio" name="q${q.id}" value="${x}"><span>${escapeHtml(o)}</span></label>`).join('')}</div>`;
  else if(q.type==='truefalse')input=`<div class="options"><label class="option"><input type="radio" name="q${q.id}" value="true"><span>صحيح</span></label><label class="option"><input type="radio" name="q${q.id}" value="false"><span>خطأ</span></label></div>`;
  else if(q.type==='matching')input=q.left.map((left,x)=>`<div class="matching-row"><span>${escapeHtml(left)}</span><select name="q${q.id}_${x}"><option value="">اختر المطابقة</option>${q.right.map(r=>`<option value="${escapeHtml(r)}">${escapeHtml(r)}</option>`).join('')}</select></div>`).join('');
  else input=`<input name="q${q.id}" placeholder="${escapeHtml(q.placeholder)}">`;
  return `<section class="question-block" data-question="${q.id}" data-type="${q.type}" data-left-count="${q.left?.length||0}"><small>السؤال ${i+1} — ${q.points} درجة</small><h4>${escapeHtml(q.prompt)}</h4>${input}</section>`;
}
async function submitExam(form,draftKey,timeExpired=false){
  const button=$('#confirmExamSubmission'),answers=collectAnswers(form),msg=$('#submitMessage');if(button)button.disabled=true;msg.textContent=timeExpired?'انتهى الوقت، جارٍ تسليم الإجابات المحفوظة…':'جارٍ تسليم الإجابات…';
  examFinalizing=true;stopExamIntegrity();
  try{const r=await api(`/api/student/exams/${currentStudentExamId}/submit`,{method:'POST',body:JSON.stringify({answers})});clearInterval(timerId);localStorage.removeItem(draftKey);activeDraftKey='';document.body.classList.remove('modal-open');$('#examReviewModal')?.remove();$('#examWorkspace').innerHTML=`<div class="section-heading"><span>تم التسليم بنجاح</span><h2>${r.score} من ${r.maxScore}</h2><p>نسبتك ${r.percentage}٪. وصلت النتيجة إلى لوحة الشيخ.</p><button id="returnAfterResult" class="button primary" type="button">العودة إلى صفحتي</button></div>`;$('#returnAfterResult').onclick=refreshStudentProfile;toast('تم حفظ نتيجتك');}catch(err){examFinalizing=false;activateExamIntegrity(currentStudentExamId);msg.textContent=err.message;msg.className='form-message error';if(button)button.disabled=false;}
}
function collectAnswers(form){const answers={};$$('.question-block',form).forEach(q=>{const id=q.dataset.question,type=q.dataset.type;if(type==='matching'){answers[id]={};for(let i=0;i<Number(q.dataset.leftCount);i++)answers[id][i]=$(`[name=q${id}_${i}]`,q)?.value||'';}else answers[id]=$(`[name=q${id}]:checked`,q)?.value??$(`[name=q${id}]`,q)?.value??'';});return answers}

$('#askForm').addEventListener('submit',async e=>{e.preventDefault();const msg=$('#askMessage');try{const gender=$('input[name=gender]:checked')?.value,topicId=Number($('input[name=topicId]:checked')?.value);const r=await api('/api/public/inquiries',{method:'POST',body:JSON.stringify({gender,topicId,question:$('#questionText').value})});msg.className='form-message success';msg.innerHTML=`${escapeHtml(r.message)} في باب <b>${escapeHtml(r.topic)}</b>. رمز المتابعة: <b dir="ltr">${escapeHtml(r.code)}</b>`;$('#lookupCode').value=r.code;e.target.reset();}catch(err){msg.textContent=err.message;msg.className='form-message error';}});
$('#lookupForm').addEventListener('submit',async e=>{e.preventDefault();const out=$('#lookupResult');try{const r=await api(`/api/public/inquiries/${encodeURIComponent($('#lookupCode').value.trim())}`);out.className='lookup-result';out.innerHTML=`<div class="answer-meta"><span>الباب: <b>${escapeHtml(r.topic_name||'أخرى')}</b></span><small>${r.gender==='woman'?'امرأة':'رجل'} · <b dir="ltr">${escapeHtml(r.public_code)}</b></small></div><b>سؤالك:</b><p>${escapeHtml(r.question)}</p>${r.status==='answered'?`<b>جواب الشيخ:</b><p>${escapeHtml(r.answer)}</p>`:'<p>لم تتم الإجابة بعد. احتفظ بالرمز وراجع الصفحة لاحقًا.</p>'}`;}catch(err){out.className='lookup-result danger-text';out.textContent=err.message;}});

$('#studentCode').value=savedStudentCode();
showSavedRegistration();
loadHome();
refreshStudentProfile();

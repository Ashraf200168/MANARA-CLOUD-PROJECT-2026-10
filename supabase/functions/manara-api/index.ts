import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { bearer, code, legacyPasswordHash, normalizeArabic, randomToken, sha256, studentCode, verifyLegacyPassword } from '../_shared/security.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const secretKey = Deno.env.get('SUPABASE_SECRET_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const db = createClient(supabaseUrl, secretKey, { auth: { persistSession: false, autoRefreshToken: false } });

class HttpError extends Error { constructor(public status: number, message: string) { super(message); } }
const fail = (status: number, message: string): never => { throw new HttpError(status, message); };
const body = async (request: Request) => request.headers.get('content-type')?.includes('application/json') ? await request.json() : {};
const now = () => new Date().toISOString();

const xmlEscape = (value: unknown) => String(value ?? '')
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&apos;');

function spreadsheetColumn(index: number) {
  let value = index + 1, output = '';
  while (value > 0) {
    value--;
    output = String.fromCharCode(65 + (value % 26)) + output;
    value = Math.floor(value / 26);
  }
  return output;
}

async function xlsxResponse(request: Request, fileName: string, rows: unknown[][]) {
  const { strToU8, zipSync } = await import('npm:fflate@0.8.2');
  const sheetRows = rows.map((row, rowIndex) => {
    const cells = row.map((value, columnIndex) => {
      const reference = `${spreadsheetColumn(columnIndex)}${rowIndex + 1}`;
      if (typeof value === 'number' && Number.isFinite(value)) {
        return `<c r="${reference}" s="${rowIndex === 0 ? 1 : 0}"><v>${value}</v></c>`;
      }
      return `<c r="${reference}" t="inlineStr" s="${rowIndex === 0 ? 1 : 0}"><is><t xml:space="preserve">${xmlEscape(value)}</t></is></c>`;
    }).join('');
    return `<row r="${rowIndex + 1}">${cells}</row>`;
  }).join('');
  const lastColumn = spreadsheetColumn(Math.max(0, (rows[0]?.length || 1) - 1));
  const files = {
    '[Content_Types].xml': `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>`,
    '_rels/.rels': `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    'xl/workbook.xml': `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView rightToLeft="1"/></bookViews><sheets><sheet name="نتائج الطلاب" sheetId="1" r:id="rId1"/></sheets></workbook>`,
    'xl/_rels/workbook.xml.rels': `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`,
    'xl/styles.xml': `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="12"/><name val="Arial"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="12"/><name val="Arial"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF174A68"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf></cellXfs></styleSheet>`,
    'xl/worksheets/sheet1.xml': `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0" rightToLeft="1"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><dimension ref="A1:${lastColumn}${Math.max(1, rows.length)}"/><cols><col min="1" max="${Math.max(1, rows[0]?.length || 1)}" width="22" customWidth="1"/></cols><sheetData>${sheetRows}</sheetData><autoFilter ref="A1:${lastColumn}${Math.max(1, rows.length)}"/></worksheet>`
  };
  const archive = zipSync(Object.fromEntries(Object.entries(files).map(([name, content]) => [name, strToU8(content)])), { level: 6 });
  const safeName = fileName.replace(/[\\/:*?"<>|]/g, '-').slice(0, 120) || 'manara-results';
  return new Response(archive, {
    headers: {
      ...corsHeaders(request),
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="manara-results.xlsx"; filename*=UTF-8''${encodeURIComponent(`${safeName}.xlsx`)}`,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'X-Manara-Backend': 'supabase-edge'
    }
  });
}

async function one<T>(query: PromiseLike<{ data: T | null; error: { message: string } | null }>, missing = 'العنصر غير موجود'): Promise<T> {
  const { data, error } = await query;
  if (error) throw new Error(error.message);
  if (!data) fail(404, missing);
  return data;
}

async function admin(request: Request) {
  const token = bearer(request); if (!token) return null;
  const hash = await sha256(token);
  const { data } = await db.from('sessions').select('admin_id,expires_at,admins(id,username)').eq('token_hash', hash).gt('expires_at', now()).maybeSingle();
  return data ? (Array.isArray(data.admins) ? data.admins[0] : data.admins) : null;
}

async function requireAdmin(request: Request) {
  const value = await admin(request); if (!value) fail(401, 'يجب تسجيل دخول الشيخ'); return value;
}

async function student(request: Request) {
  const token = bearer(request); if (!token) return null;
  const hash = await sha256(token);
  const { data } = await db.from('student_sessions').select('student_id,expires_at,students(*)').eq('token_hash', hash).gt('expires_at', now()).maybeSingle();
  const value = data ? (Array.isArray(data.students) ? data.students[0] : data.students) : null;
  return value?.status === 'approved' ? value : null;
}

async function requireStudent(request: Request) {
  const value = await student(request); if (!value) fail(401, 'سجّل الدخول إلى صفحتك الطلابية أولًا'); return value;
}

function examState(exam: Record<string, unknown>) {
  const time = Date.now(), start = exam.starts_at ? Date.parse(String(exam.starts_at)) : 0, end = exam.ends_at ? Date.parse(String(exam.ends_at)) : 0;
  if (exam.status !== 'published') return 'closed';
  if (start && time < start) return 'upcoming';
  if (end && time > end) return 'ended';
  return 'open';
}

async function settings() {
  const { data, error } = await db.from('settings').select('key,value');
  if (error) throw new Error(error.message);
  return Object.fromEntries((data || []).map(row => [row.key, row.value]));
}

async function studentProfile(current: Record<string, any>) {
  const { data, error } = await db.from('assignments').select('id,status,exam_id,exams(id,title,instructions,starts_at,ends_at,duration_minutes,status,access_mode,certificate_enabled,certificate_pass_percentage,created_at,books(title)),attempts(started_at,submitted_at,score,max_score,violation_type,violation_at),certificates(certificate_code,issued_at)').eq('student_id', current.id).order('id');
  if (error) throw new Error(error.message);
  const assignments = (data || []).map((row: any) => {
    const exam = Array.isArray(row.exams) ? row.exams[0] : row.exams;
    const attempt = Array.isArray(row.attempts) ? row.attempts[0] : row.attempts;
    const deadline = attempt?.started_at ? Date.parse(attempt.started_at) + Math.max(1, Number(exam.duration_minutes)) * 60000 : 0;
    const active = attempt?.started_at && !attempt?.submitted_at && Date.now() < deadline;
    const percentage = attempt?.max_score > 0 ? Math.round(Number(attempt.score) * 100 / Number(attempt.max_score)) : null;
    const certificateEnabled = Boolean(exam.certificate_enabled);
    const certificatePassPercentage = Number(exam.certificate_pass_percentage ?? 50);
    const certificate = Array.isArray(row.certificates) ? row.certificates[0] : row.certificates;
    return {
      assignment_id: row.id, assignment_status: row.status, exam_id: exam.id, title: exam.title,
      instructions: exam.instructions, starts_at: exam.starts_at, ends_at: exam.ends_at,
      duration_minutes: exam.duration_minutes, exam_status: exam.status,
      book_title: exam.books?.title || null, ...(attempt || {}),
      state: current.is_test || active ? 'open' : examState(exam),
      percentage, certificateEnabled, certificatePassPercentage,
      certificateAvailable: Boolean(certificate || (certificateEnabled && attempt?.submitted_at && !attempt?.violation_type && percentage !== null && percentage >= certificatePassPercentage)),
      certificateIssued: Boolean(certificate),
      certificateCode: certificate?.certificate_code || null,
      certificateIssuedAt: certificate?.issued_at || null,
      reviewAvailable: Boolean(attempt?.submitted_at && deadline && Date.now() >= deadline),
      reviewAvailableAt: deadline ? new Date(deadline).toISOString() : null
    };
  });
  const nextExam = assignments.filter((item: any) => !item.submitted_at && ['open','upcoming'].includes(item.state))[0] || null;
  return { student: { id: current.id, name: current.name, code: current.student_code, gender: current.gender || '', profile: current.profile_json || {} }, nextExam, assignments };
}

async function publicHome() {
  const [books, advice, topics, answers, exams] = await Promise.all([
    db.from('books').select('id,title,description,created_at').order('id', { ascending: false }),
    db.from('advice').select('id,text,author').eq('active', true).order('id', { ascending: false }).limit(12),
    db.from('inquiry_topics').select('id,code,name,description,icon').eq('active', true).order('position'),
    db.from('inquiries').select('public_code,gender,question,answer,answered_at,inquiry_topics(code,name,icon)').eq('status','answered').eq('publish_public',true).order('answered_at',{ascending:false}).limit(60),
    db.from('exams').select('id,title,instructions,starts_at,ends_at,duration_minutes,access_mode,status').eq('status','published').order('id',{ascending:false})
  ]);
  for (const result of [books,advice,topics,answers,exams]) if (result.error) throw new Error(result.error.message);
  const publicExams = (exams.data || []).filter(exam => exam.access_mode === 'public');
  const nextExam = (exams.data || []).filter(exam => exam.starts_at && (!exam.ends_at || Date.parse(exam.ends_at) > Date.now())).sort((a,b)=>Date.parse(a.starts_at!)-Date.parse(b.starts_at!))[0] || null;
  return { settings: await settings(), books: books.data, advice: advice.data, topics: topics.data, answers: (answers.data || []).map((item:any)=>({...item,topic_code:item.inquiry_topics?.code,topic_name:item.inquiry_topics?.name,topic_icon:item.inquiry_topics?.icon})), exams: publicExams, nextExam };
}

async function dashboard() {
  const [studentsResult,examsResult,assignmentsResult,inquiriesResult,supportResult]=await Promise.all([
    db.from('students').select('*').order('id'),
    db.from('exams').select('*,questions(id,points)').order('id',{ascending:false}),
    db.from('assignments').select('*,students(name,student_code,is_test),exams(title),attempts(*)').order('id',{ascending:false}),
    db.from('inquiries').select('*,inquiry_topics(name,icon)').order('id',{ascending:false}),
    db.from('support_tickets').select('id,status')
  ]);
  for(const result of [studentsResult,examsResult,assignmentsResult,inquiriesResult,supportResult])if(result.error)throw new Error(result.error.message);
  const students=studentsResult.data||[],exams=examsResult.data||[],assignments=assignmentsResult.data||[],inquiries=inquiriesResult.data||[],approved=students.filter((item:any)=>!item.is_test&&item.status==='approved'),registrations=students.filter((item:any)=>!item.is_test&&item.status==='pending');
  const assignmentRows=assignments.map((item:any)=>{const person=Array.isArray(item.students)?item.students[0]:item.students,exam=Array.isArray(item.exams)?item.exams[0]:item.exams,attempt=Array.isArray(item.attempts)?item.attempts[0]:item.attempts;return {...item,name:person?.name,student_code:person?.student_code,is_test:person?.is_test,title:exam?.title,...(attempt||{})}});
  const submitted=assignmentRows.filter((item:any)=>item.submitted_at),integrity=submitted.filter((item:any)=>item.violation_type),pendingRows=inquiries.filter((item:any)=>item.status==='new').map((item:any)=>({...item,topic_name:item.inquiry_topics?.name,topic_icon:item.inquiry_topics?.icon}));
  const resultsByDay=[];for(let offset=6;offset>=0;offset--){const day=new Date();day.setUTCDate(day.getUTCDate()-offset);const key=day.toISOString().slice(0,10),items=submitted.filter((item:any)=>String(item.submitted_at).slice(0,10)===key);resultsByDay.push({day:key,results:items.length,violations:items.filter((item:any)=>item.violation_type).length});}
  const bands={excellent:0,good:0,pass:0,below_pass:0};for(const item of submitted.filter((row:any)=>!row.violation_type)){const percentage=Number(item.max_score)>0?Number(item.score)*100/Number(item.max_score):0;if(percentage>=85)bands.excellent++;else if(percentage>=70)bands.good++;else if(percentage>=50)bands.pass++;else bands.below_pass++;}
  const realByExam=new Map<number,number>();for(const item of assignmentRows)if(!item.is_test)realByExam.set(item.exam_id,(realByExam.get(item.exam_id)||0)+1);
  const examRows=exams.map((exam:any)=>({id:exam.id,title:exam.title,duration_minutes:exam.duration_minutes,status:exam.status,question_count:exam.questions?.length||0,total_points:(exam.questions||[]).reduce((sum:number,q:any)=>sum+Number(q.points),0),student_count:realByExam.get(exam.id)||0}));
  const test=assignmentRows.find((item:any)=>item.is_test)||null;
  return {students:approved.length,registrations:registrations.length,exams:exams.length,submissions:submitted.length,integrityViolations:integrity.length,pending:pendingRows.length,supportPending:(supportResult.data||[]).filter((item:any)=>item.status==='new').length,recent:submitted.slice(0,40),studentRows:assignmentRows.filter((item:any)=>!item.is_test).map((item:any)=>({name:item.name,student_code:item.student_code,exam_title:item.title,status:item.status})),registrationRows:registrations.map((item:any)=>({name:item.name,student_code:item.student_code,profile:item.profile_json||{},created_at:item.created_at})),examRows,submissionRows:submitted,pendingRows,testAssignment:test?{id:test.id,name:test.name,student_code:test.student_code,exam_title:test.title}:null,resultsByDay,scoreBands:Object.entries(bands).map(([band,count])=>({band,count}))};
}

async function adminStudents(){
  const [studentsResult,assignmentsResult]=await Promise.all([db.from('students').select('*').eq('is_test',false).order('id',{ascending:false}),db.from('assignments').select('*,exams(title,status),attempts(*)').order('id')]);
  if(studentsResult.error)throw new Error(studentsResult.error.message);if(assignmentsResult.error)throw new Error(assignmentsResult.error.message);
  const all=studentsResult.data||[],byStudent=new Map<number,any[]>();for(const item of assignmentsResult.data||[]){if(!byStudent.has(item.student_id))byStudent.set(item.student_id,[]);const exam:any=Array.isArray(item.exams)?item.exams[0]:item.exams,attempt:any=Array.isArray(item.attempts)?item.attempts[0]:item.attempts;byStudent.get(item.student_id)!.push({assignmentId:item.id,assignmentStatus:item.status,examTitle:exam?.title||'',examStatus:exam?.status||'',startedAt:attempt?.started_at||null,submittedAt:attempt?.submitted_at||null,score:attempt?.score??null,maxScore:attempt?.max_score??null,percentage:attempt?.max_score>0?Math.round(Number(attempt.score)*100/Number(attempt.max_score)):null,violationType:attempt?.violation_type||'',violationAt:attempt?.violation_at||null});}
  const map=(item:any)=>({id:item.id,name:item.name,code:item.student_code,gender:item.gender||'',status:item.status,profile:item.profile_json||{},reviewNote:item.review_note||'',createdAt:item.created_at,lastAccessAt:item.last_access_at,assignments:byStudent.get(item.id)||[]});
  const students=all.filter((item:any)=>item.status==='approved').map(map),pending=all.filter((item:any)=>item.status==='pending').map(map),rejected=all.filter((item:any)=>item.status==='rejected').map(map),submitted=students.flatMap((item:any)=>item.assignments).filter((item:any)=>item.submittedAt),scored=submitted.filter((item:any)=>item.maxScore>0);
  return {stats:{totalStudents:students.length,pendingRequests:pending.length,submitted:submitted.length,averagePercentage:scored.length?Math.round(scored.reduce((sum:number,item:any)=>sum+Number(item.percentage||0),0)/scored.length):0},students,pending,rejected};
}

function positiveInteger(value: unknown) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

async function nextRoadmapPosition(bookId: number) {
  const result = await db.from('exams')
    .select('roadmap_position')
    .eq('book_id', bookId)
    .order('roadmap_position', { ascending: false, nullsFirst: false })
    .limit(1);
  if (result.error) throw new Error(result.error.message);
  return Number(result.data?.[0]?.roadmap_position || 0) + 1;
}

async function bookRoadmap(bookId: number) {
  const book = await one<any>(
    db.from('books').select('id,title,description,created_at').eq('id', bookId).maybeSingle(),
    'الكتاب غير موجود',
  );
  const examsResult = await db.from('exams')
    .select('id,title,status,roadmap_position,is_book_final,created_at,questions(id,points)')
    .eq('book_id', bookId)
    .eq('access_mode', 'private')
    .order('is_book_final', { ascending: true })
    .order('roadmap_position', { ascending: true, nullsFirst: false })
    .order('id', { ascending: true });
  if (examsResult.error) throw new Error(examsResult.error.message);
  const rawExams = examsResult.data || [];
  const examIds = rawExams.map((exam: any) => Number(exam.id));
  let assignments: any[] = [];
  if (examIds.length) {
    for (let offset = 0; ; offset += 1000) {
      const assignmentsResult = await db.from('assignments')
      .select('id,exam_id,student_id,status,students(id,name,student_code,is_test,status),attempts(started_at,submitted_at,score,max_score,violation_type)')
      .in('exam_id', examIds)
      .order('id')
      .range(offset, offset + 999);
      if (assignmentsResult.error) throw new Error(assignmentsResult.error.message);
      assignments.push(...(assignmentsResult.data || []));
      if ((assignmentsResult.data || []).length < 1000) break;
    }
  }
  const exams = rawExams.map((exam: any, index: number) => ({
    id: Number(exam.id),
    title: exam.title,
    status: exam.status,
    roadmapPosition: positiveInteger(exam.roadmap_position) || index + 1,
    isFinal: Boolean(exam.is_book_final),
    countsTowardCompletion: exam.status !== 'draft',
    questionCount: exam.questions?.length || 0,
    totalPoints: (exam.questions || []).reduce((sum: number, question: any) => sum + Number(question.points || 0), 0),
  }));
  const activeExams = exams.filter((exam: any) => exam.countsTowardCompletion);
  const finalExam = exams.find((exam: any) => exam.isFinal) || null;
  const people = new Map<number, any>();
  const assignmentByStudentAndExam = new Map<string, any>();
  for (const assignment of assignments) {
    const person = Array.isArray(assignment.students) ? assignment.students[0] : assignment.students;
    if (!person || person.is_test || person.status !== 'approved') continue;
    people.set(Number(person.id), person);
    assignmentByStudentAndExam.set(`${person.id}:${assignment.exam_id}`, assignment);
  }
  const students = [...people.values()].map((person: any) => {
    let completedExams = 0, earnedScore = 0, availableScore = 0;
    const examProgress = exams.map((exam: any) => {
      const assignment = assignmentByStudentAndExam.get(`${person.id}:${exam.id}`);
      if (!assignment) return { examId: exam.id, status: 'not_assigned', assignmentStatus: null, score: null, maxScore: null, percentage: null, submittedAt: null, violationType: null };
      const attempt = Array.isArray(assignment.attempts) ? assignment.attempts[0] : assignment.attempts;
      const submitted = Boolean(attempt?.submitted_at), violationType = attempt?.violation_type || null;
      const maxScore = submitted && attempt?.max_score != null ? Number(attempt.max_score) : null;
      const score = submitted && attempt?.score != null ? Number(attempt.score) : null;
      const percentage = maxScore && maxScore > 0 && score != null ? Math.round(score * 100 / maxScore) : null;
      const validCompletion = submitted && !violationType && maxScore != null && Number.isFinite(maxScore) && maxScore > 0 && score != null && Number.isFinite(score);
      if (exam.countsTowardCompletion && validCompletion) {
        completedExams++;
        earnedScore += score || 0;
        availableScore += maxScore;
      }
      return {
        examId: exam.id,
        status: violationType ? 'violation' : submitted ? 'completed' : assignment.status || 'ready',
        assignmentStatus: assignment.status || null,
        score,
        maxScore,
        percentage,
        submittedAt: attempt?.submitted_at || null,
        violationType,
      };
    });
    const totalExams = activeExams.length;
    const finalProgress = finalExam ? examProgress.find((progress: any) => progress.examId === finalExam.id) : null;
    return {
      id: Number(person.id),
      name: person.name,
      studentCode: person.student_code,
      completedExams,
      totalExams,
      completionRate: totalExams ? Math.round(completedExams * 100 / totalExams) : 0,
      averagePercentage: availableScore > 0 ? Math.round(earnedScore * 100 / availableScore) : null,
      earnedScore,
      assessedMaxScore: availableScore,
      finalStatus: finalProgress?.status || (finalExam ? 'not_assigned' : 'not_configured'),
      exams: examProgress,
    };
  }).sort((a: any, b: any) => b.completionRate - a.completionRate || String(a.name).localeCompare(String(b.name), 'ar'));
  const averageCompletion = students.length ? Math.round(students.reduce((sum: number, person: any) => sum + person.completionRate, 0) / students.length) : 0;
  return {
    book,
    exams,
    finalExam,
    summary: {
      totalExams: exams.length,
      activeExams: activeExams.length,
      students: students.length,
      averageCompletion,
      completedStudents: students.filter((person: any) => activeExams.length > 0 && person.completedExams === activeExams.length).length,
    },
    students,
  };
}

async function bookRoadmapOverview() {
  const booksResult = await db.from('books').select('id').order('id', { ascending: false });
  if (booksResult.error) throw new Error(booksResult.error.message);
  const roadmaps = await Promise.all((booksResult.data || []).map((book: any) => bookRoadmap(Number(book.id))));
  return roadmaps.map((roadmap: any) => ({
    book: roadmap.book,
    finalExam: roadmap.finalExam,
    summary: roadmap.summary,
  }));
}

function publicQuestion(row: any) {
  const data=row.data_json||{}, base={id:row.id,type:row.type,prompt:row.prompt,points:Number(row.points),position:row.position};
  if(row.type==='choice')return {...base,options:data.options||[]};
  if(row.type==='truefalse')return base;
  if(row.type==='matching')return {...base,left:(data.pairs||[]).map((pair:any)=>pair.left),right:(data.pairs||[]).map((pair:any)=>pair.right).sort(()=>Math.random()-.5)};
  return {...base,placeholder:'اكتب إجابتك المختصرة'};
}

function grade(row:any,answer:any){
  const data=row.data_json||{},points=Number(row.points);
  if(row.type==='choice')return Number(answer)===Number(data.correct)?points:0;
  if(row.type==='truefalse')return String(answer)===String(Boolean(data.correct))?points:0;
  if(row.type==='short')return (data.accepted||[]).some((value:string)=>normalizeArabic(value)===normalizeArabic(answer))?points:0;
  if(row.type==='matching'){const pairs=data.pairs||[],value=answer||{};return pairs.length&&pairs.every((pair:any,index:number)=>normalizeArabic(value[index])===normalizeArabic(pair.right))?points:0;}
  return 0;
}

function boundedPercentage(value: unknown, fallback = 50) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.min(100, Math.max(0, parsed)) : fallback;
}

function certificateGrade(percentage: number) {
  if (percentage >= 90) return 'ممتاز';
  if (percentage >= 80) return 'جيد جدًا';
  if (percentage >= 70) return 'جيد';
  if (percentage >= 60) return 'مقبول';
  return 'ناجح';
}

async function studentAssignment(studentId:number,examId:number){
  const {data,error}=await db.from('assignments').select('*,students(name,gender,is_test,profile_json),exams(*,books(title))').eq('student_id',studentId).eq('exam_id',examId).maybeSingle();
  if(error)throw new Error(error.message);if(!data)return null;
  const exam:any=Array.isArray(data.exams)?data.exams[0]:data.exams,person:any=Array.isArray(data.students)?data.students[0]:data.students;
  return {...data,student_name:person.name,student_profile:person.profile_json||{},gender:person.gender,is_test:person.is_test,...exam,id:data.id,assignment_id:data.id,exam_id:exam.id,exam_status:exam.status,book_title:exam.books?.title||null};
}

async function attemptFor(assignmentId:number){const {data,error}=await db.from('attempts').select('*').eq('assignment_id',assignmentId).maybeSingle();if(error)throw new Error(error.message);return data;}
const deadlineFor=(assignment:any,attempt:any)=>Date.parse(attempt.started_at)+Math.max(1,Number(assignment.duration_minutes))*60000;

async function certificateRanking(examId: number, assignmentId: number) {
  const { data, error } = await db.from('assignments')
    .select('id,students(is_test),attempts(submitted_at,score,max_score,violation_type)')
    .eq('exam_id', examId);
  if (error) throw new Error(error.message);

  const results = (data || []).map((row: any) => {
    const person = Array.isArray(row.students) ? row.students[0] : row.students;
    const attempt = Array.isArray(row.attempts) ? row.attempts[0] : row.attempts;
    const maximum = Number(attempt?.max_score);
    if (person?.is_test || !attempt?.submitted_at || attempt?.violation_type || !Number.isFinite(maximum) || maximum <= 0) return null;
    return {
      assignmentId: Number(row.id),
      percentage: Number(attempt.score || 0) * 100 / maximum,
      submittedAt: String(attempt.submitted_at)
    };
  }).filter(Boolean) as Array<{ assignmentId: number; percentage: number; submittedAt: string }>;

  results.sort((left, right) => right.percentage - left.percentage || Date.parse(left.submittedAt) - Date.parse(right.submittedAt));
  const currentIndex = results.findIndex(item => item.assignmentId === assignmentId);
  if (currentIndex < 0) return { rank: null, participants: results.length };
  const currentPercentage = results[currentIndex].percentage;
  const rank = results.findIndex(item => Math.abs(item.percentage - currentPercentage) < 0.000001) + 1;
  return { rank, participants: results.length };
}

async function persistedCertificate(assignment: any, attempt: any, studentName: string) {
  const existing = await db.from('certificates').select('*').eq('assignment_id', assignment.id).maybeSingle();
  if (existing.error) throw new Error(existing.error.message);
  if (existing.data) return existing.data;

  const score = Number(attempt.score || 0);
  const maxScore = Number(attempt.max_score);
  const percentage = Math.round(score * 100 / maxScore);
  for (let tries = 0; tries < 3; tries += 1) {
    const inserted = await db.from('certificates').insert({
      assignment_id: assignment.id,
      certificate_code: code('CRT'),
      student_name: studentName,
      exam_title: assignment.title,
      score,
      max_score: maxScore,
      percentage
    }).select('*').maybeSingle();
    if (!inserted.error && inserted.data) return inserted.data;
    if (inserted.error?.code !== '23505') throw new Error(inserted.error?.message || 'تعذر إنشاء الشهادة');
    const concurrent = await db.from('certificates').select('*').eq('assignment_id', assignment.id).maybeSingle();
    if (concurrent.error) throw new Error(concurrent.error.message);
    if (concurrent.data) return concurrent.data;
  }
  throw new Error('تعذر إنشاء رمز فريد للشهادة؛ أعد المحاولة');
}

async function certificateDocument(assignment: any, certificate: any) {
  const [programSettings, ranking] = await Promise.all([
    settings(),
    certificateRanking(Number(assignment.exam_id), Number(assignment.id))
  ]);
  const percentage = Number(certificate.percentage);
  return {
    certificateTitle: 'شهادة تفوق وتميز علمي',
    certificateCode: certificate.certificate_code,
    studentName: certificate.student_name,
    examTitle: certificate.exam_title,
    bookTitle: assignment.book_title || null,
    score: Number(certificate.score),
    maxScore: Number(certificate.max_score),
    percentage,
    grade: certificateGrade(percentage),
    rank: ranking.rank,
    participants: ranking.participants,
    issuedAt: certificate.issued_at,
    sheikhName: programSettings.sheikh_name || 'مشرف البرنامج',
    programTitle: programSettings.page_title || 'برنامج القراءة الفردية',
    passPercentage: boundedPercentage(assignment.certificate_pass_percentage, 50),
    eligible: true
  };
}

async function examQuestions(examId:number){const {data,error}=await db.from('questions').select('*').eq('exam_id',examId).order('position').order('id');if(error)throw new Error(error.message);return data||[];}

function reviewValue(type:string,data:any,value:any){
  if(value===null||value===undefined||value==='')return null;
  if(type==='choice')return {value:Number(value),label:data.options?.[Number(value)]??String(value)};
  if(type==='truefalse')return {value:String(value),label:String(value)==='true'?'صح':'خطأ'};
  if(type==='matching')return {value,label:Object.entries(value||{}).map(([key,right])=>`${data.pairs?.[Number(key)]?.left||key}: ${right}`).join('، ')};
  return {value,label:String(value)};
}

function correctReview(row:any){const data=row.data_json||{};if(row.type==='choice')return reviewValue(row.type,data,data.correct);if(row.type==='truefalse')return reviewValue(row.type,data,Boolean(data.correct));if(row.type==='matching')return {value:Object.fromEntries((data.pairs||[]).map((pair:any,index:number)=>[index,pair.right])),label:(data.pairs||[]).map((pair:any)=>`${pair.left}: ${pair.right}`).join('، ')};return {value:data.accepted||[],label:(data.accepted||[]).join('، ')};}

async function submitExam(assignment:any,answers:Record<string,unknown>){
  const attempt=await attemptFor(assignment.id);if(!attempt)fail(409,'لم يبدأ الامتحان');if(attempt.submitted_at)fail(409,'تم التسليم سابقًا');if(Date.now()>deadlineFor(assignment,attempt)+15000)fail(403,'انتهى وقت الامتحان');
  const questions=await examQuestions(assignment.exam_id);let score=0,maxScore=0;const rows=questions.map((question:any)=>{const awarded=grade(question,answers[question.id]);score+=awarded;maxScore+=Number(question.points);return {attempt_id:attempt.id,question_id:question.id,answer_json:answers[question.id]??null,awarded};});
  const removed=await db.from('answers').delete().eq('attempt_id',attempt.id);if(removed.error)throw new Error(removed.error.message);if(rows.length){const inserted=await db.from('answers').insert(rows);if(inserted.error)throw new Error(inserted.error.message);}
  const submittedAt=now(),updated=await db.from('attempts').update({submitted_at:submittedAt,score,max_score:maxScore}).eq('id',attempt.id).is('submitted_at',null);if(updated.error)throw new Error(updated.error.message);await db.from('assignments').update({status:'submitted'}).eq('id',assignment.id);
  const percentage=maxScore?Math.round(score/maxScore*100):0;
  let certificateCode:string|null=null;
  if(!assignment.is_test&&assignment.certificate_enabled&&maxScore>0&&percentage>=boundedPercentage(assignment.certificate_pass_percentage,50)){
    const fullName=String(assignment.student_profile?.fullName||'').trim(),studentName=fullName||String(assignment.student_name||'').trim();
    const certificate=await persistedCertificate(assignment,{...attempt,submitted_at:submittedAt,score,max_score:maxScore},studentName);
    certificateCode=certificate.certificate_code;
  }
  return {score,maxScore,percentage,certificateAvailable:Boolean(certificateCode),certificateCode};
}

async function integrityFailure(assignment:any,attempt:any,reason:string){
  if(attempt.submitted_at)return {score:Number(attempt.score)||0,maxScore:Number(attempt.max_score)||0,percentage:attempt.max_score?Math.round(Number(attempt.score)*100/Number(attempt.max_score)):0,violation:Boolean(attempt.violation_type),reason:attempt.violation_type||'',exitCount:Number(attempt.integrity_exit_count)||0};
  const questions=await examQuestions(assignment.exam_id),maxScore=questions.reduce((sum:number,item:any)=>sum+Number(item.points),0),when=now();await db.from('answers').delete().eq('attempt_id',attempt.id);await db.from('attempts').update({submitted_at:when,score:0,max_score:maxScore,violation_type:reason,violation_at:when,integrity_exit_started_at:null,integrity_exit_reason:''}).eq('id',attempt.id);await db.from('assignments').update({status:'submitted'}).eq('id',assignment.id);return {score:0,maxScore,percentage:0,violation:true,reason,exitCount:Number(attempt.integrity_exit_count)||0,message:'أُنهيت المحاولة لمخالفة ضوابط الامتحان وسُجّلت الدرجة صفرًا'};
}

async function integrityDeparture(assignment:any,reason:string){
  const attempt=await attemptFor(assignment.id);if(!attempt)fail(409,'لم يبدأ الامتحان');if(attempt.submitted_at)return integrityFailure(assignment,attempt,attempt.violation_type||reason);if(attempt.integrity_exit_started_at)return {violation:false,exitCount:Number(attempt.integrity_exit_count)||0,remainingExits:Math.max(0,3-Number(attempt.integrity_exit_count||0)),graceSeconds:30,graceActive:true,graceDeadline:new Date(Date.parse(attempt.integrity_exit_started_at)+30000).toISOString()};
  const count=Number(attempt.integrity_exit_count||0)+1;if(count>3)return integrityFailure(assignment,attempt,'exit_limit');const started=now();await db.from('attempts').update({integrity_exit_count:count,integrity_exit_started_at:started,integrity_exit_reason:reason}).eq('id',attempt.id);return {violation:false,exitCount:count,remainingExits:Math.max(0,3-count),graceSeconds:30,graceActive:true,graceDeadline:new Date(Date.parse(started)+30000).toISOString()};
}

async function integrityReturn(assignment:any){
  const attempt=await attemptFor(assignment.id);if(!attempt)fail(409,'لم يبدأ الامتحان');if(attempt.submitted_at)return integrityFailure(assignment,attempt,attempt.violation_type||'exit_timeout');if(attempt.integrity_exit_started_at&&Date.now()>Date.parse(attempt.integrity_exit_started_at)+30000)return integrityFailure(assignment,attempt,'exit_timeout');if(attempt.integrity_exit_started_at)await db.from('attempts').update({integrity_exit_started_at:null,integrity_exit_reason:''}).eq('id',attempt.id);const count=Number(attempt.integrity_exit_count)||0;return {violation:false,exitCount:count,remainingExits:Math.max(0,3-count),graceSeconds:30,graceActive:false,graceDeadline:null,status:'active',resumed:true};
}

async function route(request: Request, path: string): Promise<Response> {
  const method = request.method,currentUrl=new URL(request.url);
  if (path === '/api/health' && method === 'GET') return jsonResponse(request,{ok:true,version:'cloud-baseline-1.9.0',database:'ready',storage:'ready',backend:'supabase',time:now()});
  if (path === '/api/public/home' && method === 'GET') return jsonResponse(request,await publicHome());
  if (path === '/api/public/visit' && method === 'POST') {
    const value = await body(request), visitor = request.headers.get('cf-connecting-ip') || request.headers.get('x-forwarded-for') || randomToken(12);
    await db.from('site_visits').insert({visitor_hash:await sha256(visitor),page:['home','books','lantern','exam','ask'].includes(value.page)?value.page:'home'});
    return jsonResponse(request,{recorded:true},201);
  }
  if (path === '/api/student/register' && method === 'POST') {
    const existingToken=request.headers.get('x-manara-registration')||'';
    if(existingToken){const {data}=await db.from('students').select('id,name,student_code,status,review_note').eq('registration_token_hash',await sha256(existingToken)).eq('is_test',false).maybeSingle();if(data)return jsonResponse(request,{id:data.id,code:data.student_code,status:data.status,existing:true,reviewNote:data.review_note||'',registrationToken:existingToken,message:'طلبك السابق محفوظ؛ لا حاجة إلى التسجيل مرة أخرى.'});}
    const value=await body(request),name=String(value.name||'').trim();if(name.length<2||name.length>80)fail(400,'اكتب اسمًا أو لقبًا من حرفين على الأقل');
    const registrationToken=randomToken(), profile={fullName:String(value.fullName||'').slice(0,120),country:String(value.country||'').slice(0,80),city:String(value.city||'').slice(0,80),ageRange:String(value.ageRange||'').slice(0,40),education:String(value.education||'').slice(0,120),contact:String(value.contact||'').slice(0,160),about:String(value.about||'').slice(0,600)};
    const created=await one<any>(db.from('students').insert({name,gender:['man','woman'].includes(value.gender)?value.gender:'',identity_key:normalizeArabic(name),student_code:studentCode(),status:'pending',profile_json:profile,registration_token_hash:await sha256(registrationToken)}).select('id,student_code,status').single());
    return jsonResponse(request,{id:created.id,code:created.student_code,status:created.status,existing:false,registrationToken,message:'وصل طلبك إلى الشيخ. احتفظ بالمعرّف لمتابعة الموافقة، ولا ترسل طلبًا جديدًا عند تحديث الصفحة.'},201);
  }
  if(path==='/api/student/login'&&method==='POST'){
    const value=await body(request),studentCodeValue=String(value.code||'').trim().toUpperCase();
    const current=await one<any>(db.from('students').select('*').eq('student_code',studentCodeValue).maybeSingle(),'المعرّف غير صحيح');
    if(current.status!=='approved')return jsonResponse(request,{status:current.status,name:current.name,reviewNote:current.review_note||''});
    const token=randomToken(),expires=new Date(Date.now()+30*86400000).toISOString();await db.from('student_sessions').delete().eq('student_id',current.id);await db.from('student_sessions').insert({token_hash:await sha256(token),student_id:current.id,expires_at:expires});await db.from('students').update({last_access_at:now()}).eq('id',current.id);
    return jsonResponse(request,{status:'approved',studentToken:token,...await studentProfile(current)});
  }
  if(path==='/api/student/logout'&&method==='POST'){const token=bearer(request);if(token)await db.from('student_sessions').delete().eq('token_hash',await sha256(token));return jsonResponse(request,{ok:true,clearStudentToken:true});}
  if(path==='/api/student/profile'&&method==='GET'){return jsonResponse(request,await studentProfile(await requireStudent(request)));}
  if(path==='/api/student/profile'&&method==='PUT'){
    const current=await requireStudent(request),value=await body(request),name=String(value.name??current.name).trim();
    if(name.length<2||name.length>80)fail(400,'الاسم أو اللقب يجب أن يكون بين حرفين و80 حرفًا');
    const gender=value.gender===undefined?String(current.gender||''):String(value.gender||'');
    if(!['','man','woman'].includes(gender))fail(400,'قيمة الجنس غير صالحة');
    const incoming=value.profile&&typeof value.profile==='object'&&!Array.isArray(value.profile)?value.profile:{},profile={...(current.profile_json||{})};
    const limits:Record<string,number>={fullName:120,country:80,city:80,ageRange:40,education:120,contact:160,about:600};
    for(const [key,limit] of Object.entries(limits))if(Object.prototype.hasOwnProperty.call(incoming,key))profile[key]=String(incoming[key]??'').trim().slice(0,limit);
    const updated=await one<any>(db.from('students').update({name,gender,identity_key:normalizeArabic(name),profile_json:profile}).eq('id',current.id).eq('status','approved').select('*').single());
    return jsonResponse(request,await studentProfile(updated));
  }
  if(path==='/api/student/support'&&method==='GET'){const current=await requireStudent(request);const {data,error}=await db.from('support_tickets').select('id,subject,message,reply,status,created_at,replied_at,updated_at').eq('student_id',current.id).order('id',{ascending:false}).limit(50);if(error)throw new Error(error.message);return jsonResponse(request,data);}
  if(path==='/api/student/support'&&method==='POST'){const current=await requireStudent(request),value=await body(request),message=String(value.message||'').trim();if(message.length<5||message.length>2000)fail(400,'اكتب وصفًا للمشكلة بين 5 و2000 حرف');const created=await one<any>(db.from('support_tickets').insert({student_id:current.id,subject:String(value.subject||'مشكلة تقنية').slice(0,120),message}).select('id').single());return jsonResponse(request,{id:created.id,message:'وصل طلب الدعم، وستظهر إجابة الداعم في صفحتك نفسها.'},201);}
  const startExam=path.match(/^\/api\/student\/exams\/(\d+)\/start$/);if(startExam&&method==='POST'){const current=await requireStudent(request),value=await body(request),assignment=await studentAssignment(current.id,Number(startExam[1]));if(!assignment)fail(404,'هذا الامتحان غير مرتبط بصفحتك');if(value.pledge!==true)fail(400,'يجب الموافقة على قسم الأمانة قبل بدء الامتحان');let attempt=await attemptFor(assignment.id);if(attempt?.submitted_at)fail(409,'تم تسليم هذا الامتحان بالفعل');if(!attempt&&!assignment.is_test&&examState({...assignment,status:assignment.exam_status})!=='open')fail(403,'الامتحان غير متاح الآن');if(attempt&&Date.now()>deadlineFor(assignment,attempt)+15000)fail(403,'انتهى وقت الامتحان');if(!attempt){const started=now();attempt=await one<any>(db.from('attempts').insert({assignment_id:assignment.id,started_at:started,pledged_at:started}).select('*').single());await db.from('assignments').update({status:'started'}).eq('id',assignment.id);}const integrity=await integrityReturn(assignment);if(integrity.violation)fail(409,'انتهت مهلة العودة إلى الامتحان وسُجّلت الدرجة صفرًا');return jsonResponse(request,{student:assignment.student_name,title:assignment.title,startedAt:attempt.started_at,deadline:new Date(deadlineFor(assignment,attempt)).toISOString(),questions:(await examQuestions(assignment.exam_id)).map(publicQuestion),integrity});}
  const submit=path.match(/^\/api\/student\/exams\/(\d+)\/submit$/);if(submit&&method==='POST'){const current=await requireStudent(request),assignment=await studentAssignment(current.id,Number(submit[1]));if(!assignment)fail(404,'هذا الامتحان غير مرتبط بصفحتك');const value=await body(request);return jsonResponse(request,await submitExam(assignment,value.answers||{}));}
  const leave=path.match(/^\/api\/student\/exams\/(\d+)\/(?:violation|integrity\/leave)$/);if(leave&&method==='POST'){const current=await requireStudent(request),assignment=await studentAssignment(current.id,Number(leave[1]));if(!assignment)fail(404,'هذا الامتحان غير مرتبط بصفحتك');const value=await body(request);return jsonResponse(request,await integrityDeparture(assignment,String(value.reason||'page_hidden')));}
  const returning=path.match(/^\/api\/student\/exams\/(\d+)\/integrity\/return$/);if(returning&&method==='POST'){const current=await requireStudent(request),assignment=await studentAssignment(current.id,Number(returning[1]));if(!assignment)fail(404,'هذا الامتحان غير مرتبط بصفحتك');return jsonResponse(request,await integrityReturn(assignment));}
  const review=path.match(/^\/api\/student\/exams\/(\d+)\/review$/);if(review&&method==='GET'){const current=await requireStudent(request),assignment=await studentAssignment(current.id,Number(review[1]));if(!assignment)fail(404,'هذا الامتحان غير مرتبط بصفحتك');const attempt=await attemptFor(assignment.id);if(!attempt?.submitted_at)fail(409,'لم يُسلَّم الامتحان بعد');const availableAt=deadlineFor(assignment,attempt);if(Date.now()<availableAt)fail(403,`تتاح مراجعة الإجابات بعد اكتمال مدة محاولتك: ${new Date(availableAt).toLocaleString('ar-SY')}`);const questions=await examQuestions(assignment.exam_id),answersResult=await db.from('answers').select('*').eq('attempt_id',attempt.id),answers=new Map((answersResult.data||[]).map((item:any)=>[item.question_id,item]));return jsonResponse(request,{exam:{id:assignment.exam_id,title:assignment.title,reviewAvailableAt:new Date(availableAt).toISOString()},result:{score:Number(attempt.score)||0,maxScore:Number(attempt.max_score)||0,violationType:attempt.violation_type||''},questions:questions.map((question:any)=>{const answer:any=answers.get(question.id),data=question.data_json||{};return {id:question.id,position:question.position,type:question.type,prompt:question.prompt,points:Number(question.points),awarded:Number(answer?.awarded)||0,correct:Number(answer?.awarded)>=Number(question.points),studentAnswer:reviewValue(question.type,data,answer?.answer_json),correctAnswer:correctReview(question),explanation:String(data.explanation||data.guidance||''),evidence:String(data.evidence||data.bank?.sourceNote||'')}})});}
  const certificateRoute=path.match(/^\/api\/student\/exams\/(\d+)\/certificate$/);if(certificateRoute&&method==='GET'){
    const current=await requireStudent(request);
    if(current.is_test)fail(403,'حساب تجربة الشيخ لا يستحق شهادة طالب');
    const assignment=await studentAssignment(current.id,Number(certificateRoute[1]));
    if(!assignment)fail(404,'هذا الامتحان غير مرتبط بصفحتك');
    const existing=await db.from('certificates').select('*').eq('assignment_id',assignment.id).maybeSingle();
    if(existing.error)throw new Error(existing.error.message);
    if(existing.data)return jsonResponse(request,await certificateDocument(assignment,existing.data));
    if(!assignment.certificate_enabled)fail(403,'لم يحدد الشيخ هذا الامتحان لمنح الشهادات');
    const attempt=await attemptFor(assignment.id);
    if(!attempt?.submitted_at)fail(409,'لا تصدر الشهادة قبل تسليم الامتحان');
    if(attempt.violation_type)fail(403,'لا تصدر شهادة لمحاولة مسجل عليها مخالفة نزاهة');
    const maxScore=Number(attempt.max_score),score=Number(attempt.score||0);
    if(!Number.isFinite(maxScore)||maxScore<=0)fail(409,'لا يمكن إصدار شهادة لامتحان بلا درجة كلية صالحة');
    const percentage=Math.round(score*100/maxScore),passPercentage=boundedPercentage(assignment.certificate_pass_percentage,50);
    if(percentage<passPercentage)fail(403,`تحتاج إلى ${passPercentage}٪ على الأقل لاستحقاق الشهادة، ونتيجتك ${percentage}٪`);
    const fullName=String(current.profile_json?.fullName||'').trim(),studentName=fullName||String(assignment.student_name||current.name).trim();
    const issued=await persistedCertificate(assignment,attempt,studentName);
    return jsonResponse(request,await certificateDocument(assignment,issued));
  }
  const book=path.match(/^\/api\/public\/book\/(\d+)$/);if(book&&method==='GET'){const row=await one<any>(db.from('books').select('file_name').eq('id',book[1]).maybeSingle(),'الكتاب غير موجود');const {data,error}=await db.storage.from('manara-books').createSignedUrl(row.file_name,3600);if(error)throw new Error(error.message);return jsonResponse(request,{url:data.signedUrl});}
  const quiz=path.match(/^\/api\/public\/quiz\/(\d+)$/);if(quiz&&method==='GET'){const exam=await one<any>(db.from('exams').select('*').eq('id',quiz[1]).eq('status','published').eq('access_mode','public').maybeSingle(),'المسابقة غير متاحة');if(examState(exam)!=='open')fail(403,'المسابقة غير متاحة في هذا الوقت');return jsonResponse(request,{id:exam.id,title:exam.title,instructions:exam.instructions,durationMinutes:exam.duration_minutes,questions:(await examQuestions(exam.id)).map(publicQuestion)});}
  const quizSubmit=path.match(/^\/api\/public\/quiz\/(\d+)\/submit$/);if(quizSubmit&&method==='POST'){const exam=await one<any>(db.from('exams').select('*').eq('id',quizSubmit[1]).eq('status','published').eq('access_mode','public').maybeSingle(),'المسابقة غير متاحة');if(examState(exam)!=='open')fail(403,'المسابقة غير متاحة');const value=await body(request),questions=await examQuestions(exam.id);let score=0,maxScore=0;for(const question of questions){score+=grade(question,(value.answers||{})[question.id]);maxScore+=Number(question.points);}return jsonResponse(request,{score,maxScore,percentage:maxScore?Math.round(score/maxScore*100):0});}
  if(path==='/api/public/inquiries'&&method==='POST'){const value=await body(request);if(!['man','woman'].includes(value.gender))fail(400,'اختر رجل أو امرأة');const topic=await one<any>(db.from('inquiry_topics').select('id,code,name').eq('id',Number(value.topicId)).eq('active',true).maybeSingle(),'اختر باب السؤال');const question=String(value.question||'').trim();if(question.length<5||question.length>2000)fail(400,'السؤال يجب أن يكون بين 5 و2000 حرف');const publicCode=code(`${topic.code}-${value.gender==='woman'?'W':'M'}`);await db.from('inquiries').insert({public_code:publicCode,topic_id:topic.id,gender:value.gender,question});return jsonResponse(request,{code:publicCode,topic:topic.name,message:'تم إرسال سؤالك بسرية'},201);}
  const inquiry=path.match(/^\/api\/public\/inquiries\/([A-Z0-9-]+)$/i);if(inquiry&&method==='GET'){const item=await one<any>(db.from('inquiries').select('public_code,gender,question,answer,status,created_at,answered_at,inquiry_topics(code,name)').eq('public_code',inquiry[1].toUpperCase()).maybeSingle(),'رمز السؤال غير موجود');return jsonResponse(request,{...item,topic_code:item.inquiry_topics?.code,topic_name:item.inquiry_topics?.name});}
  if(path==='/api/admin/login'&&method==='POST'){const value=await body(request),record=await one<any>(db.from('admins').select('*').eq('username',String(value.username||'')).maybeSingle(),'بيانات الدخول غير صحيحة');if(!await verifyLegacyPassword(String(value.password||''),record.password_hash))fail(401,'بيانات الدخول غير صحيحة');const token=randomToken(),expires=new Date(Date.now()+12*3600000).toISOString();await db.from('sessions').insert({token_hash:await sha256(token),admin_id:record.id,expires_at:expires});return jsonResponse(request,{ok:true,adminToken:token,username:record.username});}
  if(path==='/api/admin/logout'&&method==='POST'){const token=bearer(request);if(token)await db.from('sessions').delete().eq('token_hash',await sha256(token));return jsonResponse(request,{ok:true,clearAdminToken:true});}
  if(path==='/api/admin/session'&&method==='GET'){const current=await requireAdmin(request);return jsonResponse(request,current);}
  await requireAdmin(request);
  if(path==='/api/admin/dashboard'&&method==='GET')return jsonResponse(request,await dashboard());
  if(path==='/api/admin/students'&&method==='GET')return jsonResponse(request,await adminStudents());
  const studentStatus=path.match(/^\/api\/admin\/students\/(\d+)\/status$/);if(studentStatus&&method==='PUT'){const value=await body(request);if(!['approved','rejected'].includes(value.status))fail(400,'الحالة المطلوبة غير صالحة');const updated=await one<any>(db.from('students').update({status:value.status,review_note:String(value.reviewNote||'').slice(0,500),...(value.status==='approved'?{approved_at:now()}: {})}).eq('id',studentStatus[1]).eq('is_test',false).select('student_code').single());return jsonResponse(request,{ok:true,status:value.status,code:updated.student_code});}
  const studentAdmin=path.match(/^\/api\/admin\/students\/(\d+)$/);if(studentAdmin&&method==='PUT'){const current=await one<any>(db.from('students').select('*').eq('id',studentAdmin[1]).eq('is_test',false).maybeSingle(),'طلب الطالب غير موجود'),value=await body(request),name=String(value.name??current.name).trim();if(name.length<2||name.length>80)fail(400,'الاسم أو اللقب يجب أن يكون بين حرفين و80 حرفًا');const profile={...(current.profile_json||{}),...(value.profile&&typeof value.profile==='object'?value.profile:{})};for(const key of Object.keys(profile))profile[key]=String(profile[key]||'').trim().slice(0,key==='about'?600:160);const result=await db.from('students').update({name,gender:['','man','woman'].includes(value.gender)?value.gender:current.gender,identity_key:normalizeArabic(name),profile_json:profile,review_note:String(value.reviewNote??current.review_note).slice(0,500)}).eq('id',current.id);if(result.error)throw new Error(result.error.message);return jsonResponse(request,{ok:true});}
  if(studentAdmin&&method==='DELETE'){const result=await db.from('students').delete().eq('id',studentAdmin[1]).eq('is_test',false);if(result.error)throw new Error(result.error.message);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/settings'&&method==='GET')return jsonResponse(request,await settings());
  if(path==='/api/admin/settings'&&method==='PUT'){const value=await body(request),allowed=['sheikh_name','page_title','bio','whatsapp','telegram','instagram','welcome'];for(const key of allowed)if(key in value){const {error}=await db.from('settings').upsert({key,value:String(value[key]).slice(0,2000)});if(error)throw new Error(error.message);}return jsonResponse(request,await settings());}
  if(path==='/api/admin/change-password'&&method==='POST'){const current=await requireAdmin(request),value=await body(request),record=await one<any>(db.from('admins').select('password_hash').eq('id',current.id).single());if(!await verifyLegacyPassword(String(value.currentPassword||''),record.password_hash))fail(400,'كلمة المرور الحالية غير صحيحة');const next=String(value.newPassword||'');if(next.length<10)fail(400,'كلمة المرور الجديدة يجب أن تكون 10 أحرف على الأقل');const token=bearer(request),hash=await sha256(token);await db.from('admins').update({password_hash:await legacyPasswordHash(next)}).eq('id',current.id);await db.from('sessions').delete().eq('admin_id',current.id).neq('token_hash',hash);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/support'&&method==='GET'){const {data,error}=await db.from('support_tickets').select('*,students(name,student_code)').order('id',{ascending:false});if(error)throw new Error(error.message);return jsonResponse(request,(data||[]).map((item:any)=>({...item,student_name:item.students?.name,student_code:item.students?.student_code})));}
  const supportAdmin=path.match(/^\/api\/admin\/support\/(\d+)$/);if(supportAdmin&&method==='PUT'){const value=await body(request),reply=String(value.reply||'').trim().slice(0,4000),status=['new','answered','closed'].includes(value.status)?value.status:(reply?'answered':'new'),stamp=now();const result=await db.from('support_tickets').update({reply,status,updated_at:stamp,...(status==='answered'?{replied_at:stamp}:{})}).eq('id',supportAdmin[1]);if(result.error)throw new Error(result.error.message);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/books'&&method==='GET'){const {data,error}=await db.from('books').select('id,title,description,original_name,created_at').order('id',{ascending:false});if(error)throw new Error(error.message);return jsonResponse(request,data);}
  if(path==='/api/admin/book-roadmaps'&&method==='GET')return jsonResponse(request,await bookRoadmapOverview());
  const bookRoadmapRoute=path.match(/^\/api\/admin\/books\/(\d+)\/roadmap$/);if(bookRoadmapRoute&&method==='GET')return jsonResponse(request,await bookRoadmap(Number(bookRoadmapRoute[1])));
  if(path==='/api/admin/books'&&method==='POST'){const title=String(currentUrl.searchParams.get('title')||'').trim(),description=String(currentUrl.searchParams.get('description')||'').trim(),original=String(currentUrl.searchParams.get('name')||'book.pdf').replace(/[^\p{L}\p{N}._ -]/gu,'_');if(!title)fail(400,'اسم الكتاب مطلوب');const bytes=new Uint8Array(await request.arrayBuffer());if(bytes.length<5||new TextDecoder().decode(bytes.slice(0,5))!=='%PDF-')fail(400,'الملف يجب أن يكون PDF صالحًا');const file=`${Date.now()}-${randomToken(4)}.pdf`,upload=await db.storage.from('manara-books').upload(file,bytes,{contentType:'application/pdf'});if(upload.error)throw new Error(upload.error.message);const created=await one<any>(db.from('books').insert({title,description,file_name:file,original_name:original}).select('id').single());return jsonResponse(request,{id:created.id},201);}
  const bookAdmin=path.match(/^\/api\/admin\/books\/(\d+)$/);if(bookAdmin&&method==='DELETE'){const row=await one<any>(db.from('books').select('file_name').eq('id',bookAdmin[1]).maybeSingle(),'الكتاب غير موجود');await db.from('books').delete().eq('id',bookAdmin[1]);await db.storage.from('manara-books').remove([row.file_name]);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/advice'&&method==='GET'){const {data,error}=await db.from('advice').select('*').order('id',{ascending:false});if(error)throw new Error(error.message);return jsonResponse(request,data);}
  if(path==='/api/admin/advice'&&method==='POST'){const value=await body(request),text=String(value.text||'').trim();if(!text)fail(400,'نص الفائدة مطلوب');const created=await one<any>(db.from('advice').insert({text,author:String(value.author||'').trim(),active:value.active!==false}).select('id').single());return jsonResponse(request,{id:created.id},201);}
  const adviceAdmin=path.match(/^\/api\/admin\/advice\/(\d+)$/);if(adviceAdmin&&method==='DELETE'){await db.from('advice').delete().eq('id',adviceAdmin[1]);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/exams'&&method==='GET'){const {data,error}=await db.from('exams').select('*,books(title),questions(id,points),assignments(id,students(is_test))').order('id',{ascending:false});if(error)throw new Error(error.message);return jsonResponse(request,(data||[]).map((item:any)=>({...item,book_title:item.books?.title||null,question_count:item.questions?.length||0,total_points:(item.questions||[]).reduce((sum:number,q:any)=>sum+Number(q.points),0),student_count:(item.assignments||[]).filter((a:any)=>!a.students?.is_test).length})));}
  if(path==='/api/admin/exams'&&method==='POST'){const value=await body(request),title=String(value.title||'').trim(),bookId=positiveInteger(value.bookId);if(!title)fail(400,'عنوان الامتحان مطلوب');const roadmapPosition=bookId?(positiveInteger(value.roadmapPosition)||await nextRoadmapPosition(bookId)):null;const created=await one<any>(db.from('exams').insert({title,book_id:bookId,instructions:String(value.instructions||''),starts_at:value.startsAt||null,ends_at:value.endsAt||null,duration_minutes:Math.max(1,Number(value.durationMinutes)||30),status:['draft','published','closed'].includes(value.status)?value.status:'draft',access_mode:value.accessMode==='public'?'public':'private',certificate_enabled:value.certificateEnabled===true,certificate_pass_percentage:boundedPercentage(value.certificatePassPercentage,50),roadmap_position:roadmapPosition,is_book_final:Boolean(bookId&&value.isBookFinal===true)}).select('id').single());return jsonResponse(request,{id:created.id},201);}
  const examAdmin=path.match(/^\/api\/admin\/exams\/(\d+)$/);if(examAdmin&&method==='GET'){const exam=await one<any>(db.from('exams').select('*').eq('id',examAdmin[1]).maybeSingle(),'الامتحان غير موجود'),questionsResult=await db.from('questions').select('*').eq('exam_id',exam.id).order('position').order('id'),assignmentsResult=await db.from('assignments').select('*,students(name,gender,student_code,is_test)').eq('exam_id',exam.id).order('id'),studentsResult=await db.from('students').select('id,name,student_code').eq('is_test',false).eq('status','approved').order('name');const assigned=new Set((assignmentsResult.data||[]).map((item:any)=>item.student_id));return jsonResponse(request,{exam,questions:(questionsResult.data||[]).map((q:any)=>({...q,data:q.data_json||{}})),assignments:(assignmentsResult.data||[]).map((item:any)=>({...item,...item.students})),availableStudents:(studentsResult.data||[]).filter((item:any)=>!assigned.has(item.id))});}
  if(examAdmin&&method==='PUT'){const current=await one<any>(db.from('exams').select('*').eq('id',examAdmin[1]).maybeSingle(),'الامتحان غير موجود'),value=await body(request),has=(name:string)=>Object.prototype.hasOwnProperty.call(value,name),bookId=has('bookId')?positiveInteger(value.bookId):positiveInteger(current.book_id),sameBook=bookId===positiveInteger(current.book_id);const roadmapPosition=bookId?(positiveInteger(value.roadmapPosition)||(sameBook?positiveInteger(current.roadmap_position):null)||await nextRoadmapPosition(bookId)):null;const result=await db.from('exams').update({title:String(value.title??current.title).trim(),book_id:bookId,instructions:String(value.instructions??current.instructions),starts_at:has('startsAt')?value.startsAt??null:current.starts_at,ends_at:has('endsAt')?value.endsAt??null:current.ends_at,duration_minutes:Math.max(1,Number(value.durationMinutes??current.duration_minutes)),status:['draft','published','closed'].includes(value.status)?value.status:current.status,access_mode:value.accessMode==='public'?'public':value.accessMode==='private'?'private':current.access_mode,certificate_enabled:value.certificateEnabled===undefined?Boolean(current.certificate_enabled):value.certificateEnabled===true,certificate_pass_percentage:boundedPercentage(value.certificatePassPercentage,current.certificate_pass_percentage==null?50:Number(current.certificate_pass_percentage)),roadmap_position:roadmapPosition,is_book_final:Boolean(bookId&&(value.isBookFinal===undefined?current.is_book_final:value.isBookFinal===true))}).eq('id',current.id);if(result.error)throw new Error(result.error.message);return jsonResponse(request,{ok:true});}
  if(examAdmin&&method==='DELETE'){await db.from('exams').delete().eq('id',examAdmin[1]);return jsonResponse(request,{ok:true});}
  const questionsCollection=path.match(/^\/api\/admin\/exams\/(\d+)\/questions$/);if(questionsCollection&&method==='POST'){const value=await body(request);if(!['choice','truefalse','matching','short'].includes(value.type))fail(400,'نوع السؤال غير مدعوم');const prompt=String(value.prompt||'').trim();if(!prompt)fail(400,'نص السؤال مطلوب');const existing=await db.from('questions').select('position').eq('exam_id',questionsCollection[1]).order('position',{ascending:false}).limit(1),position=Number(existing.data?.[0]?.position||0)+1,created=await one<any>(db.from('questions').insert({exam_id:Number(questionsCollection[1]),type:value.type,prompt,points:Math.max(.25,Number(value.points)||1),data_json:value.data||{},position}).select('id').single());return jsonResponse(request,{id:created.id},201);}
  const questionAdmin=path.match(/^\/api\/admin\/questions\/(\d+)$/);if(questionAdmin&&method==='PUT'){const current=await one<any>(db.from('questions').select('*').eq('id',questionAdmin[1]).maybeSingle(),'السؤال غير موجود'),value=await body(request),result=await db.from('questions').update({type:value.type||current.type,prompt:String(value.prompt??current.prompt),points:Math.max(.25,Number(value.points??current.points)),data_json:value.data??current.data_json,position:Number(value.position??current.position)}).eq('id',current.id);if(result.error)throw new Error(result.error.message);return jsonResponse(request,{ok:true});}
  if(questionAdmin&&method==='DELETE'){await db.from('questions').delete().eq('id',questionAdmin[1]);return jsonResponse(request,{ok:true});}
  const assignStudents=path.match(/^\/api\/admin\/exams\/(\d+)\/students$/);if(assignStudents&&method==='POST'){const value=await body(request),ids=[...new Set((value.studentIds||[]).map(Number))].slice(0,500),created=[];if(!ids.length)fail(400,'اختر طالبًا واحدًا على الأقل من الطلاب المقبولين');for(const id of ids){const person=await db.from('students').select('id,name,student_code').eq('id',id).eq('is_test',false).eq('status','approved').maybeSingle();if(!person.data)continue;const result=await db.from('assignments').upsert({exam_id:Number(assignStudents[1]),student_id:id,exam_code:code('ASG')},{onConflict:'exam_id,student_id',ignoreDuplicates:true}).select('id');if(!result.error&&result.data?.length)created.push({name:person.data.name,studentCode:person.data.student_code});}return jsonResponse(request,{created,alreadyAssigned:[]},201);}
  const assignmentAdmin=path.match(/^\/api\/admin\/assignments\/(\d+)$/);if(assignmentAdmin&&method==='DELETE'){await db.from('assignments').delete().eq('id',assignmentAdmin[1]);return jsonResponse(request,{ok:true});}
  const assignmentsXlsx=path.match(/^\/api\/admin\/exams\/(\d+)\/assignments\.xlsx$/);if(assignmentsXlsx&&method==='GET'){const exam=await one<any>(db.from('exams').select('id,title').eq('id',assignmentsXlsx[1]).maybeSingle(),'الامتحان غير موجود'),result=await db.from('assignments').select('status,students(name,student_code,is_test),attempts(started_at,submitted_at,score,max_score,violation_type)').eq('exam_id',exam.id).order('id');if(result.error)throw new Error(result.error.message);const statuses:Record<string,string>={ready:'جاهز للبدء',started:'قيد الحل',submitted:'تم التسليم'},headers=['الطالب','المعرّف الدائم','الحالة','الدرجة','الدرجة الكلية','النسبة','مخالفة النزاهة','وقت البدء','وقت التسليم'],rows=(result.data||[]).map((item:any)=>{const person=Array.isArray(item.students)?item.students[0]:item.students,attempt=Array.isArray(item.attempts)?item.attempts[0]:item.attempts;if(person?.is_test)return null;const maxScore=attempt?.max_score==null?'':Number(attempt.max_score),score=attempt?.score==null?'':Number(attempt.score),percentage=typeof score==='number'&&typeof maxScore==='number'&&maxScore>0?Math.round(score*100/maxScore):'';return [person?.name||'',person?.student_code||'',statuses[item.status]||item.status||'غير محدد',score,maxScore,percentage===''?'':`${percentage}٪`,attempt?.violation_type?'نعم':'لا',attempt?.started_at||'',attempt?.submitted_at||''];}).filter(Boolean) as unknown[][];return xlsxResponse(request,`نتائج-${exam.title}`,[headers,...rows]);}
  const results=path.match(/^\/api\/admin\/exams\/(\d+)\/results$/);if(results&&method==='GET'){const {data,error}=await db.from('assignments').select('status,students(name,gender,student_code,is_test),attempts(started_at,submitted_at,score,max_score,violation_type,violation_at)').eq('exam_id',results[1]);if(error)throw new Error(error.message);return jsonResponse(request,(data||[]).map((item:any)=>{const person=item.students,attempt=Array.isArray(item.attempts)?item.attempts[0]:item.attempts;return {...person,status:item.status,...(attempt||{}),percentage:attempt?.max_score>0?Math.round(Number(attempt.score)*100/Number(attempt.max_score)):null}}));}
  if(path==='/api/admin/test-assignment/reset'&&method==='POST'){const value=await body(request),assignment=await one<any>(db.from('assignments').select('id,students(is_test)').eq('id',Number(value.assignmentId)).maybeSingle(),'معرّف تجربة الشيخ غير موجود');if(!assignment.students?.is_test)fail(404,'معرّف تجربة الشيخ غير موجود');await db.from('attempts').delete().eq('assignment_id',assignment.id);await db.from('assignments').update({status:'ready'}).eq('id',assignment.id);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/exams/import-first'&&method==='POST')fail(409,'الاختبار الأول يُنقل تلقائيًا مع نسخة البيانات من الخادم الحالي، ولا يحتاج إلى استيراد مستقل في السحابة');
  if(path==='/api/admin/topics'&&method==='GET'){const [topicsResult,inquiriesResult]=await Promise.all([db.from('inquiry_topics').select('*').order('position').order('id'),db.from('inquiries').select('topic_id')]);if(topicsResult.error)throw new Error(topicsResult.error.message);return jsonResponse(request,(topicsResult.data||[]).map((item:any)=>({...item,inquiry_count:(inquiriesResult.data||[]).filter((q:any)=>q.topic_id===item.id).length})));}
  if(path==='/api/admin/topics'&&method==='POST'){const value=await body(request),topicCode=String(value.code||'').trim().toUpperCase(),name=String(value.name||'').trim();if(!/^[A-Z0-9]{2,6}$/.test(topicCode))fail(400,'رمز الباب يجب أن يكون من 2 إلى 6 أحرف أو أرقام إنجليزية');const created=await one<any>(db.from('inquiry_topics').insert({code:topicCode,name,description:String(value.description||'').slice(0,240),icon:String(value.icon||'◈').slice(0,4),active:value.active!==false,position:Number(value.position)||0}).select('id').single());return jsonResponse(request,{id:created.id},201);}
  const topicAdmin=path.match(/^\/api\/admin\/topics\/(\d+)$/);if(topicAdmin&&method==='PUT'){const value=await body(request),result=await db.from('inquiry_topics').update({code:String(value.code||'').trim().toUpperCase(),name:String(value.name||'').trim(),description:String(value.description||'').slice(0,240),icon:String(value.icon||'◈').slice(0,4),active:value.active!==false,position:Number(value.position)||0}).eq('id',topicAdmin[1]);if(result.error)throw new Error(result.error.message);return jsonResponse(request,{ok:true});}
  if(topicAdmin&&method==='DELETE'){const used=await db.from('inquiries').select('id',{count:'exact',head:true}).eq('topic_id',topicAdmin[1]);if(used.count)fail(409,'لا يمكن حذف باب مرتبط بأسئلة؛ يمكنك إيقاف ظهوره');await db.from('inquiry_topics').delete().eq('id',topicAdmin[1]);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/inquiries'&&method==='GET'){const {data,error}=await db.from('inquiries').select('*,inquiry_topics(code,name,icon)').order('id',{ascending:false});if(error)throw new Error(error.message);return jsonResponse(request,(data||[]).sort((a:any,b:any)=>(a.status==='new'?-1:1)-(b.status==='new'?-1:1)).map((item:any)=>({...item,topic_code:item.inquiry_topics?.code,topic_name:item.inquiry_topics?.name,topic_icon:item.inquiry_topics?.icon})));}
  const inquiryAdmin=path.match(/^\/api\/admin\/inquiries\/(\d+)$/);if(inquiryAdmin&&method==='PUT'){const value=await body(request),status=value.status==='answered'?'answered':'new',result=await db.from('inquiries').update({answer:String(value.answer||''),status,publish_public:Boolean(value.publishPublic),...(status==='answered'?{answered_at:now()}:{})}).eq('id',inquiryAdmin[1]);if(result.error)throw new Error(result.error.message);return jsonResponse(request,{ok:true});}
  if(path==='/api/admin/question-bank'&&method==='GET'){const {data,error}=await db.from('question_bank').select('type,category,difficulty,bank_source').eq('active',true);if(error)throw new Error(error.message);const rows=data||[],countBy=(field:string)=>Object.entries(rows.reduce((out:any,item:any)=>(out[item[field]||'']=(out[item[field]||'']+1),out),{})).filter(([name])=>name).map(([name,count])=>({[field==='bank_source'?'source':field]:name,count}));return jsonResponse(request,{total:rows.length,choice:rows.filter((q:any)=>q.type==='choice').length,truefalse:rows.filter((q:any)=>q.type==='truefalse').length,categoryCount:new Set(rows.map((q:any)=>q.category).filter(Boolean)).size,categories:countBy('category'),difficulties:countBy('difficulty'),sources:countBy('bank_source')});}
  if(path==='/api/admin/exams/from-bank'&&method==='POST'){const value=await body(request),title=String(value.title||'').trim(),questionCount=Math.min(100,Math.max(1,Number(value.questionCount)||50)),points=Math.min(100,Math.max(.25,Number(value.pointsPerQuestion)||2)),bookId=positiveInteger(value.bookId);if(!title)fail(400,'عنوان الامتحان مطلوب');let query=db.from('question_bank').select('*').eq('active',true);if(value.category)query=query.eq('category',String(value.category));if(value.difficulty)query=query.eq('difficulty',String(value.difficulty));const bank=await query;if(bank.error)throw new Error(bank.error.message);const shuffled=(bank.data||[]).sort(()=>Math.random()-.5).slice(0,questionCount);if(shuffled.length<questionCount)fail(400,`لا يتوافر في المرشح سوى ${shuffled.length} سؤالًا`);const roadmapPosition=bookId?await nextRoadmapPosition(bookId):null,exam=await one<any>(db.from('exams').insert({title,book_id:bookId,roadmap_position:roadmapPosition,is_book_final:false,instructions:String(value.instructions||'اقرأ الأسئلة بعناية، وأجب عنها بنفسك وفق تعهّد الأمانة العلمية.'),starts_at:value.startsAt||null,ends_at:value.endsAt||null,duration_minutes:Math.max(1,Number(value.durationMinutes)||60),status:['draft','published','closed'].includes(value.status)?value.status:'draft',access_mode:value.accessMode==='public'?'public':'private'}).select('id').single());const rows=shuffled.map((q:any,index:number)=>({exam_id:exam.id,type:q.type,prompt:q.prompt,points,data_json:{...(q.data_json||{}),bank:{id:q.id,sourceKey:q.source_key,originalCode:q.original_code,category:q.category,topic:q.topic,difficulty:q.difficulty,sourceNote:q.source_note,bankSource:q.bank_source}},position:index+1})),inserted=await db.from('questions').insert(rows);if(inserted.error)throw new Error(inserted.error.message);return jsonResponse(request,{id:exam.id,questionCount:rows.length,totalPoints:rows.length*points,choice:rows.filter((q:any)=>q.type==='choice').length,truefalse:rows.filter((q:any)=>q.type==='truefalse').length},201);}
  fail(501,'هذا المسار موجود في خطة النقل ولم يُفعّل بعد في النسخة السحابية التجريبية');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(request) });
  try {
    const url = new URL(request.url);
    const marker = '/manara-api';
    const index = url.pathname.indexOf(marker);
    const path = index >= 0 ? (url.pathname.slice(index + marker.length) || '/') : url.pathname;
    return await route(request, path);
  } catch (error) {
    console.error(error);
    return jsonResponse(request, { error: error instanceof Error ? error.message : 'حدث خطأ داخلي' }, error instanceof HttpError ? error.status : 500);
  }
});

# نسخة منارة السحابية التجريبية

هذا مشروع مستقل مأخوذ من خط الأساس العامل `v1.8.4`. لا يغيّر حاوية `manara`، ولا قاعدة SQLite، ولا نفق ngrok الحالي.

## المعمارية

- `frontend/`: ملفات HTML/CSS/JavaScript ثابتة تُنشر على Cloudflare Pages.
- `supabase/migrations/`: مخطط PostgreSQL، الفهارس، RLS، وحاوية الكتب الخاصة.
- `supabase/functions/manara-api/`: واجهة توافق تحفظ مسارات `/api/...` المستخدمة في الموقع.
- `migration/`: تصدير لقطة قراءة فقط من SQLite والكتب، ثم استيرادها إلى Supabase.

لا يوضع `SUPABASE_SECRET_KEY` أو `service_role` في Cloudflare Pages مطلقًا. الواجهة تحتوي فقط على رابط المشروع والمفتاح القابل للنشر، بينما المفتاح السري محفوظ ضمن أسرار Edge Function.

## حالة العمل الحالية

مكتمل في طبقة Supabase التجريبية:

- الصفحة العامة، المكتبة وروابط PDF الموقعة.
- إنشاء طلب طالب ومنع تكراره من المتصفح نفسه.
- دخول الطالب والجلسة وصفحته والدعم الفني.
- بدء الامتحان، الإجابات، التسليم، المراجعة اللاحقة، وثلاث فرص مغادرة.
- المسابقات العامة والأسئلة الشرعية.
- دخول الشيخ والجلسة، الطلاب، الكتب، الفوائد، الامتحانات والأسئلة، بنك الأسئلة، الدعم، الأسئلة الشرعية، النتائج والإعدادات.
- مخطط البيانات الكامل، RLS المغلق، والتصدير والاستيراد.

لم يكتمل بعد، ولذلك لا تُعامل هذه النسخة كبديل للإنتاج:

- تنزيل ملف Excel لتكليفات الامتحان من النسخة السحابية (المسار ما زال مؤجلًا).
- تدقيق استعلامات لوحة الشيخ على بيانات Supabase حقيقية وإصلاح أي فروق في شكل العلاقات الراجعة.
- اختبار تكامل كامل على مشروع Supabase حقيقي.
- اختبار ضغط 50–100 طالب، ومراجعة ذرّية عمليات التقييم المتزامنة.
- ربط نطاق نهائي ومراقبة النسخة السحابية.

## إنشاء مشروع Supabase التجريبي

1. أنشئ مشروع Supabase جديدًا مخصصًا للتجربة، ولا تستخدم مشروع إنتاج.
2. ثبّت Supabase CLI على جهاز الإدارة الموثوق وسجّل الدخول.
3. من هذا المجلد:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase secrets set SUPABASE_SECRET_KEY=YOUR_SECRET_KEY
supabase secrets set ALLOWED_ORIGINS=https://YOUR-PAGES-PROJECT.pages.dev
supabase functions deploy manara-api --no-verify-jwt
```

لا ترسل المفتاح السري في المحادثة ولا تحفظه في Git.

## أخذ نسخة من الخادم العامل بلا إيقافه

شغّل على Ubuntu. الأمر يستخدم SQLite بوضع القراءة فقط، ولا يوقف الحاوية ولا يغيّر البيانات:

```bash
mkdir -p "$HOME/manara-cloud-tools/migration"
# انسخ export-sqlite.mjs إلى المجلد أعلاه، ثم:
docker cp "$HOME/manara-cloud-tools/migration/export-sqlite.mjs" manara:/tmp/export-sqlite.mjs
docker exec manara node /tmp/export-sqlite.mjs /app/data/manara.db /app/data/uploads /tmp/manara-cloud-export
docker cp manara:/tmp/manara-cloud-export "$HOME/manara-cloud-export"
chmod -R go-rwx "$HOME/manara-cloud-export"
```

احتفظ بهذا المجلد بسرية لأنه يتضمن بيانات الطلاب وتجزئات كلمة مرور الإدارة. لا ترفعه إلى GitHub أو Telegram.

## الاستيراد إلى Supabase التجريبي

على جهاز موثوق بعد تطبيق migration:

```bash
npm install
export SUPABASE_URL='https://YOUR_PROJECT_REF.supabase.co'
export SUPABASE_SECRET_KEY='YOUR_SECRET_KEY'
node migration/import-supabase.mjs /secure/path/manara-cloud-export
```

أداة الاستيراد ترفض العمل إذا وجدت بيانات فعلية في الهدف، كي لا تدمج نسختين بالخطأ. جلسات الدخول لا تُنقل عمدًا؛ يسجل الجميع الدخول من جديد.

## إعداد Cloudflare Pages

عدّل `frontend/cloud-config.js` بقيمتين عامتين فقط:

```js
window.MANARA_CLOUD = Object.freeze({
  apiBase: 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/manara-api',
  publishableKey: 'YOUR_SUPABASE_PUBLISHABLE_KEY'
});
```

ثم أنشئ مشروع Pages مرتبطًا بمستودع Git:

- Build command: اتركه فارغًا.
- Build output directory: `frontend`
- Root directory: مجلد `manara-cloud` إذا كان داخل مستودع أكبر.

ملف `_headers` جاهز لسياسات الأمان، وتخدم Cloudflare صفحة `/admin` مباشرة من `admin.html`.

## تطبيق الهاتف PWA

الواجهة العامة قابلة للتثبيت من الموقع نفسه ولا تحتاج إلى متجر تطبيقات:

- يفتح التطبيق افتراضيًا على صفحة الطالب `/#exam`.
- ملف `manifest.webmanifest` يعرّف الاسم والأيقونات ووضع العرض المستقل.
- يسجّل `pwa.js` عامل الخدمة ويعرض زر التثبيت على الأجهزة الداعمة.
- يخزن `service-worker.js` ملفات الواجهة العامة فقط، ولا يعترض طلبات `/api/` أو طلبات Supabase الخارجية.
- لا تُخزن أسئلة الامتحانات أو الإجابات أو نتائج الطلاب في ذاكرة PWA المؤقتة.
- عند انقطاع الشبكة تظهر `offline.html` بدل صفحة قديمة أو امتحان غير قابل للحفظ.

بعد كل تعديل في سياسة التخزين المؤقت، غيّر قيمة `CACHE_VERSION` داخل `service-worker.js` قبل النشر.

## ترتيب الاعتماد

1. إبقاء ngrok عاملًا كما هو.
2. نشر Supabase وCloudflare على عنوان تجريبي.
3. استيراد لقطة البيانات والكتب.
4. فحص الصفحة العامة، طالب تجريبي، امتحان تجريبي، ولوحة الشيخ.
5. إكمال جميع مسارات إدارة الشيخ واختبار الضغط.
6. بعد الموافقة فقط: نقل ميزات v1.8.6 (الشهادات وتعديل ملف الطالب).
7. مزامنة نهائية قصيرة للبيانات، ثم تحويل النطاق.
8. إبقاء النسخة القديمة قابلة للرجوع فترة متفقًا عليها، ثم إيقاف ngrok.

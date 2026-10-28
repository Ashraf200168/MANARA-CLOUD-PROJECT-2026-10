# Manara Backup EXE

`Manara-Backup-Now.exe` هو مشغّل Windows بواجهة رسومية لإنشاء نسخة Manara مشفرة وفورية.

- ملف الإصدار: `release/Manara-Backup-Now.exe`
- الإصدار: `1.0.0.0`
- الحجم: 22,528 بايت
- SHA-256: `96698158050AFFC14A6AEDF4FB5B686A7C23927F00F2532FE4BFA8F8802EE1EA`

## الاستخدام

1. ضع ملف EXE في سطح المكتب أو أي مجلد على **الكمبيوتر الذي أُعد عليه النسخ الاحتياطي**.
2. افتحه بالنقر المزدوج.
3. يبدأ تصدير قاعدة البيانات والكتب تلقائيًا.
4. بعد نجاح التشفير والتحقق تظهر تسمية الملف وزر فتح مجلد OneDrive.

يمكن نقل EXE إلى أي مكان في الكمبيوتر نفسه؛ يبحث عن المشروع تلقائيًا ويتذكر موقعه. لا يحتوي EXE أي secret أو كلمة استعادة.

## الحدود

- يحتاج إلى مجلد مشروع Manara وإعداد `.tools/backup` الموجودين على الجهاز.
- يحتاج إلى الاتصال بالإنترنت وNode.js وPowerShell، وهي متوفرة على جهاز التشغيل الحالي.
- عند نقله إلى كمبيوتر جديد يجب نقل المشروع وتشغيل `START-MANARA-BACKUP-SETUP.bat` مرة واحدة لأن مفاتيح DPAPI مرتبطة بحساب Windows الأصلي.
- إنشاء النسخة يدويًا من EXE لا يلغي المهمة التلقائية؛ كلاهما يستخدم mutex لمنع نسختين متزامنتين.

## المصدر والبناء

المصدر موجود في `tools/manara-backup-launcher/`. بُني الإصدار الموزع كملف Windows EXE واحد باستخدام Roslyn ومكتبات .NET Framework الموجودة في Windows، لذلك لا يحتاج ملفات DLL بجانبه.

يمكن أيضًا بناء نسخة .NET حديثة framework-dependent:

```powershell
dotnet publish tools/manara-backup-launcher/Manara.Backup.Launcher.csproj -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true
```

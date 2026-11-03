using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace Manara.Backup.Status
{
    static class Data
    {
        public static Dictionary<string, object> Read(string path)
        {
            try { return new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(path)); }
            catch { return new Dictionary<string, object>(); }
        }
        public static string Text(Dictionary<string, object> value, string key)
        { object item; return value.TryGetValue(key, out item) && item != null ? Convert.ToString(item, CultureInfo.InvariantCulture) : ""; }
        public static Dictionary<string, object> Object(Dictionary<string, object> value, string key)
        { object item; return value.TryGetValue(key, out item) && item is Dictionary<string, object> ? (Dictionary<string, object>)item : new Dictionary<string, object>(); }
        public static string Hash(string path)
        {
            using (var stream = File.OpenRead(path))
            using (var sha = SHA256.Create())
                return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
        }
        public static Icon AppIcon()
        {
            using(var stream=typeof(Data).Assembly.GetManifestResourceStream("Manara.Backup.Status.Icon"))
            using(var icon=new Icon(stream,new Size(32,32)))
                return (Icon)icon.Clone();
        }
        public static string Digest(string text)
        {
            var match = Regex.Match(text ?? "", @"\A\s*([0-9a-fA-F]{64})(?=\s|$)");
            return match.Success ? match.Groups[1].Value.ToUpperInvariant() : "";
        }
        public static DateTimeOffset? Next(Dictionary<string, object> schedule, DateTimeOffset now)
        {
            DateTimeOffset start; int days;
            if (Text(schedule, "status") != "ACTIVE" || !DateTimeOffset.TryParse(Text(schedule, "firstRun"), out start) ||
                !int.TryParse(Text(schedule, "daysInterval"), out days) || days < 1 || days > 365) return null;
            if (start > now) return start;
            return start.AddDays((Math.Floor((now - start).TotalDays / days) + 1) * days);
        }
        public static bool Uploaded(Dictionary<string, object> state, string backupHash)
        {
            return Text(state, "status") == "SUCCESS" && !String.IsNullOrEmpty(backupHash) &&
                String.Equals(Text(Object(state, "backup"), "sha256"), backupHash, StringComparison.OrdinalIgnoreCase) &&
                Regex.IsMatch(Text(state, "encryptedBackupCommit"), @"\A[0-9a-fA-F]{40,64}\z");
        }
        public static string Time(string value)
        {
            DateTimeOffset time;
            return DateTimeOffset.TryParse(value, out time) ? time.ToOffset(TimeSpan.FromHours(3)).ToString("yyyy-MM-dd  HH:mm:ss") + "  دمشق" : "غير متوفر";
        }
        public static bool FreshUploadSuccess(Dictionary<string, object> state, DateTimeOffset started)
        {
            DateTimeOffset recordStarted, completed;
            return Uploaded(state, Digest(Text(Object(state,"backup"),"sha256"))) &&
                Regex.IsMatch(Text(state,"sourceCommit"), @"\A[0-9a-fA-F]{40,64}\z") &&
                DateTimeOffset.TryParse(Text(state,"startedAt"),out recordStarted) && recordStarted >= started &&
                DateTimeOffset.TryParse(Text(state,"completedAt"),out completed) && completed >= recordStarted;
        }
    }

    static class BackupRunner
    {
        public static async Task<int> RunAsync(string script, Action<string> log)
        {
            if(!File.Exists(script))throw new FileNotFoundException("ملف النسخ والرفع غير موجود.",script);
            if(script.IndexOf('"')>=0)throw new ArgumentException("مسار ملف التشغيل غير صالح.");
            using(var process=new Process())
            {
                process.StartInfo=new ProcessStartInfo {
                    FileName=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell","v1.0","powershell.exe"),
                    Arguments="-NoProfile -NonInteractive -ExecutionPolicy Bypass -File \""+script+"\" -Scheduled",
                    WorkingDirectory=Path.GetDirectoryName(Path.GetFullPath(script)),
                    UseShellExecute=false, CreateNoWindow=true, RedirectStandardOutput=true, RedirectStandardError=true,
                    StandardOutputEncoding=Encoding.UTF8, StandardErrorEncoding=Encoding.UTF8
                };
                process.OutputDataReceived+=delegate(object sender,DataReceivedEventArgs e){if(e.Data!=null)log(e.Data);};
                process.ErrorDataReceived+=delegate(object sender,DataReceivedEventArgs e){if(e.Data!=null)log(e.Data);};
                if(!process.Start())throw new InvalidOperationException("تعذّر بدء النسخ الاحتياطي.");
                process.BeginOutputReadLine(); process.BeginErrorReadLine();
                await Task.Run(delegate { process.WaitForExit(); });
                process.WaitForExit();
                return process.ExitCode;
            }
        }
    }

    static class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            if (args.Length > 0 && args[0] == "--self-test") return SelfTest();
            if (args.Length == 2 && args[0] == "--verify-latest")
            {
                try
                {
                    var last=Data.Read(Path.Combine(args[1],".tools","backup","last-success.json"));
                    var uploaded=Data.Read(Path.Combine(args[1],".tools","github-update","last-status.json"));
                    string digest=Data.Digest(Data.Text(last,"sha256"));
                    if(digest=="" || !String.Equals(Data.Hash(Data.Text(last,"archive")),digest,StringComparison.OrdinalIgnoreCase))return 11;
                    return Data.Uploaded(uploaded,digest) ? 0 : 12;
                } catch { return 13; }
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            if(args.Length==2 && args[0]=="--render-preview")
            {
                using(var form=new StatusForm())
                {
                    form.ShowInTaskbar=false; form.StartPosition=FormStartPosition.Manual; form.Location=new Point(-20000,-20000);
                    form.Show(); Application.DoEvents();
                    using(var bitmap=new Bitmap(form.Width,form.Height))
                    { form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height)); bitmap.Save(args[1],System.Drawing.Imaging.ImageFormat.Png); }
                    form.Close();
                }
                return 0;
            }
            Application.Run(new StatusForm());
            return 0;
        }
        static int SelfTest()
        {
            try
            {
                using(var icon=Data.AppIcon()) { if(icon.Width!=32 || icon.Height!=32)return 9; }
                string hash = new string('A', 64);
                if (Data.Digest(hash + "  manara-cloud-latest.mnbak") != hash || Data.Digest("bad") != "" || Data.Digest(hash + "0") != "") return 1;
                var schedule = new Dictionary<string, object> { {"status","ACTIVE"}, {"firstRun","2026-10-31T10:00:00+03:00"}, {"daysInterval",3} };
                if (Data.Next(schedule, DateTimeOffset.Parse("2026-11-03T11:00:00+03:00")) != DateTimeOffset.Parse("2026-11-06T10:00:00+03:00")) return 2;
                var state = new Dictionary<string, object> { {"status","SUCCESS"}, {"backup",new Dictionary<string,object>{{"sha256",hash}}}, {"encryptedBackupCommit",new string('b',40)} };
                if (!Data.Uploaded(state, hash) || Data.Uploaded(state, new string('C',64))) return 3;
                state["status"] = "FAILED";
                if (Data.Uploaded(state, hash)) return 4;
                state["status"]="SUCCESS"; state["startedAt"]="2026-11-03T10:00:02+03:00"; state["completedAt"]="2026-11-03T10:00:42+03:00"; state["sourceCommit"]=new string('c',40);
                if(!Data.FreshUploadSuccess(state,DateTimeOffset.Parse("2026-11-03T10:00:01+03:00")) || Data.FreshUploadSuccess(state,DateTimeOffset.Parse("2026-11-03T11:00:00+03:00")))return 6;
                state["completedAt"]="2026-11-03T09:00:00+03:00";
                if(Data.FreshUploadSuccess(state,DateTimeOffset.Parse("2026-11-03T10:00:01+03:00")))return 7;
                string temporary = Path.GetTempFileName();
                try { File.WriteAllBytes(temporary, new byte[] {97,98,99}); if (Data.Hash(temporary) != "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD") return 5; }
                finally { File.Delete(temporary); }
                string testRoot=Path.Combine(Path.GetTempPath(),"ManaraStatusTest-"+Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(testRoot);
                string script=Path.Combine(testRoot,"mock backup.ps1");
                try
                {
                    foreach(int code in new int[]{0,1,75})
                    {
                        File.WriteAllText(script,"param([switch]$Scheduled)\r\nif (-not $Scheduled) { exit 99 }\r\nWrite-Output 'MOCK PROGRESS'\r\nexit "+code);
                        var output=new System.Collections.Concurrent.ConcurrentQueue<string>();
                        int actualCode=BackupRunner.RunAsync(script,delegate(string line){output.Enqueue(line);}).GetAwaiter().GetResult();
                        if(actualCode!=code || !String.Join("\n",output.ToArray()).Contains("MOCK PROGRESS"))return 8;
                    }
                }
                finally { if(File.Exists(script))File.Delete(script); Directory.Delete(testRoot); }
                return 0;
            } catch { return 10; }
        }
    }

    sealed class StatusForm : Form
    {
        readonly Color navy = Color.FromArgb(12,59,79);
        readonly Label summary = new Label();
        readonly Label scheduleLabel = new Label();
        readonly Label location = new Label();
        readonly Label verification = new Label();
        readonly DataGridView grid = new DataGridView();
        readonly TextBox report = new TextBox();
        readonly TextBox expected = new TextBox();
        readonly Button verify = new Button();
        readonly Button refresh = new Button();
        readonly Button pick = new Button();
        readonly Button projectButton = new Button();
        readonly Button backupNow = new Button();
        readonly ProgressBar progress = new ProgressBar();
        readonly Timer timer = new Timer();
        string projectRoot;
        string backupRoot;
        string selectedFile;
        bool busy;
        bool backupRunning;
        Dictionary<string, object> success = new Dictionary<string, object>();
        Dictionary<string, object> upload = new Dictionary<string, object>();
        readonly Dictionary<string,string> checkedFiles = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);

        public StatusForm()
        {
            Icon=Data.AppIcon();
            Text = "Manara — حالة النسخ الاحتياطي";
            Size = new Size(1080,850); MinimumSize = new Size(860,720);
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI",10); BackColor = Color.FromArgb(244,249,251);
            RightToLeft = RightToLeft.Yes; RightToLeftLayout = true;
            var layout = new TableLayoutPanel { Dock=DockStyle.Fill, ColumnCount=1, RowCount=10, Padding=new Padding(20) };
            foreach (int height in new int[]{62,65,54,38,47,45,38,34}) layout.RowStyles.Add(new RowStyle(SizeType.Absolute,height));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent,48));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent,52));
            var title = new Label {Text="برنامج القراءة الفردية | مراقبة النسخ الاحتياطي", Dock=DockStyle.Fill, BackColor=navy, ForeColor=Color.White, Font=new Font("Segoe UI",19,FontStyle.Bold), TextAlign=ContentAlignment.MiddleRight, Padding=new Padding(12)};
            layout.Controls.Add(title,0,0);
            summary.Dock=DockStyle.Fill; summary.Font=new Font("Segoe UI",12,FontStyle.Bold); summary.TextAlign=ContentAlignment.MiddleRight;
            layout.Controls.Add(summary,0,1);
            scheduleLabel.Dock=DockStyle.Fill; scheduleLabel.TextAlign=ContentAlignment.MiddleRight;
            layout.Controls.Add(scheduleLabel,0,2);
            location.Dock=DockStyle.Fill; location.AutoEllipsis=true; location.TextAlign=ContentAlignment.MiddleLeft; location.RightToLeft=RightToLeft.No;
            layout.Controls.Add(location,0,3);
            var actions = new FlowLayoutPanel {Dock=DockStyle.Fill, FlowDirection=FlowDirection.RightToLeft, WrapContents=false, AutoScroll=true};
            AddButton(actions,backupNow,"نسخ احتياطي الآن",async delegate { await BackupNowAsync(); });
            backupNow.BackColor=navy; backupNow.ForeColor=Color.White; backupNow.Font=new Font("Segoe UI",10,FontStyle.Bold);
            AddButton(actions, refresh,"تحديث الحالة",delegate { Reload(); });
            AddButton(actions,new Button(),"مجلد النسخ",delegate { OpenFolder(backupRoot); });
            AddButton(actions,new Button(),"التقرير النصي",delegate { OpenReport(); });
            AddButton(actions,projectButton,"تحديد المشروع",delegate { ChooseProject(); });
            AddButton(actions,pick,"اختيار ملف نسخة",delegate { ChooseFile(); });
            layout.Controls.Add(actions,0,4);
            var hashPanel = new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=3};
            hashPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,142)); hashPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100)); hashPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,145));
            hashPanel.Controls.Add(new Label{Text="البصمة المتوقعة:",Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleRight},0,0);
            expected.Dock=DockStyle.Fill; expected.Font=new Font("Consolas",9); expected.RightToLeft=RightToLeft.No;
            hashPanel.Controls.Add(expected,1,0);
            verify.Text="تحقق من الملف"; verify.Dock=DockStyle.Fill; verify.Click+=async delegate { await VerifyAsync(); };
            hashPanel.Controls.Add(verify,2,0); layout.Controls.Add(hashPanel,0,5);
            verification.Dock=DockStyle.Fill; verification.TextAlign=ContentAlignment.MiddleRight; verification.AutoEllipsis=true;
            layout.Controls.Add(verification,0,6);
            progress.Dock=DockStyle.Fill; progress.Visible=false; progress.Style=ProgressBarStyle.Marquee;
            layout.Controls.Add(progress,0,7);
            grid.Dock=DockStyle.Fill; grid.ReadOnly=true; grid.AllowUserToAddRows=false; grid.AllowUserToDeleteRows=false; grid.MultiSelect=false;
            grid.SelectionMode=DataGridViewSelectionMode.FullRowSelect; grid.AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill;
            grid.RowHeadersVisible=false; grid.BackgroundColor=Color.White; grid.AutoGenerateColumns=false;
            grid.Columns.Add("file","ملف النسخة"); grid.Columns.Add("date","تاريخ الملف — دمشق"); grid.Columns.Add("size","الحجم MB"); grid.Columns.Add("check","سلامة الملف");
            grid.Columns[0].FillWeight=160; grid.Columns[1].FillWeight=100; grid.Columns[2].FillWeight=55;
            grid.SelectionChanged+=delegate { if (!busy && grid.SelectedRows.Count>0) SelectFile((string)grid.SelectedRows[0].Tag); };
            layout.Controls.Add(grid,0,8);
            report.Dock=DockStyle.Fill; report.Multiline=true; report.ReadOnly=true; report.ScrollBars=ScrollBars.Both;
            report.Font=new Font("Consolas",9); report.RightToLeft=RightToLeft.No; report.WordWrap=false;
            layout.Controls.Add(report,0,9); Controls.Add(layout);
            Shown+=delegate { projectRoot=FindProject(); Reload(); };
            timer.Interval=30000; timer.Tick+=delegate { if (!busy && !expected.Focused && (grid.Focused || String.IsNullOrEmpty(selectedFile) || (backupRoot!=null && String.Equals(Path.GetDirectoryName(selectedFile),backupRoot,StringComparison.OrdinalIgnoreCase)))) Reload(); }; timer.Start();
            FormClosed+=delegate { timer.Stop(); timer.Dispose(); if(Icon!=null)Icon.Dispose(); };
            FormClosing+=delegate(object sender,FormClosingEventArgs e){if(backupRunning){e.Cancel=true; MessageBox.Show(this,"النسخ والرفع يعمل الآن. اترك النافذة مفتوحة حتى ينتهي؛ يمكنك تصغيرها.","Manara");}};
        }
        void AddButton(FlowLayoutPanel panel, Button button, string text, EventHandler handler)
        { button.Text=text; button.AutoSize=true; button.Height=35; button.MinimumSize=new Size(122,35); button.Click+=handler; panel.Controls.Add(button); }
        static string ValidProject(string path)
        {
            try { return !String.IsNullOrWhiteSpace(path) && File.Exists(Path.Combine(path,".tools","backup","backup-config.json")) ? Path.GetFullPath(path) : null; }
            catch { return null; }
        }
        string FindProject()
        {
            var candidates = new List<string> {Environment.GetEnvironmentVariable("MANARA_PROJECT_ROOT"),AppDomain.CurrentDomain.BaseDirectory,Environment.CurrentDirectory,
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Documents","Codex","2026-09-29","i","work","manara-cloud")};
            try { candidates.Insert(0,File.ReadAllText(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Manara","backup-project.txt")).Trim()); } catch { }
            var parent = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
            for(int i=0;parent!=null && i<8;i++,parent=parent.Parent) { candidates.Add(parent.FullName); candidates.Add(Path.Combine(parent.FullName,"work","manara-cloud")); }
            foreach(string candidate in candidates) { string root=ValidProject(candidate); if(root!=null)return root; }
            return null;
        }
        void Reload()
        {
            if(busy)return;
            try
            {
                if(projectRoot==null)
                { backupNow.Enabled=false; summary.Text="اختر مجلد مشروع Manara لعرض حالته، أو اختر ملف نسخة لفحصه."; summary.ForeColor=navy; scheduleLabel.Text="اختر المشروع لتفعيل النسخ الفوري. لا تبدأ أي عملية تلقائيًا عند فتح البرنامج."; return; }
                backupNow.Enabled=File.Exists(Path.Combine(projectRoot,"BACKUP-AND-UPLOAD-MANARA.ps1"));
                var config=Data.Read(Path.Combine(projectRoot,".tools","backup","backup-config.json"));
                backupRoot=Data.Text(config,"backupRoot"); location.Text=backupRoot;
                success=Data.Read(Path.Combine(projectRoot,".tools","backup","last-success.json"));
                upload=Data.Read(Path.Combine(projectRoot,".tools","github-update","last-status.json"));
                var lastRun=Data.Read(Path.Combine(projectRoot,".tools","backup","last-run.json"));
                string uploadStatus=Data.Text(upload,"status");
                summary.ForeColor=navy;
                if (uploadStatus=="RUNNING" || uploadStatus=="BACKUP_CREATED" || uploadStatus=="SOURCE_UPLOADED")
                    summary.Text="السجل يشير إلى عملية جارية أو غير مكتملة — اضغط تحديث لمتابعتها.";
                else if(uploadStatus=="FAILED" || Data.Text(lastRun,"status")=="FAILED")
                { summary.Text="آخر محاولة سجّلت فشلًا. النسخة الناجحة السابقة: " + Data.Time(Data.Text(success,"completedAt")); summary.ForeColor=Color.Firebrick; }
                else if(Data.Text(success,"status")=="SUCCESS")
                {
                    bool uploaded=Data.Uploaded(upload,Data.Text(success,"sha256"));
                    summary.Text="آخر نسخة ناجحة: " + Data.Time(Data.Text(success,"completedAt")) + Environment.NewLine +
                        (uploaded ? "سجل رفع النسخة نفسها إلى GitHub: ناجح — " + Data.Time(Data.Text(upload,"completedAt")) : "رفع النسخة الأخيرة إلى GitHub: غير مؤكد في السجل المحلي");
                    summary.ForeColor=Color.FromArgb(15,122,82);
                }
                else summary.Text="لا يوجد سجل نسخة ناجحة مؤكد بعد.";
                var schedule=Data.Read(Path.Combine(projectRoot,".tools","github-update","schedule.json"));
                var next=Data.Next(schedule,DateTimeOffset.Now);
                scheduleLabel.Text=next.HasValue ? "الجدول المحفوظ: كل " + Data.Text(schedule,"daysInterval") + " أيام، الساعة " + Data.Text(schedule,"time") + " دمشق. القادم المتوقع: " + Data.Time(next.Value.ToString("o")) + Environment.NewLine + "الموعد محسوب من الإعداد؛ حالة مهمة Windows الفعلية غير مفحوصة." : "لا يتوفر إعداد جدول محفوظ.";
                string oldSelected=selectedFile;
                grid.Rows.Clear();
                if(Directory.Exists(backupRoot))
                {
                    var files=new DirectoryInfo(backupRoot).GetFiles("*.mnbak");
                    Array.Sort(files,delegate(FileInfo a, FileInfo b){return b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc);});
                    foreach(var file in files)
                    {
                        string check;
                        if(!checkedFiles.TryGetValue(CacheKey(file.FullName),out check))check="لم تُفحص في هذه الجلسة";
                        int index=grid.Rows.Add(file.Name,new DateTimeOffset(file.LastWriteTimeUtc).ToOffset(TimeSpan.FromHours(3)).ToString("yyyy-MM-dd HH:mm"),(file.Length/1024d/1024d).ToString("N2"),check);
                        grid.Rows[index].Tag=file.FullName;
                    }
                    if(grid.Rows.Count>0)
                    {
                        grid.ClearSelection();
                        DataGridViewRow row=grid.Rows[0];
                        foreach(DataGridViewRow candidate in grid.Rows)if(String.Equals((string)candidate.Tag,oldSelected,StringComparison.OrdinalIgnoreCase))row=candidate;
                        row.Selected=true; grid.CurrentCell=row.Cells[0]; SelectFile((string)row.Tag);
                    }
                }
                string reportPath=ReportPath();
                report.Text=reportPath!=null ? File.ReadAllText(reportPath) : "No combined text report found. The checksum .sha256.txt file is not a status report.";
            }
            catch(Exception error) { summary.ForeColor=Color.Firebrick; summary.Text="تعذّر قراءة الحالة: " + error.Message; }
        }
        string CacheKey(string path)
        { var file=new FileInfo(path); return path + "|" + file.Length + "|" + file.LastWriteTimeUtc.Ticks; }
        void SelectFile(string path)
        {
            selectedFile=path; string digest="";
            try { if(File.Exists(path+".sha256.txt"))digest=Data.Digest(File.ReadAllText(path+".sha256.txt")); }catch { }
            if(digest=="" && String.Equals(path,Data.Text(success,"archive"),StringComparison.OrdinalIgnoreCase))digest=Data.Digest(Data.Text(success,"sha256"));
            expected.Text=digest;
            string check;
            verification.ForeColor=navy;
            verification.Text=File.Exists(path) && checkedFiles.TryGetValue(CacheKey(path),out check) ? check : "اختر «تحقق من الملف» لحساب البصمة. لا يتم فك تشفير بيانات الطلاب.";
        }
        async Task VerifyAsync()
        {
            if(String.IsNullOrEmpty(selectedFile) || !File.Exists(selectedFile)) { MessageBox.Show(this,"اختر ملف نسخة موجودًا أولًا."); return; }
            string digest=Data.Digest(expected.Text);
            if(!String.IsNullOrWhiteSpace(expected.Text) && digest=="") { MessageBox.Show(this,"أدخل بصمة SHA-256 صحيحة: 64 حرفًا من 0-9 وA-F."); return; }
            string path=selectedFile; string key=CacheKey(path);
            busy=true; backupNow.Enabled=false; verify.Enabled=false; refresh.Enabled=false; pick.Enabled=false; projectButton.Enabled=false; grid.Enabled=false; expected.Enabled=false; progress.Visible=true;
            verification.Text="جارٍ حساب البصمة...";
            try
            {
                string actual=await Task.Run(delegate { return Data.Hash(path); });
                if(CacheKey(path)!=key)throw new IOException("تغير الملف أثناء الفحص. أعد المحاولة.");
                bool matches=digest!="" && String.Equals(digest,actual,StringComparison.OrdinalIgnoreCase);
                string message=digest=="" ? "حُسبت البصمة فقط — لا يوجد مرجع للمقارنة" : matches ? "البصمة مطابقة — الملف لم يتغير عن المرجع" : "تحذير: البصمة غير مطابقة للمرجع";
                checkedFiles[key]=message;
                verification.Text=message;
                verification.ForeColor=matches ? Color.FromArgb(15,122,82) : digest=="" ? navy : Color.Firebrick;
                report.Text="FILE CHECK (not a restore test)\r\nFile: " + path + "\r\nSHA-256: " + actual + "\r\nExpected: " + (digest=="" ? "not supplied" : digest) + "\r\nResult: " + (digest=="" ? "HASH ONLY" : matches ? "MATCH" : "MISMATCH") + "\r\n\r\n" +
                    "Matching checksums do not prove database restore readiness or a current GitHub upload. The status above uses local records, not a live GitHub request.";
                foreach(DataGridViewRow row in grid.Rows)if((string)row.Tag==path)row.Cells[3].Value=message;
            }
            catch(Exception error) { verification.ForeColor=Color.Firebrick; verification.Text="فشل التحقق: " + error.Message; }
            finally { busy=false; backupNow.Enabled=projectRoot!=null && File.Exists(Path.Combine(projectRoot,"BACKUP-AND-UPLOAD-MANARA.ps1")); verify.Enabled=true; refresh.Enabled=true; pick.Enabled=true; projectButton.Enabled=true; grid.Enabled=true; expected.Enabled=true; progress.Visible=false; }
        }
        void AppendProgress(string line)
        {
            if(IsDisposed || !IsHandleCreated)return;
            if(InvokeRequired) { try { BeginInvoke(new Action<string>(AppendProgress),line); }catch(InvalidOperationException){} return; }
            if(!backupRunning)return;
            if(report.TextLength>60000)report.Text=report.Text.Substring(report.TextLength-40000);
            report.AppendText(line+Environment.NewLine); report.SelectionStart=report.TextLength; report.ScrollToCaret();
        }
        async Task BackupNowAsync()
        {
            if(busy)return;
            if(projectRoot==null){MessageBox.Show(this,"اختر مجلد مشروع Manara أولًا.");return;}
            string script=Path.Combine(projectRoot,"BACKUP-AND-UPLOAD-MANARA.ps1");
            if(!File.Exists(script)){MessageBox.Show(this,"ملف النسخ والرفع غير موجود في المشروع.");return;}
            if(MessageBox.Show(this,"سيتم إنشاء نسخة مشفرة جديدة من البيانات والكتب، ثم رفع النسخة والكود والتطبيق إلى GitHub.\nيلزم الإنترنت. لن يتغير الجدول التلقائي.\n\nهل تريد البدء الآن؟","Manara — نسخ احتياطي الآن",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;
            var started=DateTimeOffset.Now;
            busy=true; backupRunning=true; backupNow.Enabled=false; verify.Enabled=false; refresh.Enabled=false; pick.Enabled=false; projectButton.Enabled=false; grid.Enabled=false; expected.Enabled=false; progress.Visible=true;
            summary.ForeColor=navy; summary.Text="جارٍ إنشاء النسخة والتحقق منها ورفعها إلى GitHub...";
            verification.Text="اترك النافذة مفتوحة. يمكنك متابعة الخطوات في التفاصيل أدناه.";
            report.Clear();
            string result=""; bool ok=false;
            try
            {
                int code=await BackupRunner.RunAsync(script,AppendProgress);
                if(code==75)result="توجد عملية نسخ ورفع أخرى تعمل بالفعل. لم يبدأ البرنامج نسخة ثانية. يمكنك متابعة حالتها بزر تحديث.";
                else if(code!=0)result="لم تكتمل العملية (رمز "+code+"). راجع التفاصيل والتقرير النصي؛ النسخ الناجحة السابقة محفوظة.";
                else
                {
                    var state=Data.Read(Path.Combine(projectRoot,".tools","github-update","last-status.json"));
                    ok=Data.FreshUploadSuccess(state,started);
                    result=ok ? "اكتمل النسخ الاحتياطي والرفع إلى GitHub بنجاح. التقرير النصي متاح الآن." : "انتهى التشغيل، لكن لم يتأكد نجاح نسخة جديدة ورفعها. لم يتم اعتماد السجل القديم كنجاح جديد.";
                }
            }
            catch(Exception error){result="تعذّر إكمال العملية: "+error.Message;}
            finally
            {
                busy=false; backupRunning=false; backupNow.Enabled=true; verify.Enabled=true; refresh.Enabled=true; pick.Enabled=true; projectButton.Enabled=true; grid.Enabled=true; expected.Enabled=true; progress.Visible=false;
            }
            string liveLog=report.Text;
            Reload();
            if(!ok)report.Text=liveLog+Environment.NewLine+Environment.NewLine+result;
            verification.Text=result; verification.ForeColor=ok ? Color.FromArgb(15,122,82) : Color.Firebrick;
            MessageBox.Show(this,result,"Manara",MessageBoxButtons.OK,ok ? MessageBoxIcon.Information : MessageBoxIcon.Warning);
        }
        void ChooseProject()
        {
            using(var dialog=new FolderBrowserDialog {Description="اختر مجلد manara-cloud",ShowNewFolderButton=false})
            {
                if(dialog.ShowDialog(this)!=DialogResult.OK)return;
                string root=ValidProject(dialog.SelectedPath);
                if(root==null) { MessageBox.Show(this,"لم يوجد إعداد النسخ الاحتياطي في المجلد المختار."); return; }
                projectRoot=root; Reload();
            }
        }
        void ChooseFile()
        {
            using(var dialog=new OpenFileDialog {Filter="Manara encrypted backup (*.mnbak)|*.mnbak",CheckFileExists=true})
            { if(dialog.ShowDialog(this)==DialogResult.OK)SelectFile(dialog.FileName); }
        }
        string ReportPath()
        {
            if(projectRoot!=null)
            { string local=Path.Combine(projectRoot,".tools","github-update","reports","latest-report.txt"); if(File.Exists(local))return local; }
            if(!String.IsNullOrEmpty(backupRoot))
            { string copy=Path.Combine(backupRoot,"Reports","latest-report.txt"); if(File.Exists(copy))return copy; }
            return null;
        }
        void OpenReport()
        { string path=ReportPath(); if(path!=null)Process.Start(new ProcessStartInfo("notepad.exe","\""+path+"\""){UseShellExecute=true}); else MessageBox.Show(this,"لا يوجد تقرير نصي بعد."); }
        void OpenFolder(string path)
        { if(!String.IsNullOrEmpty(path) && Directory.Exists(path))Process.Start(new ProcessStartInfo("explorer.exe","\""+path+"\""){UseShellExecute=true}); else MessageBox.Show(this,"اختر مجلد المشروع أولًا."); }
    }
}

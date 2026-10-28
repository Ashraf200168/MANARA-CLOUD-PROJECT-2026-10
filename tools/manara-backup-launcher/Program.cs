#nullable enable

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: AssemblyTitle("Manara Backup Now")]
[assembly: AssemblyDescription("Portable verified encrypted backup launcher for Manara Cloud")]
[assembly: AssemblyCompany("Manara Individual Reading Program")]
[assembly: AssemblyProduct("Manara Cloud")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace Manara.Backup.Launcher;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length > 0 && string.Equals(args[0], "--verify", StringComparison.OrdinalIgnoreCase))
            return BackupForm.VerifyConfiguration() ? 0 : 2;
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new BackupForm());
        return 0;
    }
}

internal sealed class BackupForm : Form
{
    private static readonly Color Navy = Color.FromArgb(12, 59, 79);
    private static readonly Color Teal = Color.FromArgb(25, 112, 130);
    private static readonly Color Gold = Color.FromArgb(226, 181, 75);
    private static readonly Color Page = Color.FromArgb(244, 249, 251);

    private readonly Label statusLabel = new();
    private readonly Label detailLabel = new();
    private readonly ProgressBar progress = new();
    private readonly TextBox logBox = new();
    private readonly Button runButton = new();
    private readonly Button openButton = new();
    private readonly Button locateButton = new();
    private readonly Button closeButton = new();

    private string? projectRoot;
    private string? backupFolder;
    private bool started;

    public BackupForm()
    {
        Text = "Manara Backup — النسخ الاحتياطي";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(720, 590);
        Size = new Size(820, 650);
        BackColor = Page;
        Font = new Font("Segoe UI", 10F);
        RightToLeft = RightToLeft.Yes;
        RightToLeftLayout = true;

        BuildInterface();
        Shown += async (_, _) =>
        {
            if (started) return;
            started = true;
            await RunBackupAsync();
        };
    }

    private void BuildInterface()
    {
        var header = new Panel
        {
            Dock = DockStyle.Top,
            Height = 118,
            BackColor = Navy,
            Padding = new Padding(28, 18, 28, 14)
        };

        var title = new Label
        {
            Text = "برنامج القراءة الفردية",
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 20F, FontStyle.Bold),
            Dock = DockStyle.Top,
            Height = 45,
            TextAlign = ContentAlignment.MiddleRight
        };
        var subtitle = new Label
        {
            Text = "نسخة احتياطية مشفرة وفورية — Manara Cloud",
            ForeColor = Color.FromArgb(206, 228, 236),
            Font = new Font("Segoe UI", 11F),
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleRight
        };
        header.Controls.Add(subtitle);
        header.Controls.Add(title);
        Controls.Add(header);

        var body = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(28, 24, 28, 20),
            ColumnCount = 1,
            RowCount = 7
        };
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        body.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 12));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 54));

        statusLabel.Text = "جارٍ التحضير...";
        statusLabel.ForeColor = Navy;
        statusLabel.Font = new Font("Segoe UI", 17F, FontStyle.Bold);
        statusLabel.Dock = DockStyle.Fill;
        statusLabel.TextAlign = ContentAlignment.MiddleRight;
        body.Controls.Add(statusLabel, 0, 0);

        detailLabel.Text = "سيبدأ النسخ تلقائيًا ويُحفظ في OneDrive.";
        detailLabel.ForeColor = Color.FromArgb(75, 91, 100);
        detailLabel.Font = new Font("Segoe UI", 10.5F);
        detailLabel.Dock = DockStyle.Fill;
        detailLabel.TextAlign = ContentAlignment.MiddleRight;
        body.Controls.Add(detailLabel, 0, 1);

        progress.Dock = DockStyle.Fill;
        progress.Style = ProgressBarStyle.Marquee;
        progress.MarqueeAnimationSpeed = 25;
        body.Controls.Add(progress, 0, 2);

        var logTitle = new Label
        {
            Text = "تفاصيل العملية",
            ForeColor = Teal,
            Font = new Font("Segoe UI", 10F, FontStyle.Bold),
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.BottomRight
        };
        body.Controls.Add(logTitle, 0, 3);

        logBox.Multiline = true;
        logBox.ReadOnly = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.BackColor = Color.White;
        logBox.ForeColor = Color.FromArgb(45, 57, 64);
        logBox.BorderStyle = BorderStyle.FixedSingle;
        logBox.Font = new Font("Consolas", 9F);
        logBox.Dock = DockStyle.Fill;
        logBox.RightToLeft = RightToLeft.No;
        body.Controls.Add(logBox, 0, 4);

        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.RightToLeft,
            WrapContents = false,
            Padding = new Padding(0, 6, 0, 0)
        };

        ConfigureButton(runButton, "إنشاء نسخة أخرى", Teal, Color.White, async (_, _) => await RunBackupAsync());
        ConfigureButton(openButton, "فتح مجلد النسخ", Gold, Navy, (_, _) => OpenBackupFolder());
        ConfigureButton(locateButton, "تحديد المشروع", Color.White, Navy, (_, _) => LocateProjectManually());
        ConfigureButton(closeButton, "إغلاق", Color.White, Navy, (_, _) => Close());
        runButton.Enabled = false;
        openButton.Enabled = false;

        buttons.Controls.Add(runButton);
        buttons.Controls.Add(openButton);
        buttons.Controls.Add(locateButton);
        buttons.Controls.Add(closeButton);
        body.Controls.Add(buttons, 0, 6);
        Controls.Add(body);
    }

    private static void ConfigureButton(Button button, string text, Color background, Color foreground, EventHandler action)
    {
        button.Text = text;
        button.AutoSize = true;
        button.MinimumSize = new Size(138, 38);
        button.Height = 38;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = Color.FromArgb(156, 172, 179);
        button.BackColor = background;
        button.ForeColor = foreground;
        button.Font = new Font("Segoe UI", 9.5F, FontStyle.Bold);
        button.Margin = new Padding(8, 0, 0, 0);
        button.Click += action;
    }

    private async Task RunBackupAsync()
    {
        SetBusy(true);
        logBox.Clear();
        statusLabel.Text = "جارٍ البحث عن إعداد Manara...";
        detailLabel.Text = "يمكن نقل هذا الملف إلى أي مجلد على هذا الكمبيوتر.";

        try
        {
            projectRoot ??= await Task.Run(FindProjectRoot);
            if (projectRoot is null)
            {
                SetFailure("لم يتم العثور على مشروع Manara.", "اضغط «تحديد المشروع» واختر مجلد manara-cloud.");
                return;
            }

            SaveProjectLocator(projectRoot);
            var script = Path.Combine(projectRoot, "RUN-MANARA-BACKUP.ps1");
            var config = Path.Combine(projectRoot, ".tools", "backup", "backup-config.json");
            var secret = Path.Combine(projectRoot, ".tools", "backup", "private", "supabase-secret.dpapi");
            var password = Path.Combine(projectRoot, ".tools", "backup", "private", "backup-password.dpapi");
            if (!File.Exists(script) || !File.Exists(config) || !File.Exists(secret) || !File.Exists(password))
            {
                SetFailure("إعداد النسخ غير مكتمل.", "شغّل START-MANARA-BACKUP-SETUP.bat مرة واحدة، ثم أعد المحاولة.");
                return;
            }

            statusLabel.Text = "جارٍ إنشاء النسخة المشفرة...";
            detailLabel.Text = "لا تغلق النافذة. يجري تصدير قاعدة البيانات والكتب والتحقق من سلامة الملف.";
            AppendLog($"Project: {projectRoot}");
            AppendLog("Starting forced verified backup...");

            var startedAt = DateTimeOffset.Now;
            using var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    WorkingDirectory = projectRoot,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                },
                EnableRaisingEvents = true
            };
            process.StartInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + QuoteArgument(script) + " -Force";

            process.OutputDataReceived += (_, eventArgs) => { if (!string.IsNullOrWhiteSpace(eventArgs.Data)) AppendLog(eventArgs.Data); };
            process.ErrorDataReceived += (_, eventArgs) => { if (!string.IsNullOrWhiteSpace(eventArgs.Data)) AppendLog("ERROR: " + eventArgs.Data); };
            if (!process.Start()) throw new InvalidOperationException("PowerShell could not be started.");
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            await Task.Run(() => process.WaitForExit());
            process.WaitForExit();

            if (process.ExitCode != 0)
            {
                SetFailure("فشلت النسخة الاحتياطية.", $"رمز الخطأ: {process.ExitCode}. راجع التفاصيل الظاهرة وسجل backup.log.");
                return;
            }

            var result = ReadLatestSuccess(projectRoot);
            if (result is null || !string.Equals(result.Status, "SUCCESS", StringComparison.OrdinalIgnoreCase) ||
                result.CompletedAt < startedAt.AddMinutes(-1) || string.IsNullOrWhiteSpace(result.Archive) || !File.Exists(result.Archive))
            {
                SetFailure("لم تُنشأ نسخة جديدة مؤكدة.", "قد تكون هناك نسخة أخرى تعمل الآن. انتظر قليلًا ثم اضغط «إنشاء نسخة أخرى».");
                return;
            }

            backupFolder = Path.GetDirectoryName(result.Archive);
            var sizeMb = result.Bytes / 1024d / 1024d;
            progress.Style = ProgressBarStyle.Continuous;
            progress.Value = 100;
            statusLabel.Text = "اكتملت النسخة الاحتياطية بنجاح";
            statusLabel.ForeColor = Color.FromArgb(15, 122, 82);
            detailLabel.Text = $"{Path.GetFileName(result.Archive)} — {sizeMb:N1} MB";
            AppendLog("");
            AppendLog("BACKUP VERIFIED AND SAVED");
            AppendLog($"Archive: {result.Archive}");
            AppendLog($"SHA-256: {result.Sha256}");
            openButton.Enabled = true;
        }
        catch (Exception error)
        {
            AppendLog(error.ToString());
            SetFailure("حدث خطأ غير متوقع.", error.Message);
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void SetBusy(bool busy)
    {
        runButton.Enabled = !busy;
        locateButton.Enabled = !busy;
        closeButton.Enabled = !busy;
        if (busy)
        {
            progress.Style = ProgressBarStyle.Marquee;
            progress.MarqueeAnimationSpeed = 25;
            statusLabel.ForeColor = Navy;
        }
    }

    private void SetFailure(string title, string detail)
    {
        progress.Style = ProgressBarStyle.Continuous;
        progress.Value = 0;
        statusLabel.Text = title;
        statusLabel.ForeColor = Color.FromArgb(176, 48, 48);
        detailLabel.Text = detail;
    }

    private void AppendLog(string value)
    {
        if (IsDisposed) return;
        if (InvokeRequired)
        {
            BeginInvoke(new Action(() => AppendLog(value)));
            return;
        }
        logBox.AppendText(value + Environment.NewLine);
        logBox.SelectionStart = logBox.TextLength;
        logBox.ScrollToCaret();
    }

    private void OpenBackupFolder()
    {
        if (string.IsNullOrWhiteSpace(backupFolder) || !Directory.Exists(backupFolder)) return;
        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{backupFolder}\"") { UseShellExecute = true });
    }

    private void LocateProjectManually()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "اختر مجلد manara-cloud الذي يحتوي RUN-MANARA-BACKUP.ps1",
            ShowNewFolderButton = false
        };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        var selected = NormalizeCandidate(dialog.SelectedPath);
        if (selected is null)
        {
            MessageBox.Show(this, "المجلد المختار لا يحتوي إعداد Manara الصحيح.", "Manara Backup", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
        projectRoot = selected;
        SaveProjectLocator(selected);
        detailLabel.Text = $"تم تحديد المشروع: {selected}";
        runButton.Enabled = true;
    }

    internal static bool VerifyConfiguration()
    {
        var root = FindProjectRoot();
        if (root is null) return false;
        return File.Exists(Path.Combine(root, "RUN-MANARA-BACKUP.ps1")) &&
               File.Exists(Path.Combine(root, ".tools", "backup", "backup-config.json")) &&
               File.Exists(Path.Combine(root, ".tools", "backup", "private", "supabase-secret.dpapi")) &&
               File.Exists(Path.Combine(root, ".tools", "backup", "private", "backup-password.dpapi"));
    }

    private static string? FindProjectRoot()
    {
        var candidates = new List<string?>
        {
            Environment.GetEnvironmentVariable("MANARA_PROJECT_ROOT"),
            ReadProjectLocator(),
            AppContext.BaseDirectory,
            Environment.CurrentDirectory,
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Codex", "2026-09-29", "i", "work", "manara-cloud"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Documents", "Codex", "2026-09-29", "i", "work", "manara-cloud")
        };

        var current = new DirectoryInfo(AppContext.BaseDirectory);
        for (var depth = 0; current is not null && depth < 8; depth++, current = current.Parent)
        {
            candidates.Add(current.FullName);
            candidates.Add(Path.Combine(current.FullName, "work", "manara-cloud"));
        }

        foreach (var candidate in candidates)
        {
            var normalized = NormalizeCandidate(candidate);
            if (normalized is not null) return normalized;
        }

        var codexRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Codex");
        try
        {
            foreach (var script in Directory.EnumerateFiles(codexRoot, "RUN-MANARA-BACKUP.ps1", SearchOption.AllDirectories))
            {
                var normalized = NormalizeCandidate(Path.GetDirectoryName(script));
                if (normalized is not null) return normalized;
            }
        }
        catch (Exception) { }
        return null;
    }

    private static string? NormalizeCandidate(string? candidate)
    {
        if (string.IsNullOrWhiteSpace(candidate)) return null;
        try
        {
            var full = Path.GetFullPath(candidate);
            if (File.Exists(Path.Combine(full, "RUN-MANARA-BACKUP.ps1")) &&
                File.Exists(Path.Combine(full, ".tools", "backup", "backup-config.json"))) return full;
            var nested = Path.Combine(full, "work", "manara-cloud");
            if (File.Exists(Path.Combine(nested, "RUN-MANARA-BACKUP.ps1")) &&
                File.Exists(Path.Combine(nested, ".tools", "backup", "backup-config.json"))) return nested;
        }
        catch (Exception) { }
        return null;
    }

    private static string LocatorPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Manara", "backup-project.txt");

    private static string? ReadProjectLocator()
    {
        try { return File.Exists(LocatorPath) ? File.ReadAllText(LocatorPath).Trim() : null; }
        catch (Exception) { return null; }
    }

    private static void SaveProjectLocator(string path)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(LocatorPath)!);
            File.WriteAllText(LocatorPath, path, new UTF8Encoding(false));
        }
        catch (Exception) { }
    }

    private static BackupResult? ReadLatestSuccess(string root)
    {
        try
        {
            var path = Path.Combine(root, ".tools", "backup", "last-success.json");
            var value = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(path));
            return new BackupResult(
                Convert.ToString(value["status"], CultureInfo.InvariantCulture) ?? string.Empty,
                DateTimeOffset.Parse(Convert.ToString(value["completedAt"], CultureInfo.InvariantCulture) ?? string.Empty, CultureInfo.InvariantCulture),
                Convert.ToString(value["archive"], CultureInfo.InvariantCulture) ?? string.Empty,
                Convert.ToInt64(value["bytes"], CultureInfo.InvariantCulture),
                Convert.ToString(value["sha256"], CultureInfo.InvariantCulture) ?? string.Empty);
        }
        catch (Exception) { return null; }
    }

    private static string QuoteArgument(string value) => "\"" + value.Replace("\"", "\\\"") + "\"";

    private sealed class BackupResult
    {
        public BackupResult(string status, DateTimeOffset completedAt, string archive, long bytes, string sha256)
        {
            Status = status;
            CompletedAt = completedAt;
            Archive = archive;
            Bytes = bytes;
            Sha256 = sha256;
        }

        public string Status { get; }
        public DateTimeOffset CompletedAt { get; }
        public string Archive { get; }
        public long Bytes { get; }
        public string Sha256 { get; }
    }
}

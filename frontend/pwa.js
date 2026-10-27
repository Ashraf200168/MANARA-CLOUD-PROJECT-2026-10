(function () {
  const banner = document.getElementById('pwaInstallBanner');
  const installButton = document.getElementById('pwaInstallButton');
  const dismissButton = document.getElementById('pwaInstallDismiss');
  const installText = document.getElementById('pwaInstallText');
  const DISMISS_KEY = 'manara-pwa-install-dismissed-at';
  const DISMISS_FOR = 7 * 24 * 60 * 60 * 1000;
  let deferredPrompt = null;

  const isStandalone = () => window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  const dismissedRecently = () => Date.now() - Number(localStorage.getItem(DISMISS_KEY) || 0) < DISMISS_FOR;
  const isIos = () => /iphone|ipad|ipod/i.test(navigator.userAgent);

  function showBanner(mode) {
    if (!banner || isStandalone() || dismissedRecently()) return;
    banner.classList.remove('hidden');
    if (mode === 'ios') {
      installText.textContent = 'على iPhone: اضغط زر المشاركة، ثم اختر «إضافة إلى الشاشة الرئيسية».';
      installButton.textContent = 'طريقة التثبيت';
      installButton.dataset.installMode = 'ios';
    } else {
      installText.textContent = 'افتح صفحتك من أيقونة على الهاتف دون كتابة الرابط كل مرة.';
      installButton.textContent = 'تثبيت التطبيق';
      installButton.dataset.installMode = 'prompt';
    }
  }

  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    deferredPrompt = event;
    showBanner('prompt');
  });

  installButton?.addEventListener('click', async () => {
    if (installButton.dataset.installMode === 'ios') {
      installText.textContent = 'اضغط زر المشاركة في المتصفح، ثم «إضافة إلى الشاشة الرئيسية»، ثم «إضافة».';
      return;
    }
    if (!deferredPrompt) return;
    installButton.disabled = true;
    deferredPrompt.prompt();
    const choice = await deferredPrompt.userChoice;
    deferredPrompt = null;
    installButton.disabled = false;
    if (choice.outcome === 'accepted') banner?.classList.add('hidden');
  });

  dismissButton?.addEventListener('click', () => {
    localStorage.setItem(DISMISS_KEY, String(Date.now()));
    banner?.classList.add('hidden');
  });

  window.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    localStorage.removeItem(DISMISS_KEY);
    banner?.classList.add('hidden');
  });

  if (isIos() && !isStandalone()) showBanner('ios');

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/service-worker.js', { scope: '/' }).catch(error => {
        console.warn('تعذر تفعيل وضع التطبيق', error);
      });
    });
  }
})();

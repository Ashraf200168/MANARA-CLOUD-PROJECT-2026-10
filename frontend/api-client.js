(function () {
  const config = window.MANARA_CLOUD || {};
  const base = String(config.apiBase || '').replace(/\/$/, '');
  const ADMIN_TOKEN = 'manara-cloud-admin-token';
  const STUDENT_TOKEN = 'manara-cloud-student-token';
  const REGISTRATION_TOKEN = 'manara-cloud-registration-token';

  function apiUrl(path) {
    if (/^https?:\/\//i.test(path)) return path;
    if (!base || base.includes('YOUR_PROJECT_REF')) return path;
    return `${base}${path}`;
  }

  function tokenFor(path) {
    const route = /^https?:\/\//i.test(path) ? new URL(path).pathname.replace(/^.*\/manara-api/, '') : path;
    if (route.startsWith('/api/admin/')) return sessionStorage.getItem(ADMIN_TOKEN) || '';
    if (route.startsWith('/api/student/')) return localStorage.getItem(STUDENT_TOKEN) || '';
    return '';
  }

  async function request(path, options = {}) {
    const headers = new Headers(options.headers || {});
    if (options.body && typeof options.body === 'string' && !headers.has('Content-Type')) {
      headers.set('Content-Type', 'application/json');
    }
    if (config.publishableKey && !String(config.publishableKey).includes('YOUR_SUPABASE')) {
      headers.set('apikey', config.publishableKey);
    }
    const token = tokenFor(path);
    if (token) headers.set('Authorization', `Bearer ${token}`);
    const registrationToken = localStorage.getItem(REGISTRATION_TOKEN);
    if (registrationToken && (path === '/api/student/register' || path.endsWith('/manara-api/api/student/register'))) {
      headers.set('X-Manara-Registration', registrationToken);
    }
    const response = await fetch(apiUrl(path), { ...options, headers });
    const type = response.headers.get('content-type') || '';
    if (!type.includes('application/json')) return response;
    const data = await response.json().catch(() => ({ error: 'استجابة غير صالحة' }));
    if (!response.ok) throw new Error(data.error || 'تعذر إكمال الطلب');
    if (data.adminToken) sessionStorage.setItem(ADMIN_TOKEN, data.adminToken);
    if (data.studentToken) localStorage.setItem(STUDENT_TOKEN, data.studentToken);
    if (data.registrationToken) localStorage.setItem(REGISTRATION_TOKEN, data.registrationToken);
    if (data.clearAdminToken) sessionStorage.removeItem(ADMIN_TOKEN);
    if (data.clearStudentToken) localStorage.removeItem(STUDENT_TOKEN);
    return data;
  }

  window.manaraCloudApi = Object.freeze({
    request,
    apiUrl,
    clearAdmin: () => sessionStorage.removeItem(ADMIN_TOKEN),
    clearStudent: () => localStorage.removeItem(STUDENT_TOKEN)
  });
})();

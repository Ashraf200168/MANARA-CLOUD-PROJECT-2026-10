export function corsHeaders(request: Request): Record<string, string> {
  const configured = (Deno.env.get('ALLOWED_ORIGINS') || '').split(',').map(v => v.trim()).filter(Boolean);
  const origin = request.headers.get('origin') || '';
  const allowed = configured.includes(origin) ? origin : (configured[0] || 'http://localhost:8788');
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-manara-registration',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin'
  };
}

export function jsonResponse(request: Request, data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders(request),
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'X-Manara-Backend': 'supabase-edge'
    }
  });
}

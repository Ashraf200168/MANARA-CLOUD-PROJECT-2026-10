import scryptModule from 'npm:scrypt-js@3.0.1';

// scrypt-js is published as CommonJS. Supabase Edge Runtime exposes that
// module through its default export rather than synthesising named exports.
const { scrypt } = scryptModule;

const encoder = new TextEncoder();

export function randomToken(bytes = 32): string {
  const value = crypto.getRandomValues(new Uint8Array(bytes));
  return btoa(String.fromCharCode(...value)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

export async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value));
  return [...new Uint8Array(digest)].map(v => v.toString(16).padStart(2, '0')).join('');
}

function fromHex(value: string): Uint8Array {
  if (!/^[0-9a-f]+$/i.test(value) || value.length % 2) return new Uint8Array();
  return new Uint8Array(value.match(/.{2}/g)!.map(byte => Number.parseInt(byte, 16)));
}

export async function verifyLegacyPassword(password: string, stored: string): Promise<boolean> {
  const [salt, expectedHex] = String(stored || '').split(':');
  if (!salt || !expectedHex) return false;
  const expected = fromHex(expectedHex);
  if (!expected.length) return false;
  const actual = await scrypt(encoder.encode(password), encoder.encode(salt), 16384, 8, 1, expected.length);
  if (actual.length !== expected.length) return false;
  let difference = 0;
  for (let i = 0; i < actual.length; i += 1) difference |= actual[i] ^ expected[i];
  return difference === 0;
}

export async function legacyPasswordHash(password: string): Promise<string> {
  const saltBytes = crypto.getRandomValues(new Uint8Array(16));
  const salt = [...saltBytes].map(value => value.toString(16).padStart(2, '0')).join('');
  const result = await scrypt(encoder.encode(password), encoder.encode(salt), 16384, 8, 1, 64);
  const hash = [...result].map(value => value.toString(16).padStart(2, '0')).join('');
  return `${salt}:${hash}`;
}

export function bearer(request: Request): string {
  const value = request.headers.get('authorization') || '';
  return value.startsWith('Bearer ') ? value.slice(7).trim() : '';
}

export function normalizeArabic(value = ''): string {
  return String(value).normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g, '')
    .replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه').replace(/\s+/g, ' ').trim().toLowerCase();
}

export function code(prefix = 'MN'): string {
  const hex = [...crypto.getRandomValues(new Uint8Array(5))].map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase();
  return `${prefix}-${hex.slice(0, 5)}-${hex.slice(5)}`;
}

export function studentCode(): string {
  const hex = [...crypto.getRandomValues(new Uint8Array(6))].map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase();
  return `ST-${hex.slice(0, 4)}-${hex.slice(4, 8)}-${hex.slice(8)}`;
}

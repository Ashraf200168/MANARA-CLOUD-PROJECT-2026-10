import { createDecipheriv, scryptSync } from 'node:crypto';
import { createReadStream, createWriteStream, existsSync, openSync, closeSync, readSync, renameSync, rmSync, statSync } from 'node:fs';
import { once } from 'node:events';

const source = process.argv[2];
const destination = process.argv[3];
const passphrase = process.env.MANARA_BACKUP_PASSPHRASE;
if (!source || !destination || !passphrase) throw new Error('Source, destination, and MANARA_BACKUP_PASSPHRASE are required');
if (!existsSync(source)) throw new Error(`Encrypted backup not found: ${source}`);
if (existsSync(destination)) throw new Error(`Refusing to overwrite decrypted archive: ${destination}`);

const size = statSync(source).size;
const headerLength = 8 + 16 + 12;
const tagLength = 16;
if (size <= headerLength + tagLength) throw new Error('Backup is truncated');

const descriptor = openSync(source, 'r');
const header = Buffer.alloc(headerLength);
const tag = Buffer.alloc(tagLength);
try {
  readSync(descriptor, header, 0, header.length, 0);
  readSync(descriptor, tag, 0, tag.length, size - tagLength);
} finally {
  closeSync(descriptor);
}

if (header.subarray(0, 8).toString('ascii') !== 'MNBAK001') throw new Error('Unsupported Manara backup format');
const salt = header.subarray(8, 24);
const iv = header.subarray(24, 36);
const key = scryptSync(passphrase, salt, 32, { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
const decipher = createDecipheriv('aes-256-gcm', key, iv);
decipher.setAuthTag(tag);
const temporary = `${destination}.part`;

try {
  const output = createWriteStream(temporary, { flags: 'wx', mode: 0o600 });
  const input = createReadStream(source, { start: headerLength, end: size - tagLength - 1 });
  for await (const chunk of input) {
    if (!output.write(decipher.update(chunk))) await once(output, 'drain');
  }
  output.write(decipher.final());
  output.end();
  await once(output, 'finish');
  renameSync(temporary, destination);
  console.log(`Backup decrypted and authenticated: ${destination}`);
} catch (error) {
  rmSync(temporary, { force: true });
  throw new Error(`Backup authentication failed. The password may be wrong or the file may be damaged. ${error.message}`);
}

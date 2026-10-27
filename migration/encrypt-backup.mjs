import { createCipheriv, randomBytes, scryptSync } from 'node:crypto';
import { createReadStream, createWriteStream, existsSync, renameSync, rmSync } from 'node:fs';
import { once } from 'node:events';

const source = process.argv[2];
const destination = process.argv[3];
const passphrase = process.env.MANARA_BACKUP_PASSPHRASE;
if (!source || !destination || !passphrase) throw new Error('Source, destination, and MANARA_BACKUP_PASSPHRASE are required');
if (!existsSync(source)) throw new Error(`Source archive not found: ${source}`);
if (existsSync(destination)) throw new Error(`Refusing to overwrite encrypted backup: ${destination}`);

const magic = Buffer.from('MNBAK001', 'ascii');
const salt = randomBytes(16);
const iv = randomBytes(12);
const key = scryptSync(passphrase, salt, 32, { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
const cipher = createCipheriv('aes-256-gcm', key, iv);
const temporary = `${destination}.part`;

try {
  const output = createWriteStream(temporary, { flags: 'wx', mode: 0o600 });
  output.write(Buffer.concat([magic, salt, iv]));
  for await (const chunk of createReadStream(source)) {
    if (!output.write(cipher.update(chunk))) await once(output, 'drain');
  }
  output.write(cipher.final());
  output.end(cipher.getAuthTag());
  await once(output, 'finish');
  renameSync(temporary, destination);
  console.log(`Encrypted backup created: ${destination}`);
} catch (error) {
  rmSync(temporary, { force: true });
  throw error;
}

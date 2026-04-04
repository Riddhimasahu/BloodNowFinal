import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const serverRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const envPath = path.join(serverRoot, '.env');

if (process.env.NODE_ENV !== 'production') {
  const result = dotenv.config({ path: envPath });
  if (result.error) {
    if (result.error.code === 'ENOENT') {
      console.warn(
        `No file at ${envPath}. Copy server/.env.example to server/.env and set DATABASE_URL.`,
      );
    } else {
      console.warn('dotenv:', result.error.message);
    }
  }
} else {
  console.log('Production mode - using environment variables from Render.');
}
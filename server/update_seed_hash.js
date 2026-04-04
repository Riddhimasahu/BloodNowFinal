import fs from 'fs';
import bcrypt from 'bcryptjs';

const hash = bcrypt.hashSync('bloodbank123', 10);
const path = 'db/seed_kota.sql';
let sql = fs.readFileSync(path, 'utf8');
// Replace all existing bcrypt hashes in the VALUES block with the new hash for bloodbank123
sql = sql.replace(/\$2b\$10\$[a-zA-Z0-9./]+/g, hash);
fs.writeFileSync(path, sql);
console.log('Successfully updated seed_kota.sql with the new hash for bloodbank123.');

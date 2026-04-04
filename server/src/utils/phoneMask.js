export function maskPhone(phone) {
  if (phone == null || String(phone).length === 0) return '••••';
  const s = String(phone).trim();
  if (s.length <= 4) return '••••';
  return `${'•'.repeat(s.length - 4)}${s.slice(-4)}`;
}

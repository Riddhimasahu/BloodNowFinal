import jwt from 'jsonwebtoken';

function verify(req, res) {
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'Missing bearer token' });
    return null;
  }
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    res.status(500).json({ error: 'Server misconfiguration' });
    return null;
  }
  try {
    return jwt.verify(token, secret);
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
    return null;
  }
}

/** Attaches `req.auth` with JWT payload `{ sub, email, typ }` */
export function requireAuth(req, res, next) {
  const payload = verify(req, res);
  if (!payload) return;
  req.auth = payload;
  next();
}

export function requireUser(req, res, next) {
  const payload = verify(req, res);
  if (!payload) return;
  if (payload.typ !== 'user') {
    return res.status(403).json({ error: 'User session required' });
  }
  req.auth = payload;
  next();
}

export function requireBank(req, res, next) {
  const payload = verify(req, res);
  if (!payload) return;
  if (payload.typ !== 'bank' && payload.role !== 'blood_bank') {
    return res.status(403).json({ error: 'Blood bank session required' });
  }
  req.auth = payload;
  if (payload.role === 'blood_bank' && payload.blood_bank_id) {
    req.auth.sub = String(payload.blood_bank_id);
  }
  next();
}

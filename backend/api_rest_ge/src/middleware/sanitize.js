import xss from 'xss';

function deepSanitize(obj) {
  if (!obj || typeof obj !== 'object') return obj;
  for (const k of Object.keys(obj)) {
    const v = obj[k];
    if (typeof v === 'string') obj[k] = xss(v);
    else if (Array.isArray(v)) obj[k] = v.map(it => (typeof it === 'string' ? xss(it) : it));
    else if (typeof v === 'object') deepSanitize(v);
  }
  return obj;
}

export function sanitizeBodyAndParams(req, _res, next) {
  if (req.body) deepSanitize(req.body);
  if (req.params) deepSanitize(req.params);
  // OJO: en Express 5, req.query es de solo lectura. Si quieres sanearlo:
  // const safeQuery = deepSanitize({ ...req.query });
  // req.sanitized = { ...(req.sanitized || {}), query: safeQuery };
  next();
}

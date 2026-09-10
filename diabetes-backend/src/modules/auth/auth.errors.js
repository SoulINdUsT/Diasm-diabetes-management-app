// Only these deliberately public errors may be returned to session clients.
export class SessionError extends Error {
  constructor(status, code, message) {
    super(message);
    this.name = 'SessionError';
    this.status = status;
    this.code = code;
  }
}

export function sendSessionError(res, error) {
  if (error instanceof SessionError) {
    return res.status(error.status).json({ code: error.code, message: error.message });
  }

  // Database, signing, and other infrastructure failures do not invalidate
  // credentials. Never return SQL, connection details, or raw error messages.
  return res.status(503).json({
    code: 'AUTH_SERVICE_UNAVAILABLE',
    message: 'Authentication service is temporarily unavailable. Please try again.',
  });
}

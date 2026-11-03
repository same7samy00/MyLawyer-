import { FastifyReply, FastifyRequest } from 'fastify';

export interface AuthenticatedUser {
  userId: string;
  role: 'client' | 'lawyer' | 'admin';
}

export const UUID_PATTERN = /^[0-9a-f-]{36}$/i;

/// A refusal with a clear message for the person, answered by the error handler in app.ts
export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

/// Signs the request in, and refuses anyone outside the given roles
export function requireAuth(roles?: AuthenticatedUser['role'][], forbiddenMessage = 'غير مصرح لك بهذه العملية', signInMessage = 'غير مصرح: يرجى تسجيل الدخول') {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: signInMessage });
    }
    if (roles && !roles.includes((request.user as AuthenticatedUser).role)) {
      return reply.status(403).send({ success: false, error: forbiddenMessage });
    }
  };
}

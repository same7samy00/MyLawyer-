import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { query } from '../../database/index.js';
import { sanitizeText } from '../../utils/security.js';

/// What the installed app itself needs from the server: the oldest build still served, and a place to report
/// a crash from someone's phone.

const VERSION_SECONDS = 60;
let version: { at: number; minBuild: number; updateUrl: string | null } | null = null;

/// Read from the settings at most once a minute per worker, so the check costs a request nothing
export async function appVersion() {
  if (!version || Date.now() - version.at >= VERSION_SECONDS * 1000) {
    const res = await query('SELECT min_app_build, app_update_url FROM platform_settings LIMIT 1');
    version = { at: Date.now(), minBuild: Number(res.rows[0]?.min_app_build ?? 0), updateUrl: res.rows[0]?.app_update_url ?? null };
  }
  return version;
}

export function forgetAppVersion() {
  version = null;
}

/// An app older than the oldest allowed build gets one clear answer on every request, and shows its update page.
/// A request with no build number is not the app (the control page, the site) or is older than this rule
export async function refuseOldApp(request: FastifyRequest, reply: FastifyReply) {
  const build = Number(request.headers['x-app-build']);
  if (!Number.isInteger(build) || build <= 0) return;
  const { minBuild, updateUrl } = await appVersion();
  if (build >= minBuild) return;
  return reply.status(426).send({ success: false, error: 'حدّث التطبيق عشان تكمّل', data: { status: 'update_required', updateUrl } });
}

export async function appClientRoutes(fastify: FastifyInstance) {
  // A crash or an unexpected error on a phone. Open to a signed-out app too, so it is small and limited
  fastify.post('/errors', { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } }, async (request: FastifyRequest, reply: FastifyReply) => {
    const body = (request.body || {}) as { message?: unknown; stack?: unknown; platform?: unknown };
    if (typeof body.message !== 'string' || !body.message.trim()) return reply.status(400).send({ success: false, error: 'رسالة الخطأ مطلوبة' });

    let userId: string | null = null;
    try {
      userId = ((await request.jwtVerify()) as { userId?: string }).userId ?? null;
    } catch {
      // A crash before sign-in is still worth knowing about
    }
    const build = Number(request.headers['x-app-build']);
    await query(
      'INSERT INTO app_errors (user_id, app_build, platform, message, stack) VALUES ($1, $2, $3, $4, $5)',
      [
        userId, Number.isInteger(build) && build > 0 ? build : null,
        typeof body.platform === 'string' ? sanitizeText(body.platform, 20) : null,
        sanitizeText(body.message, 500), typeof body.stack === 'string' ? sanitizeText(body.stack, 4000) : null,
      ]
    );
    return reply.status(201).send({ success: true });
  });
}

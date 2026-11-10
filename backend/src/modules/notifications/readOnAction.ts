import { FastifyInstance } from 'fastify';
import { query } from '../../database/index.js';
import { UUID_PATTERN } from '../../utils/http.js';

/// Like the big apps: once a person acts on an order, a request or a ticket (pays, arrives, finishes, sends a
/// price, replies), their notifications about it are read. The news they spoke about is handled.
/// Runs before the answer leaves, so the app's next badge count already sees it.
export function readOnAction(fastify: FastifyInstance, column: 'order_id' | 'request_id' | 'ticket_id') {
  fastify.addHook('onSend', async (request, reply, payload) => {
    if (request.method !== 'POST' || reply.statusCode >= 400) return payload;
    const id = (request.params as { id?: string } | undefined)?.id;
    const userId = (request.user as { userId?: string } | undefined)?.userId;
    if (!id || !userId || !UUID_PATTERN.test(id)) return payload;
    await query(
      `UPDATE notifications SET read_at = NOW() WHERE user_id = $1 AND ${column} = $2 AND read_at IS NULL`,
      [userId, id],
    ).catch(() => undefined);
    return payload;
  });
}

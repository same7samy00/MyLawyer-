import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import pg from 'pg';
import { FastifyRequest } from 'fastify';
import { config } from '../../config/index.js';
import { sanitizeText } from '../../utils/security.js';
import { detectFileType } from '../../utils/files.js';

type Db = pg.Pool | pg.PoolClient;

export const TICKET_CATEGORIES = ['ORDER', 'MONEY', 'ACCOUNT', 'OTHER'] as const;
export type TicketCategory = typeof TICKET_CATEGORIES[number];
export const MAX_OPEN_TICKETS = 3;
export const MAX_IMAGES = 5;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const ATTACHMENTS_DIR = () => path.join(config.privateStoragePath, 'support');

export class TicketError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

/// The fees wait for the admin decision
export async function freezePayout(db: Db, order: any) {
  if (order.status === 'COMPLETED') {
    await db.query(`UPDATE service_orders SET payout_status = 'FROZEN' WHERE id = $1 AND payout_status IN ('HELD', 'AVAILABLE')`, [order.id]);
  }
}

/// SQL condition: the order has an open ticket, which holds the task and the fees until the admin decides
export const OPEN_ORDER_TICKET = (orderColumn: string) =>
  `EXISTS (SELECT 1 FROM support_tickets st WHERE st.order_id = ${orderColumn} AND st.status <> 'CLOSED')`;

export interface TicketForm {
  fields: Record<string, string>;
  images: { buffer: Buffer; ext: string; mime: string }[];
}

/// Reads the text fields and up to 5 images from a multipart form, or a plain JSON body
export async function readTicketForm(request: FastifyRequest): Promise<TicketForm> {
  if (!request.isMultipart()) {
    const body = (request.body || {}) as Record<string, unknown>;
    return { fields: Object.fromEntries(Object.entries(body).map(([key, value]) => [key, String(value ?? '')])), images: [] };
  }

  const fields: Record<string, string> = {};
  const images: TicketForm['images'] = [];
  for await (const part of request.parts({ limits: { files: MAX_IMAGES, fileSize: MAX_IMAGE_BYTES } })) {
    if (part.type === 'file') {
      const buffer = await part.toBuffer();
      if (part.file.truncated) throw new TicketError(400, 'الصورة أكبر من 5 ميجا');
      const type = detectFileType(buffer);
      if (!type?.mime.startsWith('image/')) throw new TicketError(400, 'الملفات لازم تكون صور');
      images.push({ buffer, ext: type.ext, mime: type.mime });
    } else {
      fields[part.fieldname] = String(part.value ?? '');
    }
  }
  return { fields, images };
}

/// Saves one message with its images
export async function addMessage(db: Db, ticketId: string, author: 'USER' | 'ADMIN' | 'NOTE', authorId: string, body: string, images: TicketForm['images']) {
  const text = sanitizeText(body, 4000).trim();
  if (!text && images.length === 0) throw new TicketError(400, 'اكتب رسالتك أو ضيف صورة');

  const res = await db.query(
    'INSERT INTO ticket_messages (ticket_id, author, author_id, body) VALUES ($1, $2, $3, $4) RETURNING id',
    [ticketId, author, authorId, text]
  );
  const messageId = res.rows[0].id;

  if (images.length > 0) fs.mkdirSync(ATTACHMENTS_DIR(), { recursive: true });
  for (const image of images) {
    const fileName = `${crypto.randomUUID()}${image.ext}`;
    fs.writeFileSync(path.join(ATTACHMENTS_DIR(), fileName), image.buffer);
    await db.query('INSERT INTO ticket_attachments (message_id, file_name, mime) VALUES ($1, $2, $3)', [messageId, fileName, image.mime]);
  }
  await db.query('UPDATE support_tickets SET updated_at = NOW() WHERE id = $1', [ticketId]);
  return messageId;
}

/// The messages of one ticket in order, each with its image links. Internal notes only for admins.
export async function ticketMessages(db: Db, ticketId: string, includeNotes: boolean) {
  const res = await db.query(
    `SELECT m.id, m.author, m.body, m.created_at,
            COALESCE(json_agg(a.id ORDER BY a.created_at) FILTER (WHERE a.id IS NOT NULL), '[]') AS images
     FROM ticket_messages m LEFT JOIN ticket_attachments a ON a.message_id = m.id
     WHERE m.ticket_id = $1 ${includeNotes ? '' : "AND m.author <> 'NOTE'"}
     GROUP BY m.id ORDER BY m.created_at ASC`,
    [ticketId]
  );
  return res.rows.map((row) => ({
    id: row.id,
    author: row.author,
    body: row.body,
    createdAt: row.created_at,
    images: (row.images as string[]).map((id) => `/support/attachments/${id}`),
  }));
}

/// Finds an attachment file the viewer is allowed to see
export async function attachmentFile(db: Db, attachmentId: string, viewer: { userId: string; role: string }) {
  if (!/^[0-9a-f-]{36}$/i.test(attachmentId)) return null;
  const res = await db.query(
    `SELECT a.file_name, a.mime, t.user_id FROM ticket_attachments a
     JOIN ticket_messages m ON m.id = a.message_id
     JOIN support_tickets t ON t.id = m.ticket_id
     WHERE a.id = $1 AND m.author <> 'NOTE'`,
    [attachmentId]
  );
  const row = res.rows[0];
  if (!row || (viewer.role !== 'admin' && row.user_id !== viewer.userId)) return null;
  const filePath = path.join(ATTACHMENTS_DIR(), path.basename(row.file_name));
  return fs.existsSync(filePath) ? { filePath, mime: row.mime as string } : null;
}

export const STATUS_LABELS: Record<string, string> = { UNDER_REVIEW: 'تحت المراجعة', OPEN: 'مفتوحة', CLOSED: 'مقفولة' };
export const CATEGORY_LABELS: Record<string, string> = { ORDER: 'مشكلة في طلب', MONEY: 'الفلوس والمحفظة', ACCOUNT: 'الحساب', OTHER: 'حاجة تانية' };

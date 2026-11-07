import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { FastifyRequest } from 'fastify';
import { config } from '../../config/index.js';
import { Db } from '../../database/index.js';
import { detectFileType } from '../../utils/files.js';
import { HttpError, UUID_PATTERN } from '../../utils/http.js';

export const CONSULTATION_KINDS = ['CALL', 'PAPERS'] as const;
export type ConsultationKind = typeof CONSULTATION_KINDS[number];
const MAX_PAGE_BYTES = 6 * 1024 * 1024;
const PAGES_DIR = () => path.join(config.privateStoragePath, 'consultations');

export interface ConsultationSettings {
  callPrice: number;
  papersBasePrice: number;
  pagePrice: number;
  maxPages: number;
  callMinutes: number;
  minDetailsChars: number;
  isOpen: boolean;
}

export async function readSettings(db: Db): Promise<ConsultationSettings> {
  const res = await db.query('SELECT * FROM consultation_settings LIMIT 1');
  const row = res.rows[0] ?? {};
  return {
    callPrice: Number(row.call_price ?? 200),
    papersBasePrice: Number(row.papers_base_price ?? 250),
    pagePrice: Number(row.page_price ?? 30),
    maxPages: Number(row.max_pages ?? 10),
    callMinutes: Number(row.call_minutes ?? 7),
    minDetailsChars: Number(row.min_details_chars ?? 50),
    isOpen: row.is_open ?? true,
  };
}

/// السعر بيتحسب هنا بس، فالتطبيق ما يقدرش يغيره
export function priceOf(settings: ConsultationSettings, kind: ConsultationKind, pages: number) {
  const lines = kind === 'CALL'
    ? [{ label: 'استشارة', amount: settings.callPrice }]
    : [
        { label: 'الاطلاع والاستشارة', amount: settings.papersBasePrice },
        { label: `${pages} ورقة × ${settings.pagePrice}`, amount: pages * settings.pagePrice },
      ];
  return { lines, total: lines.reduce((sum, line) => sum + line.amount, 0) };
}

export interface ConsultationForm {
  fields: Record<string, string>;
  pages: { buffer: Buffer; ext: string; mime: string }[];
}

/// بيقرا الحقول وصور الورق من فورم multipart، وكل صورة لازم تكون صورة فعلًا
export async function readConsultationForm(request: FastifyRequest, maxPages: number): Promise<ConsultationForm> {
  if (!request.isMultipart()) {
    const body = (request.body || {}) as Record<string, unknown>;
    return { fields: Object.fromEntries(Object.entries(body).map(([key, value]) => [key, String(value ?? '')])), pages: [] };
  }
  const fields: Record<string, string> = {};
  const pages: ConsultationForm['pages'] = [];
  for await (const part of request.parts({ limits: { files: maxPages + 1, fileSize: MAX_PAGE_BYTES } })) {
    if (part.type === 'file') {
      const buffer = await part.toBuffer();
      if (part.file.truncated) throw new HttpError(400, 'الصورة أكبر من 6 ميجا');
      const type = detectFileType(buffer);
      if (!type?.mime.startsWith('image/')) throw new HttpError(400, 'الملفات لازم تكون صور');
      pages.push({ buffer, ext: type.ext, mime: type.mime });
    } else {
      fields[part.fieldname] = String(part.value ?? '');
    }
  }
  if (pages.length > maxPages) throw new HttpError(400, `الحد الأقصى ${maxPages} ورقات`);
  return { fields, pages };
}

export async function savePages(db: Db, consultationId: string, pages: ConsultationForm['pages']) {
  if (pages.length === 0) return;
  await fs.promises.mkdir(PAGES_DIR(), { recursive: true });
  for (const page of pages) {
    const fileName = `${crypto.randomUUID()}${page.ext}`;
    await fs.promises.writeFile(path.join(PAGES_DIR(), fileName), page.buffer);
    await db.query('INSERT INTO consultation_pages (consultation_id, file_name, mime) VALUES ($1, $2, $3)', [consultationId, fileName, page.mime]);
  }
}

export async function pageLinks(db: Db, consultationId: string) {
  const res = await db.query('SELECT id FROM consultation_pages WHERE consultation_id = $1 ORDER BY created_at', [consultationId]);
  return res.rows.map((row) => `/consultations/pages/${row.id}`);
}

/// صورة ورقة لصاحب الاستشارة أو للإدارة بس
export async function pageFile(db: Db, pageId: string, viewer: { userId: string; role: string }) {
  if (!UUID_PATTERN.test(pageId)) return null;
  const res = await db.query(
    `SELECT p.file_name, p.mime, c.client_id FROM consultation_pages p JOIN consultations c ON c.id = p.consultation_id WHERE p.id = $1`,
    [pageId]
  );
  const row = res.rows[0];
  if (!row || (viewer.role !== 'admin' && row.client_id !== viewer.userId)) return null;
  const filePath = path.join(PAGES_DIR(), path.basename(row.file_name));
  return fs.existsSync(filePath) ? { filePath, mime: row.mime as string } : null;
}

export const STATUS_TEXT: Record<string, string> = {
  PAID: 'مستني مكالمة فريقنا',
  CONTACTING: 'فريقنا بيكلمك دلوقتي',
  DONE: 'الاستشارة تمت',
  REJECTED: 'اترفضت والمبلغ رجع لرصيدك',
};

export const listItem = (row: any) => ({
  id: row.id,
  reference: row.reference,
  kind: row.kind,
  pages: row.pages,
  price: Number(row.price),
  status: row.status,
  statusText: STATUS_TEXT[row.status] ?? row.status,
  rejectReason: row.reject_reason,
  createdAt: row.created_at,
});

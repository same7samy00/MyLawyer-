import { FastifyInstance } from 'fastify';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

const CONTENT_TYPES: Record<string, string> = {
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.png': 'image/png',
};

/// Serves the control page. Its files change name with every release, so browsers can keep them for a year
export function registerAdminPanel(api: FastifyInstance) {
  const root = path.resolve(process.cwd(), 'public/admin');
  const version = crypto.randomBytes(6).toString('hex');
  const page = () => fs.readFileSync(path.join(root, 'index.html'), 'utf-8').replaceAll('__VERSION__', version);

  api.get('/admin-panel', async (_request, reply) => {
    return reply.header('Cache-Control', 'no-cache').type('text/html; charset=utf-8').send(page());
  });

  api.get('/admin-panel/assets/*', async (request, reply) => {
    const relative = (request.params as { '*': string })['*'];
    const file = path.resolve(root, relative);
    const type = CONTENT_TYPES[path.extname(file)];
    if (!type || !file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      return reply.status(404).send({ success: false, error: 'الملف غير موجود' });
    }
    return reply.header('Cache-Control', 'public, max-age=31536000, immutable').type(type).send(fs.readFileSync(file));
  });
}

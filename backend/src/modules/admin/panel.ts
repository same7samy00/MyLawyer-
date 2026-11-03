import { FastifyInstance } from 'fastify';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

// Loaded together in this order, because later files use what earlier ones define
const STYLES = ['css/base.css', 'css/panel.css', 'css/lists.css', 'css/profile.css'];
const SCRIPTS = [
  'js/core.js',
  'js/components.js',
  'js/pages/overview.js',
  'js/pages/tickets.js',
  'js/windows.js',
  'js/actions.js',
  'js/pages/ticket.js',
  'js/pages/reports.js',
  'js/pages/applications.js',
  'js/pages/accounts.js',
  'js/pages/orders.js',
  'js/pages/reviews.js',
  'js/pages/prices.js',
  'js/pages/money.js',
  'js/pages/decisions.js',
  'js/router.js',
  'js/app.js',
];
const FONTS: Record<string, string> = {
  thin: 'Thin',
  extralight: 'ExtraLight',
  light: 'Light',
  regular: 'Regular',
  medium: 'Medium',
  semibold: 'SemiBold',
};
const YEAR_CACHE = 'public, max-age=31536000, immutable';

/// Serves the control page. Links have no file extension because Nginx answers those itself,
/// and they change with every release, so browsers can keep the files for a year.
export function registerAdminPanel(api: FastifyInstance) {
  const root = path.resolve(process.cwd(), 'public/admin');
  const version = crypto.randomBytes(6).toString('hex');
  const read = (file: string) => fs.readFileSync(path.join(root, file));
  const joined = (files: string[]) => files.map((file) => read(file).toString('utf-8')).join('\n');

  // Read once at start, a release restarts the server, so no request waits on the disk
  const page = read('index.html').toString('utf-8').replaceAll('__VERSION__', version);
  const styles = joined(STYLES);
  const script = joined(SCRIPTS);
  const logo = read('assets/logo.png');
  const fonts = new Map(Object.entries(FONTS).map(([weight, file]) => [weight, read(`fonts/IBMPlexSansArabic-${file}.woff2`)]));

  api.get('/admin-panel', async (_request, reply) => {
    return reply.header('Cache-Control', 'no-cache').type('text/html; charset=utf-8').send(page);
  });
  api.get('/admin-panel/styles', async (_request, reply) => {
    return reply.header('Cache-Control', YEAR_CACHE).type('text/css; charset=utf-8').send(styles);
  });
  api.get('/admin-panel/script', async (_request, reply) => {
    return reply.header('Cache-Control', YEAR_CACHE).type('application/javascript; charset=utf-8').send(script);
  });
  api.get('/admin-panel/logo', async (_request, reply) => {
    return reply.header('Cache-Control', YEAR_CACHE).type('image/png').send(logo);
  });
  api.get('/admin-panel/font/:weight', async (request, reply) => {
    const font = fonts.get((request.params as { weight: string }).weight);
    if (!font) return reply.status(404).send();
    return reply.header('Cache-Control', YEAR_CACHE).type('font/woff2').send(font);
  });
}

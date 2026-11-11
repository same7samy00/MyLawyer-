# My Lawyer

منصة قانونية عربية تربط الموكلين بالمحامين. الخدمات الشغالة: «محاميك حالاً» و«استشارة سريعة». المشروع في التطوير ومفيش مستخدمين حقيقيين.

| الجزء | المكان | التقنية |
|---|---|---|
| التطبيق | `lib/` | Flutter |
| الخادم | `backend/src/` | Fastify وTypeScript وPostgreSQL |
| لوحة التحكم | `backend/public/admin/` | HTML وJavaScript، على `/api/v1/admin-panel` |
| الموقع العام | `backend/public/site/` | HTML، وNginx بيعرضه |
| الخرائط | `docs/GPS_SYSTEM.md` | TomTom عن طريق سيرفرنا |
| سكريبتات السيرفر | `backend/ops/` و`backend/deploy.sh` | Bash |

الوضع الحالي في [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md)، وفهرس التوثيق في [`docs/README.md`](docs/README.md)، وقواعد العمل لأي مطور أو نموذج في [`CLAUDE.md`](CLAUDE.md).

## التشغيل
```bash
flutter run
```
```bash
cd backend && npm run preview:panel
```

## الفحوصات
```bash
flutter analyze && flutter test
```
```bash
cd backend && npx tsc --noEmit && npm test
```

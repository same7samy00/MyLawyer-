# My Lawyer

منصة قانونية عربية تربط الموكلين بالمحامين. الخدمة الشغالة دلوقتي هي «محاميك حالاً»، والمشروع لسه في مرحلة التطوير.

| الجزء | المكان | التقنية |
|---|---|---|
| التطبيق | `lib/` | Flutter |
| الخادم | `backend/src/` | Fastify وTypeScript وPostgreSQL |
| لوحة التحكم | `backend/public/admin/` | HTML وJavaScript، على `/api/v1/admin-panel` |
| الموقع العام | `backend/public/site/` | HTML، وNginx بيعرضه |
| الخرائط | `docs/GPS_SYSTEM.md` | TomTom عن طريق سيرفرنا |

## التوثيق
| الملف | المحتوى |
|---|---|
| [`AGENTS.md`](AGENTS.md) | القواعد الملزمة ودورة العمل |
| [`docs/HANDOFF.md`](docs/HANDOFF.md) | الوضع الحالي والتشغيل |
| [`docs/memory/PENDING_TASKS.md`](docs/memory/PENDING_TASKS.md) | المهام |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | قرارات صاحب المشروع |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | المعمارية |
| [`docs/API_DOCUMENTATION.md`](docs/API_DOCUMENTATION.md) | مسارات الخادم |
| [`docs/DATABASE_ARCHITECTURE.md`](docs/DATABASE_ARCHITECTURE.md) | قاعدة البيانات |
| [`docs/GPS_SYSTEM.md`](docs/GPS_SYSTEM.md) | الموقع والخريطة |
| [`docs/SERVER_ARCHITECTURE.md`](docs/SERVER_ARCHITECTURE.md) | السيرفرين |
| [`docs/DEVELOPMENT_GUIDE.md`](docs/DEVELOPMENT_GUIDE.md) | التشغيل والرفع |

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

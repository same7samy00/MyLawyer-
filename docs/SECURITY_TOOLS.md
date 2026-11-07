# أدوات الأمان

**آخر تحقق:** 2026-11-07. السياسة والأسرار في [`SECURITY.md`](SECURITY.md)، والمقترح الكامل بالتكلفة في [`SERVER_TOOLS.md`](SERVER_TOOLS.md).

| الأداة | الحالة | التشغيل |
|---|---|---|
| UFW (22 و80 و443 بس) | ✅ السيرفرين | `ufw status` |
| fail2ban على SSH | ✅ السيرفرين | `fail2ban-client status sshd` |
| SSH بالمفتاح بس | ✅ السيرفرين | `sshd -T \| grep passwordauthentication` |
| TLS 1.2 و1.3 بس | ✅ الجديد (OPS-04). القديم فيه برضه | `curl --tls-max 1.1 https://my-lawyer.online` لازم يفشل |
| تجديد الشهادات | ✅ `certbot.timer` | `certbot certificates` |
| التحديثات الأمنية | ✅ unattended-upgrades | `/var/log/unattended-upgrades/` |
| ثغرات مكتبات الخادم | ✅ `npm audit`: 0 (2026-11-07، بعد تصليح 3 في أدوات التطوير) | `npm audit` من `backend` |
| ثغرات مكتبات التطبيق | ⚠️ المكتبات قديمة (Flutter 3.24.3)، ومفيش أداة فحص | `flutter pub outdated` |
| فحص الأسرار في الريبو | ⚠️ يدوي (`git grep` للأنماط المعروفة). مقترح: Secret scanning في GitHub | — |
| Dependabot | ⚠️ مقترح (`SERVER_TOOLS.md` البند 5) | — |
| مراجعة الدخول | `last` و`journalctl -u ssh` على السيرفرين | — |

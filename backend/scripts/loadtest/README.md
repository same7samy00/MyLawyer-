# اختبار الحمل على نسخة معزولة

بيعمل نسخة من الخادم على نفس السيرفر: قاعدة بيانات فاضية لوحدها (`mylawyer_loadtest`)، ومنفذ 4100، ومن غير إشعارات ولا إيميل ولا حدود طلبات. وبيضغط عليها من السيرفر نفسه، عشان النت ما يبقاش هو الحد. **الإنتاج وبياناته ما بيتلمسوش.**

```bash
scp -F D:/KAREM/.access/ssh_config backend/scripts/loadtest/* mylawyer-vps:/tmp/lt/
```
```bash
ssh -F D:/KAREM/.access/ssh_config mylawyer-vps 'cd /tmp/lt && sed -i "s/\r$//" *.sh && bash setup.sh && sudo -u postgres psql -q -d mylawyer_loadtest -f seed.sql && sudo -u postgres psql -q -d mylawyer_loadtest -f seed-more.sql && npm init -y >/dev/null && npm i autocannon@7.15.0 --silent'
```
```bash
ssh -F D:/KAREM/.access/ssh_config mylawyer-vps 'cd /tmp/lt && ulimit -n 65535 && DUR=15 node bench.mjs all'
```
```bash
ssh -F D:/KAREM/.access/ssh_config mylawyer-vps 'bash /tmp/lt/cleanup.sh'
```

- مسار واحد بس: `node bench.mjs nearby50` (الأسماء في `scenarios` جوه `bench.mjs`).
- المراحل: `RAMP=100,300,600,1000`، وعدد الطلبات `REQUESTS=5000`، والخطوط اللايف `LINES=10000`.
- أداة الضغط بتاخد من نفس معالجات السيرفر، فالأرقام اللي بتطلع هي الحد الأدنى.
- النتايج بتتحفظ في `/tmp/lt/results.json`، وآخر نتايج متسجلة في `docs/engineering/PERFORMANCE.md` القسم 1.2.
- **شغّل `cleanup.sh` دايمًا في الآخر.**

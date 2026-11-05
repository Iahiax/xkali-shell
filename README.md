# xkali-shell

External Auto-Reviver for segfault.net (Kali-based).

## ما تم تطبيقه في هذه النسخة

- **إلغاء الموقت بالكامل** – لا يوجد sleep 2 / sleep 61 / Enter إضافي.
- **اقتراح 4** – نسخ احتياطي خفيف مع استثناءات (`node_modules`, `.git`, `__pycache__`...) + تدوير آخر 7 نسخ.
- **اقتراح 5** – دعم Node + Python عبر ملف `config/bots.yaml` (تشغيل عدة بوتات + تخطي المفقود).
- **اقتراح 7** – GitHub Actions مع `workflow_dispatch` (normal / force-restart / healthcheck-only) + concurrency.
- **اقتراح 8** – هيكل جديد: `bots.yaml` + `healthcheck.sh` + `notify.sh`.

## الملفات المهمة

| الملف | الوظيفة |
|------|---------|
| `config/secrets.env` | ضع فيه الـ SECRET (محلي فقط) |
| `config/bots.yaml` | قائمة البوتات التي تعمل |
| `scripts/connect-and-revive.sh` | اتصال بدون مؤقت |
| `scripts/start-services.sh` | يقرأ bots.yaml ويشغّل البوتات |
| `scripts/backup-and-push.sh` | نسخ احتياطي مع استثناءات |
| `scripts/healthcheck.sh` | فحص حالة + heartbeat |
| `scripts/notify.sh` | إشعارات (Telegram / Discord / لوج) |

## طريقة الاستخدام السريعة

1. ضع الـ SECRET في `config/secrets.env` (موجود مسبقاً).
2. عدّل `config/bots.yaml` حسب بوتاتك.
3. ضع كود البوتات في `bots/node-bot/` و `bots/python-bot/`.
4. شغّل محلياً:
   ```bash
   bash scripts/connect-and-revive.sh
   ```
5. أو استخدم GitHub Actions يدوياً (Modes: normal / force-restart / healthcheck-only).

## ملاحظات

- `config/secrets.env` موجود في `.gitignore` ولن يُرفع.
- الجلسة على segfault هي Kali، بينما الـ CI runner يبقى Ubuntu (طبيعي).

# 🚨 إصلاح عاجل - DocsGPT

## المشاكل الحالية

من الصور التي أرسلتها، المشاكل هي:

1. ❌ **502 Bad Gateway** - الـ Backend لا يستجيب
2. ❌ **الواجهة الأمامية قديمة** - لا تحتوي على صفحات التسجيل والاشتراكات الجديدة
3. ❌ **PM2 يعرض رقم منفذ خاطئ** - يظهر `:450/api` بدلاً من `:7091/api`

---

## ✅ الحل السريع (على السيرفر)

### الخطوة 1: سحب آخر التحديثات

```bash
cd /root/DocsGPT/DocsGPT
git pull origin main
```

### الخطوة 2: تشغيل سكريبت الإصلاح العاجل

```bash
bash URGENT_FIX.sh
```

**هذا السكريبت سيقوم بـ:**
- ✅ إيقاف جميع الخدمات القديمة
- ✅ تحديث ملفات البيئة (.env)
- ✅ بناء الـ Backend من جديد في Docker
- ✅ بدء MongoDB و Redis
- ✅ تهيئة قاعدة البيانات
- ✅ بدء Backend و Celery
- ✅ بناء Frontend من جديد مع المكتبات الصحيحة
- ✅ بدء Frontend مع PM2

**المدة المتوقعة:** 5-10 دقائق

---

## 🔧 إصلاح Nginx (إذا احتجت)

```bash
bash fix_nginx.sh
```

هذا سيعيد إعداد Nginx بشكل صحيح لتوجيه:
- `/` → Frontend على المنفذ `5173`
- `/api` → Backend على المنفذ `7091`

---

## 🧪 التحقق من نجاح التثبيت

### 1. فحص حالة الخدمات

```bash
# Docker containers
docker compose ps

# يجب أن ترى:
# docsgpt-mongo     Up      27017/tcp
# docsgpt-redis     Up      6379/tcp
# docsgpt-backend   Up      7091/tcp
# docsgpt-celery    Up
```

```bash
# PM2 processes
pm2 list

# يجب أن ترى:
# frontend  │ online
```

### 2. اختبار Backend API

```bash
curl http://localhost:7091/api/subscription/plans
```

**يجب أن ترى JSON يحتوي على:**
```json
{
  "plans": [
    {"name": "Free", "price": 0, ...},
    {"name": "Pro", "price": 15, ...},
    {"name": "Enterprise", "price": 30, ...}
  ]
}
```

### 3. فحص الواجهة الأمامية

افتح المتصفح: `http://78.31.67.155`

**يجب أن ترى:**
- ✅ الصفحة الرئيسية
- ✅ زر "تسجيل الدخول" أو "Login"
- ✅ رابط للتسجيل "Register"

**جرّب:**
- اذهب إلى: `http://78.31.67.155/register`
- يجب أن ترى نموذج التسجيل

---

## 🔑 تحديث مفاتيح Stripe (مهم!)

بعد نجاح التثبيت:

### 1. Backend

```bash
nano /root/DocsGPT/DocsGPT/.env
```

عدّل هذه الأسطر:
```env
STRIPE_SECRET_KEY=sk_test_YOUR_REAL_KEY_HERE
STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_REAL_KEY_HERE
STRIPE_WEBHOOK_SECRET=whsec_YOUR_REAL_SECRET_HERE
```

### 2. Frontend

```bash
nano /root/DocsGPT/DocsGPT/frontend/.env
```

عدّل هذا السطر:
```env
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_REAL_KEY_HERE
```

### 3. إعادة تشغيل الخدمات

```bash
cd /root/DocsGPT/DocsGPT
docker compose restart backend
pm2 restart frontend
```

---

## 🐛 إذا واجهت مشاكل

### عرض سجلات Backend

```bash
docker compose logs -f backend
```

ابحث عن أخطاء مثل:
- Connection errors
- Import errors
- Port binding errors

### عرض سجلات Frontend

```bash
pm2 logs frontend
```

### عرض سجلات Nginx

```bash
tail -f /var/log/nginx/error.log
```

### إعادة التشغيل الكاملة

إذا لم يعمل شيء:

```bash
cd /root/DocsGPT/DocsGPT

# إيقاف كل شيء
docker compose down
pm2 delete all

# بدء من جديد
docker compose up -d mongodb redis
sleep 15
docker compose up -d backend celery-worker
sleep 10
pm2 start frontend
```

---

## 📱 اختبار التطبيق كاملاً

### 1. إنشاء حساب جديد

```bash
curl -X POST http://localhost:7091/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#",
    "name": "Test User"
  }'
```

### 2. تسجيل الدخول

```bash
curl -X POST http://localhost:7091/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#"
  }'
```

### 3. في المتصفح

1. افتح: `http://78.31.67.155/register`
2. أنشئ حساب
3. سجل دخول
4. اذهب إلى: `/subscription`
5. يجب أن ترى خطط الاشتراك (Free, Pro, Enterprise)

---

## ✅ معايير النجاح

بعد تشغيل `URGENT_FIX.sh`، يجب أن ترى:

```
✅ تم الإصلاح! / Fixed!

Services Status:

docsgpt-mongo     Up 2 minutes     27017/tcp
docsgpt-redis     Up 2 minutes     6379/tcp  
docsgpt-backend   Up 1 minute      7091/tcp
docsgpt-celery    Up 1 minute

┌─────┬──────────┬─────────┬───────┐
│ id  │ name     │ status  │ cpu   │
├─────┼──────────┼─────────┼───────┤
│ 0   │ frontend │ online  │ 0%    │
└─────┴──────────┴─────────┴───────┘

Access Application:
  Frontend: http://78.31.67.155
  Backend: http://78.31.67.155/api
```

---

## 🆘 ما الذي تم إصلاحه؟

### المشكلة 1: 502 Bad Gateway
**السبب:** Backend لم يكن يعمل بشكل صحيح
**الحل:** 
- إعادة بناء Backend في Docker
- إصلاح متغيرات البيئة
- التأكد من بدء MongoDB و Redis أولاً

### المشكلة 2: الواجهة الأمامية القديمة
**السبب:** Frontend لم يُبنَ بشكل صحيح مع المكونات الجديدة
**الحل:**
- حذف `node_modules` القديمة
- إعادة تثبيت المكتبات مع `--legacy-peer-deps`
- إعادة بناء Frontend

### المشكلة 3: المنفذ الخاطئ في PM2
**السبب:** إعدادات Nginx غير صحيحة
**الحل:**
- تحديث إعدادات Nginx
- توجيه `/api` إلى `localhost:7091`

---

## 📞 مصادر إضافية

- **الوثائق الكاملة:** `/root/DocsGPT/DocsGPT/DEPLOYMENT_READY.md`
- **دليل التثبيت اليدوي:** `/root/DocsGPT/DocsGPT/MANUAL_INSTALL.md`
- **سكريبت الإصلاح:** `/root/DocsGPT/DocsGPT/URGENT_FIX.sh`

---

## 🎯 الخطوة التالية

**على السيرفر الآن، نفذ:**

```bash
cd /root/DocsGPT/DocsGPT
git pull origin main
bash URGENT_FIX.sh
```

**انتظر 5-10 دقائق ثم افتح:** `http://78.31.67.155`

**يجب أن ترى التطبيق يعمل مع صفحات التسجيل والاشتراكات!** 🚀

---

*آخر تحديث: 2025-11-26*  
*GitHub: https://github.com/HosamN-ALI/DocsGPT*

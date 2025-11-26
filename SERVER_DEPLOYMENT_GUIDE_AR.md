# 🚀 دليل تثبيت نظام الاشتراكات على السيرفر

## معلومات السيرفر
- **IP Address**: `78.31.67.155`
- **User**: `root`
- **المجلد**: `/root/docgpt`

---

## 📋 المتطلبات الأساسية

### 1. الاتصال بالسيرفر
```bash
# استخدم SSH key المرفوع
chmod 600 /home/user/uploaded_files/root
ssh -i /home/user/uploaded_files/root root@78.31.67.155
```

### 2. التحقق من المتطلبات المثبتة
```bash
# التحقق من Docker
docker --version

# التحقق من Docker Compose
docker-compose --version

# التحقق من Git
git --version

# التحقق من Python
python3 --version

# التحقق من Node.js
node --version
npm --version
```

---

## 🔧 التثبيت خطوة بخطوة

### الخطوة 1: تحديث النظام والحزم الأساسية

```bash
# الاتصال بالسيرفر
ssh -i /home/user/uploaded_files/root root@78.31.67.155

# تحديث النظام
apt update && apt upgrade -y

# تثبيت الأدوات الأساسية
apt install -y git curl wget vim nano software-properties-common
```

### الخطوة 2: تثبيت Docker و Docker Compose

```bash
# إزالة إصدارات Docker القديمة إن وجدت
apt remove -y docker docker-engine docker.io containerd runc

# إضافة مستودع Docker الرسمي
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# تثبيت Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# تفعيل Docker
systemctl enable docker
systemctl start docker

# التحقق من التثبيت
docker --version
docker compose version
```

### الخطوة 3: تثبيت Python 3 و pip

```bash
# تثبيت Python 3
apt install -y python3 python3-pip python3-venv

# التحقق من التثبيت
python3 --version
pip3 --version
```

### الخطوة 4: تثبيت Node.js و npm

```bash
# إضافة مستودع Node.js (نسخة 22)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

# تثبيت Node.js
apt install -y nodejs

# التحقق من التثبيت
node --version
npm --version
```

### الخطوة 5: استنساخ المشروع من GitHub

```bash
# الانتقال إلى مجلد root
cd /root

# إزالة المجلد القديم إن وجد
rm -rf docgpt

# استنساخ المشروع
git clone https://github.com/HosamN-ALI/DocsGPT.git docgpt

# الانتقال إلى مجلد المشروع
cd /root/docgpt

# التحقق من الفرع
git branch
git log --oneline -5
```

### الخطوة 6: إعداد ملفات البيئة (Environment Variables)

```bash
cd /root/docgpt

# إنشاء ملف .env للـ Backend
cat > .env << 'EOF'
# MongoDB Configuration
MONGO_URI=mongodb://mongodb:27017/
MONGO_DB_NAME=docsgpt

# Authentication
AUTH_TYPE=session_jwt
JWT_SECRET_KEY=your-super-secret-key-change-this-in-production-12345

# Stripe Configuration (راجع .env.subscription.example للمفاتيح)
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Stripe Product IDs
FREE_PRODUCT_ID=prod_free
FREE_PRICE_ID=price_free
PRO_PRODUCT_ID=prod_TSey5KafEFEsW9
PRO_PRICE_ID=price_1SVje7QZf6X1AyY5KoKCiHea
ENTERPRISE_PRODUCT_ID=prod_TSeyNNEx9WnH11
ENTERPRISE_PRICE_ID=price_1SVje8QZf6X1AyY5aQpJxo0A

# Application Settings
COMPRESSION_MODEL_OVERRIDE=gpt-4o-mini
COMPRESSION_PROMPT_VERSION=v1.0
COMPRESSION_MAX_HISTORY_POINTS=3

# API Keys (أضف مفاتيح الـ API الخاصة بك)
API_KEY=your_api_key_here
OPENAI_API_KEY=your_openai_key_here
EOF

# إنشاء ملف .env للـ Frontend
cat > frontend/.env << 'EOF'
# Stripe
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here

# API Base URL (غير IP إلى عنوان السيرفر)
VITE_API_BASE_URL=http://78.31.67.155:7091
EOF

echo "✅ تم إنشاء ملفات البيئة"
```

### الخطوة 7: تثبيت مكتبات Python

```bash
cd /root/docgpt

# تثبيت المكتبات
pip3 install -r application/requirements.txt

echo "✅ تم تثبيت مكتبات Python"
```

### الخطوة 8: تهيئة قاعدة البيانات

```bash
cd /root/docgpt

# بدء MongoDB فقط
docker compose up -d mongodb

# انتظر 10 ثواني حتى يبدأ MongoDB
sleep 10

# إنشاء الـ indexes
python3 application/init_db_indexes.py

echo "✅ تم تهيئة قاعدة البيانات"
```

### الخطوة 9: بناء وتشغيل الـ Backend

```bash
cd /root/docgpt

# بناء وتشغيل جميع الخدمات
docker compose up -d

# التحقق من حالة الخدمات
docker compose ps

# عرض السجلات
docker compose logs -f
```

### الخطوة 10: بناء وتشغيل الـ Frontend

```bash
cd /root/docgpt/frontend

# تثبيت المكتبات
npm install

# بناء المشروع للإنتاج
npm run build

# تشغيل Frontend (في الخلفية)
npm run preview -- --host 0.0.0.0 --port 5173 &

# أو استخدم serve
npm install -g serve
serve -s dist -l 5173 &
```

### الخطوة 11: إعداد Nginx (اختياري - للإنتاج)

```bash
# تثبيت Nginx
apt install -y nginx

# إنشاء ملف إعداد
cat > /etc/nginx/sites-available/docsgpt << 'EOF'
server {
    listen 80;
    server_name 78.31.67.155;

    # Frontend
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:7091;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# تفعيل الإعداد
ln -s /etc/nginx/sites-available/docsgpt /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# اختبار الإعداد
nginx -t

# إعادة تشغيل Nginx
systemctl restart nginx
systemctl enable nginx
```

---

## 🔍 التحقق من التثبيت

### 1. التحقق من الخدمات

```bash
# التحقق من Docker containers
docker ps

# يجب أن ترى:
# - docsgpt-backend
# - docsgpt-mongodb
# - docsgpt-redis
# - docsgpt-worker

# التحقق من Backend
curl http://localhost:7091/api/config

# التحقق من Frontend
curl http://localhost:5173
```

### 2. التحقق من الـ API Endpoints

```bash
# اختبار تسجيل المستخدم
curl -X POST http://localhost:7091/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User"
  }'

# اختبار تسجيل الدخول
curl -X POST http://localhost:7091/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# اختبار خطط الاشتراك
curl http://localhost:7091/api/subscription/plans
```

### 3. فتح المنافذ في الـ Firewall

```bash
# السماح بمنفذ 80 (HTTP)
ufw allow 80/tcp

# السماح بمنفذ 443 (HTTPS)
ufw allow 443/tcp

# السماح بمنفذ 22 (SSH)
ufw allow 22/tcp

# تفعيل Firewall
ufw --force enable

# عرض الحالة
ufw status
```

---

## 🌐 الوصول إلى التطبيق

بعد التثبيت، يمكنك الوصول إلى:

### بدون Nginx:
- **Frontend**: http://78.31.67.155:5173
- **Backend API**: http://78.31.67.155:7091

### مع Nginx:
- **التطبيق الكامل**: http://78.31.67.155

---

## 🧪 اختبار النظام

### 1. اختبار التسجيل والدخول
1. افتح http://78.31.67.155:5173/register
2. سجل مستخدم جديد
3. سجل الدخول

### 2. اختبار خطط الاشتراك
1. اذهب إلى http://78.31.67.155:5173/subscription
2. اعرض الخطط الثلاث (Free, Pro, Enterprise)

### 3. اختبار Stripe Checkout
1. اضغط على "Subscribe" لخطة Pro
2. استخدم بطاقة الاختبار: `4242 4242 4242 4242`

---

## 📊 مراقبة النظام

### عرض السجلات

```bash
# Backend logs
docker compose logs -f backend

# MongoDB logs
docker compose logs -f mongodb

# جميع السجلات
docker compose logs -f

# آخر 100 سطر
docker compose logs --tail=100

# Frontend logs (إذا كان يعمل في الخلفية)
pm2 logs frontend
```

### التحقق من استخدام الموارد

```bash
# استخدام Docker
docker stats

# استخدام النظام
htop
# أو
top

# مساحة القرص
df -h

# الذاكرة
free -h
```

---

## 🔧 إدارة الخدمات

### إعادة تشغيل الخدمات

```bash
# إعادة تشغيل جميع الخدمات
docker compose restart

# إعادة تشغيل خدمة معينة
docker compose restart backend
docker compose restart mongodb

# إيقاف الخدمات
docker compose stop

# بدء الخدمات
docker compose start

# إعادة بناء وتشغيل
docker compose up -d --build
```

### تحديث الكود

```bash
cd /root/docgpt

# جلب آخر التحديثات
git pull origin main

# إعادة بناء Backend
docker compose up -d --build backend

# إعادة بناء Frontend
cd frontend
npm install
npm run build
```

---

## 🔐 إعداد SSL/HTTPS (للإنتاج)

### استخدام Let's Encrypt

```bash
# تثبيت Certbot
apt install -y certbot python3-certbot-nginx

# الحصول على شهادة SSL (استبدل example.com بدومينك)
certbot --nginx -d yourdomain.com -d www.yourdomain.com

# تجديد تلقائي
certbot renew --dry-run

# إضافة cron job للتجديد التلقائي
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
```

---

## 🐛 حل المشاكل الشائعة

### المشكلة: MongoDB لا يعمل

```bash
# التحقق من حالة MongoDB
docker compose ps mongodb

# إعادة تشغيل MongoDB
docker compose restart mongodb

# عرض سجلات MongoDB
docker compose logs mongodb

# حذف وإعادة إنشاء MongoDB
docker compose down mongodb
docker volume rm docsgpt_mongodb_data
docker compose up -d mongodb
```

### المشكلة: Backend لا يستجيب

```bash
# التحقق من السجلات
docker compose logs backend

# إعادة تشغيل Backend
docker compose restart backend

# إعادة بناء Backend
docker compose up -d --build backend
```

### المشكلة: Frontend لا يعمل

```bash
# التحقق من العملية
ps aux | grep node

# قتل العملية
pkill -f "vite preview"

# إعادة التشغيل
cd /root/docgpt/frontend
npm run preview -- --host 0.0.0.0 --port 5173 &
```

### المشكلة: CORS errors

تحقق من إعدادات CORS في `application/app.py`:
```python
CORS(app, origins=["http://78.31.67.155:5173", "http://78.31.67.155"])
```

---

## 📝 ملاحظات مهمة

### 1. الأمان
- ⚠️ **غير JWT_SECRET_KEY** في ملف `.env`
- ⚠️ استخدم مفاتيح Stripe الحقيقية للإنتاج
- ⚠️ فعّل HTTPS في الإنتاج
- ⚠️ قم بتقييد الوصول إلى MongoDB

### 2. النسخ الاحتياطي
```bash
# نسخ احتياطي لقاعدة البيانات
docker exec -it docsgpt-mongodb mongodump --out /backup

# نسخ الملفات
docker cp docsgpt-mongodb:/backup ./mongodb-backup
```

### 3. الأداء
- استخدم Nginx لتحسين الأداء
- فعّل caching للـ static files
- استخدم CDN للـ assets

---

## 🚀 تشغيل تلقائي عند بدء السيرفر

### إعداد systemd service

```bash
# إنشاء service للـ Backend
cat > /etc/systemd/system/docsgpt-backend.service << 'EOF'
[Unit]
Description=DocsGPT Backend
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/root/docgpt
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# تفعيل الخدمة
systemctl enable docsgpt-backend
systemctl start docsgpt-backend

# التحقق من الحالة
systemctl status docsgpt-backend
```

---

## ✅ قائمة التحقق النهائية

قبل نقل الموقع للإنتاج:

- [ ] MongoDB يعمل بشكل صحيح
- [ ] Backend API يستجيب على جميع endpoints
- [ ] Frontend يعمل ويتصل بالـ Backend
- [ ] يمكن تسجيل مستخدم جديد
- [ ] يمكن تسجيل الدخول
- [ ] خطط الاشتراك تظهر بشكل صحيح
- [ ] Stripe Checkout يعمل
- [ ] تم تغيير جميع المفاتيح السرية
- [ ] Firewall مُفعّل ومُعد بشكل صحيح
- [ ] Nginx مُثبت ومُعد (اختياري)
- [ ] SSL/HTTPS مُفعّل (للإنتاج)
- [ ] النسخ الاحتياطي مُجدول
- [ ] المراقبة مُفعّلة

---

## 📞 الدعم

إذا واجهت أي مشاكل:
1. راجع ملف `QUICK_START_GUIDE.md`
2. راجع السجلات (logs)
3. تحقق من إعدادات Firewall
4. تأكد من أن جميع الخدمات تعمل

---

**تم إعداد الدليل**: 26 نوفمبر 2025  
**الحالة**: ✅ جاهز للتثبيت على السيرفر

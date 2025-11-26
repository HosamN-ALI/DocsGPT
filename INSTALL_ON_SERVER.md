# 🚀 تثبيت DocsGPT على السيرفر - دليل سريع

## معلومات السيرفر
- **IP**: 78.31.67.155
- **User**: root
- **المسار**: /root/docgpt

---

## ⚡ التثبيت السريع (خطوة واحدة)

### الطريقة 1: التثبيت التلقائي الكامل

```bash
# 1. الاتصال بالسيرفر
ssh -i /home/user/uploaded_files/root root@78.31.67.155

# 2. تحميل وتشغيل سكريبت التثبيت
curl -o install.sh https://raw.githubusercontent.com/HosamN-ALI/DocsGPT/main/install_server.sh
chmod +x install.sh
./install.sh
```

أو إذا كان لديك المشروع محلياً:

```bash
# 1. نسخ السكريبت إلى السيرفر
scp -i /home/user/uploaded_files/root install_server.sh root@78.31.67.155:/root/

# 2. الاتصال بالسيرفر
ssh -i /home/user/uploaded_files/root root@78.31.67.155

# 3. تشغيل السكريبت
cd /root
chmod +x install_server.sh
./install_server.sh
```

**⏱️ الوقت المتوقع**: 10-15 دقيقة

---

## 📋 ما الذي سيقوم به السكريبت؟

السكريبت سيقوم تلقائياً بـ:

1. ✅ تحديث النظام
2. ✅ تثبيت Docker و Docker Compose
3. ✅ تثبيت Python 3 و pip
4. ✅ تثبيت Node.js 22
5. ✅ استنساخ المشروع من GitHub
6. ✅ إنشاء ملفات .env
7. ✅ تثبيت مكتبات Python
8. ✅ بدء MongoDB وتهيئة قاعدة البيانات
9. ✅ بدء جميع خدمات Docker
10. ✅ بناء وتشغيل Frontend
11. ✅ تثبيت وإعداد Nginx
12. ✅ إعداد systemd للتشغيل التلقائي
13. ✅ إعداد Firewall
14. ✅ بدء Frontend باستخدام PM2

---

## 🌐 الوصول إلى التطبيق

بعد اكتمال التثبيت:

### عبر Nginx (الطريقة الموصى بها):
- **التطبيق**: http://78.31.67.155
- **API**: http://78.31.67.155/api

### المنافذ المباشرة:
- **Frontend**: http://78.31.67.155:5173
- **Backend**: http://78.31.67.155:7091

---

## 🧪 اختبار التثبيت

### 1. اختبار Backend API

```bash
# اختبار خطط الاشتراك
curl http://78.31.67.155:7091/api/subscription/plans

# اختبار التسجيل
curl -X POST http://78.31.67.155:7091/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User"
  }'
```

### 2. اختبار Frontend
افتح المتصفح على: http://78.31.67.155

### 3. اختبار تسجيل مستخدم جديد
1. اذهب إلى http://78.31.67.155/register
2. املأ النموذج
3. سجل الدخول

---

## 🔧 إدارة الخدمات

### عرض حالة الخدمات

```bash
# خدمات Docker
docker compose ps

# Frontend (PM2)
pm2 list

# Nginx
systemctl status nginx
```

### عرض السجلات

```bash
# Backend logs
docker compose logs -f backend

# MongoDB logs
docker compose logs -f mongodb

# Frontend logs
pm2 logs frontend

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### إعادة تشغيل الخدمات

```bash
# جميع خدمات Docker
docker compose restart

# Backend فقط
docker compose restart backend

# Frontend
pm2 restart frontend

# Nginx
systemctl restart nginx
```

### إيقاف الخدمات

```bash
# Docker services
docker compose stop

# Frontend
pm2 stop frontend

# Nginx
systemctl stop nginx
```

---

## 🔄 تحديث التطبيق

عندما تريد تحديث الكود:

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
pm2 restart frontend
```

---

## 🔐 إعدادات الأمان المهمة

### 1. تغيير المفاتيح السرية

```bash
# تعديل ملف .env
nano /root/docgpt/.env

# غيّر هذه القيم:
# JWT_SECRET_KEY=أنشئ-مفتاح-عشوائي-قوي-جداً
# STRIPE_SECRET_KEY=مفتاح-stripe-الحقيقي
# STRIPE_WEBHOOK_SECRET=سر-webhook-من-stripe
```

### 2. إعداد SSL/HTTPS (للإنتاج)

```bash
# تثبيت Certbot
apt install -y certbot python3-certbot-nginx

# الحصول على شهادة (استبدل yourdomain.com بدومينك)
certbot --nginx -d yourdomain.com

# تجديد تلقائي
certbot renew --dry-run
```

### 3. تشديد الأمان

```bash
# تحديث النظام بانتظام
apt update && apt upgrade -y

# تفعيل automatic security updates
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# قيود على SSH (اختياري)
# تعديل /etc/ssh/sshd_config
# PermitRootLogin no
# PasswordAuthentication no
```

---

## 💾 النسخ الاحتياطي

### نسخ احتياطي يدوي

```bash
# نسخ احتياطي لقاعدة البيانات
docker exec docsgpt-mongodb mongodump --out /backup

# نسخ الملفات
docker cp docsgpt-mongodb:/backup ./mongodb-backup-$(date +%Y%m%d).tar.gz

# نسخ احتياطي لملفات .env
cp /root/docgpt/.env ./env-backup-$(date +%Y%m%d)
cp /root/docgpt/frontend/.env ./frontend-env-backup-$(date +%Y%m%d)
```

### نسخ احتياطي تلقائي

```bash
# إنشاء سكريبت للنسخ الاحتياطي
cat > /root/backup_docsgpt.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

# MongoDB backup
docker exec docsgpt-mongodb mongodump --out /backup
docker cp docsgpt-mongodb:/backup $BACKUP_DIR/mongodb-$DATE

# Compress
cd $BACKUP_DIR
tar -czf mongodb-$DATE.tar.gz mongodb-$DATE
rm -rf mongodb-$DATE

# Keep only last 7 backups
ls -t mongodb-*.tar.gz | tail -n +8 | xargs rm -f
EOF

chmod +x /root/backup_docsgpt.sh

# جدولة نسخ احتياطي يومي (2:00 صباحاً)
(crontab -l 2>/dev/null; echo "0 2 * * * /root/backup_docsgpt.sh") | crontab -
```

---

## 🐛 حل المشاكل

### المشكلة: التطبيق لا يعمل

```bash
# تحقق من الخدمات
docker compose ps
pm2 list
systemctl status nginx

# تحقق من السجلات
docker compose logs --tail=50
pm2 logs frontend --lines 50
tail -50 /var/log/nginx/error.log
```

### المشكلة: MongoDB لا يبدأ

```bash
# إعادة تشغيل MongoDB
docker compose restart mongodb

# إذا لم ينجح، أعد إنشاءه
docker compose down mongodb
docker volume rm docsgpt_mongodb_data
docker compose up -d mongodb
python3 /root/docgpt/application/init_db_indexes.py
```

### المشكلة: Frontend لا يظهر

```bash
# تحقق من PM2
pm2 list
pm2 logs frontend

# إعادة تشغيل
pm2 restart frontend

# إعادة بناء
cd /root/docgpt/frontend
npm run build
pm2 restart frontend
```

### المشكلة: Nginx error 502

```bash
# تحقق من أن Backend و Frontend يعملان
curl http://localhost:7091/api/config
curl http://localhost:5173

# تحقق من إعدادات Nginx
nginx -t

# أعد تشغيل Nginx
systemctl restart nginx
```

---

## 📊 المراقبة والصيانة

### مراقبة استخدام الموارد

```bash
# استخدام CPU والذاكرة
htop

# استخدام Docker
docker stats

# مساحة القرص
df -h

# الذاكرة
free -h
```

### تنظيف النظام

```bash
# حذف images غير المستخدمة
docker system prune -a

# حذف volumes غير المستخدمة
docker volume prune

# حذف npm cache
npm cache clean --force

# حذف apt cache
apt clean
apt autoremove -y
```

---

## 📞 الدعم والمساعدة

إذا واجهت مشاكل:

1. **راجع السجلات** (logs)
2. **تحقق من حالة الخدمات**
3. **راجع الدليل الشامل**: `SERVER_DEPLOYMENT_GUIDE_AR.md`
4. **اختبر الـ API endpoints** يدوياً

---

## ✅ قائمة التحقق بعد التثبيت

- [ ] جميع خدمات Docker تعمل
- [ ] Frontend يفتح في المتصفح
- [ ] Backend API يستجيب
- [ ] يمكن تسجيل مستخدم جديد
- [ ] يمكن تسجيل الدخول
- [ ] خطط الاشتراك تظهر
- [ ] Nginx يعمل بشكل صحيح
- [ ] Firewall مُفعّل
- [ ] تم تغيير JWT_SECRET_KEY
- [ ] تم إعداد النسخ الاحتياطي

---

## 🎯 الخطوات التالية

بعد التثبيت الناجح:

1. **اختبر جميع الميزات**
2. **غيّر جميع المفاتيح السرية**
3. **أعد إعداد Stripe للإنتاج**
4. **فعّل SSL/HTTPS**
5. **إعداد النسخ الاحتياطي التلقائي**
6. **إعداد المراقبة**
7. **اختبار الأداء**

---

**تاريخ الإنشاء**: 26 نوفمبر 2025  
**الحالة**: ✅ جاهز للاستخدام

🎉 **مبروك! التطبيق الآن يعمل على السيرفر!**

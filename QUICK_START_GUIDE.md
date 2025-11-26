# 🚀 DocsGPT Subscription System - Quick Start Guide

## Overview
This guide will help you quickly set up and test the newly implemented subscription system for DocsGPT.

---

## 🎯 What's Been Implemented

### Backend (Python/Flask)
- ✅ User authentication (email/password + JWT)
- ✅ 3 subscription tiers (Free, Pro, Enterprise)
- ✅ Stripe payment integration
- ✅ Token usage tracking with 5% markup
- ✅ Request quota enforcement
- ✅ 13 REST API endpoints

### Frontend (React/TypeScript)
- ✅ Login & Registration forms
- ✅ Pricing plans page with Stripe Checkout
- ✅ Usage dashboard with analytics
- ✅ Account settings page
- ✅ Protected routes
- ✅ Dark mode support

---

## ⚡ Quick Setup (5 Minutes)

### Step 1: Backend Setup

```bash
# Navigate to project
cd /home/user/webapp

# Install Python dependencies
pip install -r application/requirements.txt

# Initialize database indexes
python application/init_db_indexes.py

# Start services with Docker
docker-compose up -d

# OR run Flask directly
python application/app.py
```

**Backend will be running at**: `http://localhost:7091`

### Step 2: Frontend Setup

```bash
# Navigate to frontend
cd /home/user/webapp/frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

**Frontend will be running at**: `http://localhost:5173`

### Step 3: Configure Environment Variables

#### Backend `.env`
Create `/home/user/webapp/.env`:
```env
# Required
MONGO_URI=mongodb://localhost:27017/
MONGO_DB_NAME=docsgpt
AUTH_TYPE=session_jwt
JWT_SECRET_KEY=your-super-secret-key-change-this

# Stripe Test Keys (Get from .env.subscription.example)
STRIPE_SECRET_KEY=sk_test_YOUR_STRIPE_SECRET_KEY
STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_STRIPE_PUBLISHABLE_KEY
```

**Note**: See `.env.subscription.example` for the actual test keys.

#### Frontend `.env`
Create `/home/user/webapp/frontend/.env`:
```env
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_STRIPE_PUBLISHABLE_KEY
VITE_API_BASE_URL=http://localhost:7091
```

**Note**: Use the same publishable key from backend `.env`.

---

## 🧪 Testing the System

### Test 1: User Registration
1. Go to `http://localhost:5173/register`
2. Fill in:
   - **Email**: `test@example.com`
   - **Password**: `password123` (min 8 chars)
   - **Name**: `Test User`
3. Check "I agree to Terms of Service"
4. Click "Sign up"
5. ✅ You should be logged in automatically

### Test 2: Login
1. Go to `http://localhost:5173/login`
2. Enter your credentials
3. Click "Sign in"
4. ✅ You should be redirected to the dashboard

### Test 3: View Subscription Plans
1. Go to `http://localhost:5173/subscription`
2. You should see 3 plans:
   - **Free**: $0/mo, 1,000 requests
   - **Pro**: $15/mo, 10,000 requests
   - **Enterprise**: $30/mo, 100,000 requests
3. Your current plan (Free) should have a "Current Plan" badge

### Test 4: Stripe Checkout (Test Mode)
1. Click "Subscribe" on Pro plan
2. You'll be redirected to Stripe Checkout
3. Use test card:
   - **Card**: `4242 4242 4242 4242`
   - **Expiry**: Any future date (e.g., `12/25`)
   - **CVC**: Any 3 digits (e.g., `123`)
   - **ZIP**: Any 5 digits (e.g., `12345`)
4. Click "Pay"
5. ✅ You should be redirected back and see Pro plan active

### Test 5: Usage Dashboard
1. Go to `http://localhost:5173/subscription/usage`
2. You should see:
   - Current request usage (0/10,000 for Pro)
   - Token usage by model
   - Usage charts
   - Billing period dates

### Test 6: Account Settings
1. Go to `http://localhost:5173/settings`
2. Click "Account" tab
3. You should see:
   - Your email, name, user ID
   - Current subscription plan
   - Password change form
4. Try changing password:
   - Enter current password
   - Enter new password (min 8 chars)
   - Confirm new password
   - Click "Change Password"

### Test 7: Backend API Testing
```bash
cd /home/user/webapp
python test_subscription_backend.py
```

This will test all API endpoints automatically.

---

## 📋 Subscription Plans

| Plan | Price | Requests/Month | Models | Priority |
|------|-------|----------------|--------|----------|
| **Free** | $0 | 1,000 | Basic only | Standard |
| **Pro** | $15 | 10,000 | All models | Standard |
| **Enterprise** | $30 | 100,000 | All models | Priority ✨ |

---

## 🔌 API Endpoints Reference

### Authentication
```bash
# Register
curl -X POST http://localhost:7091/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'

# Login
curl -X POST http://localhost:7091/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Get Current User
curl -X GET http://localhost:7091/api/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Subscription
```bash
# Get Plans
curl -X GET http://localhost:7091/api/subscription/plans

# Create Checkout
curl -X POST http://localhost:7091/api/subscription/create-checkout \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{"plan_id":"pro"}'

# Get Current Subscription
curl -X GET http://localhost:7091/api/subscription/current \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Get Usage Stats
curl -X GET http://localhost:7091/api/subscription/usage \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 🎨 UI Routes

| Route | Description | Protection |
|-------|-------------|------------|
| `/login` | Login page | Public |
| `/register` | Registration page | Public |
| `/` | Main dashboard | Protected |
| `/subscription` | Pricing plans | Protected |
| `/subscription/usage` | Usage dashboard | Protected |
| `/settings` | General settings | Protected |
| `/settings/account` | Account settings | Protected |

---

## 🐛 Troubleshooting

### Issue: "Module not found" error
**Solution**: Install dependencies
```bash
pip install -r application/requirements.txt
cd frontend && npm install
```

### Issue: MongoDB connection error
**Solution**: Ensure MongoDB is running
```bash
# Check if MongoDB is running
docker ps | grep mongo

# Start MongoDB
docker-compose up -d mongodb
```

### Issue: Stripe checkout not working
**Solution**: Check environment variables
1. Verify `.env` files exist
2. Check Stripe keys are correct
3. Ensure backend is running

### Issue: "CORS error" in browser
**Solution**: Check API base URL in frontend `.env`
```env
VITE_API_BASE_URL=http://localhost:7091
```

### Issue: JWT token expired
**Solution**: Logout and login again
- Token expires after 1 hour
- Refresh token expires after 7 days

---

## 📊 Monitoring

### Check Logs

#### Backend Logs
```bash
# Docker logs
docker-compose logs -f backend

# Or direct Python logs
tail -f application/logs/app.log
```

#### Frontend Logs
- Open browser console (F12)
- Check Network tab for API calls
- Check Console tab for errors

### Database Queries

```bash
# Connect to MongoDB
docker exec -it docsgpt-mongo mongosh

# Use database
use docsgpt

# Check users
db.users.find().pretty()

# Check subscriptions
db.subscription_history.find().pretty()

# Check token usage
db.token_usage.find().sort({timestamp: -1}).limit(10).pretty()

# Check request quotas
db.request_quotas.find().pretty()
```

---

## 🔐 Security Notes

### For Development
- ✅ Test Stripe keys are safe to commit (already in code)
- ✅ JWT secret should be changed for production
- ✅ Use test mode for all Stripe operations

### For Production
- 🔴 Generate new JWT secret key
- 🔴 Use production Stripe keys
- 🔴 Set up Stripe webhook endpoint
- 🔴 Enable HTTPS
- 🔴 Configure CORS properly
- 🔴 Set up environment variables securely

---

## 🚀 Next Steps After Testing

1. **Integration Testing**
   - Test full user journey
   - Test webhook handling
   - Test error scenarios

2. **UI/UX Review**
   - Check responsive design
   - Test dark mode
   - Verify loading states

3. **Performance Testing**
   - Load test with multiple users
   - Check database query performance
   - Monitor API response times

4. **Production Preparation**
   - Update Stripe keys
   - Configure webhook endpoint
   - Set up monitoring/alerts
   - Deploy to production server

---

## 📚 Documentation

- **Complete Plan**: `SUBSCRIPTION_IMPLEMENTATION_PLAN.md`
- **Backend Docs**: `BACKEND_IMPLEMENTATION_COMPLETE.md`
- **Frontend Docs**: `FRONTEND_IMPLEMENTATION_COMPLETE.md`
- **Summary**: `SUBSCRIPTION_SYSTEM_COMPLETE.md`
- **This Guide**: `QUICK_START_GUIDE.md`

---

## 🎯 Success Criteria

After following this guide, you should be able to:
- ✅ Register a new user
- ✅ Login successfully
- ✅ View subscription plans
- ✅ Complete test Stripe checkout
- ✅ View usage dashboard
- ✅ Change password
- ✅ See all API endpoints working

---

## 💡 Tips

1. **Use Incognito Mode**: Test registration/login without cookies
2. **Check Network Tab**: See all API calls in browser DevTools
3. **Use Stripe Dashboard**: View test mode transactions
4. **Check MongoDB**: Verify data is being saved
5. **Test Error Cases**: Try invalid inputs to see error handling

---

## 🆘 Getting Help

If you encounter issues:
1. Check the troubleshooting section above
2. Review error messages in logs
3. Check browser console for frontend errors
4. Verify all services are running
5. Review the detailed documentation

---

## ✅ Quick Checklist

Before testing:
- [ ] MongoDB is running
- [ ] Backend is running (port 7091)
- [ ] Frontend is running (port 5173)
- [ ] Environment variables are set
- [ ] Database indexes are initialized

After testing:
- [ ] User registration works
- [ ] Login authentication works
- [ ] Subscription plans display
- [ ] Stripe checkout completes
- [ ] Usage dashboard shows data
- [ ] Account settings functional
- [ ] All API endpoints respond

---

**Ready to test? Start with Step 1 and follow through each test case!** 🎉

**Estimated Time to Complete**: 15-20 minutes for full testing

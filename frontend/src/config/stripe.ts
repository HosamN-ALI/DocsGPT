/**
 * Stripe configuration and subscription plan definitions
 */

export const STRIPE_CONFIG = {
  publishableKey: import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || '',
};

export const SUBSCRIPTION_PLANS = {
  free: {
    id: 'free',
    name: 'Free',
    price: 0,
    requestLimit: 1000,
    features: [
      '1,000 requests per month',
      'Access to basic models',
      'Community support',
    ],
  },
  pro: {
    id: 'pro',
    name: 'Pro',
    price: 15,
    requestLimit: 10000,
    features: [
      '10,000 requests per month',
      'Access to all models',
      'Priority support',
      'Advanced analytics',
    ],
  },
  enterprise: {
    id: 'enterprise',
    name: 'Enterprise',
    price: 30,
    requestLimit: 100000,
    features: [
      '100,000 requests per month',
      'Access to all models',
      'Priority processing',
      'Dedicated support',
      'Custom integrations',
    ],
  },
};

export type SubscriptionPlanId = keyof typeof SUBSCRIPTION_PLANS;

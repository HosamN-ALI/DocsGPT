import apiClient from '../client';
import endpoints from '../endpoints';

interface CheckoutData {
  plan: string;
  success_url: string;
  cancel_url: string;
}

const subscriptionService = {
  getPlans: (token: string | null) =>
    apiClient.get(endpoints.SUBSCRIPTION.PLANS, token),

  getCurrentSubscription: (token: string | null) =>
    apiClient.get(endpoints.SUBSCRIPTION.CURRENT, token),

  createCheckout: (data: CheckoutData, token: string | null) =>
    apiClient.post(endpoints.SUBSCRIPTION.CHECKOUT, data, token),

  cancelSubscription: (token: string | null) =>
    apiClient.post(endpoints.SUBSCRIPTION.CANCEL, {}, token),

  getHistory: (token: string | null, limit?: number) =>
    apiClient.get(
      `${endpoints.SUBSCRIPTION.HISTORY}${limit ? `?limit=${limit}` : ''}`,
      token
    ),

  getUsage: (token: string | null) =>
    apiClient.get(endpoints.SUBSCRIPTION.USAGE, token),
};

export default subscriptionService;

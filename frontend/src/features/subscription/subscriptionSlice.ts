import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../../store';

interface PlanConfig {
  name: string;
  price: number;
  request_limit: number;
  features: string[];
}

interface Subscription {
  user_id: string;
  plan: string;
  plan_config: PlanConfig | null;
  status: string;
  requests_used: number;
  request_limit: number;
  current_period_start?: string;
  current_period_end?: string;
  stripe_customer_id?: string;
  stripe_subscription_id?: string;
}

interface SubscriptionState {
  current: Subscription | null;
  isLoading: boolean;
}

const initialState: SubscriptionState = {
  current: null,
  isLoading: false,
};

export const subscriptionSlice = createSlice({
  name: 'subscription',
  initialState,
  reducers: {
    setSubscription: (state, action: PayloadAction<Subscription | null>) => {
      state.current = action.payload;
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.isLoading = action.payload;
    },
    incrementUsage: (state) => {
      if (state.current) {
        state.current.requests_used += 1;
      }
    },
  },
});

export const { setSubscription, setLoading, incrementUsage } =
  subscriptionSlice.actions;

export const selectSubscription = (state: RootState) =>
  (state.subscription as SubscriptionState).current;
export const selectSubscriptionLoading = (state: RootState) =>
  (state.subscription as SubscriptionState).isLoading;

export default subscriptionSlice.reducer;

import { useState, useEffect } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import subscriptionService from '../../api/services/subscriptionService';
import { selectToken } from '../../preferences/preferenceSlice';
import { SUBSCRIPTION_PLANS } from '../../config/stripe';

interface Plan {
  id: string;
  name: string;
  price: number;
  request_limit: number;
  features: string[];
}

export default function PricingPlans() {
  const [plans, setPlans] = useState<Plan[]>([]);
  const [currentPlan, setCurrentPlan] = useState<string>('free');
  const [isLoading, setIsLoading] = useState(false);
  const token = useSelector(selectToken);
  const navigate = useNavigate();

  useEffect(() => {
    loadPlans();
    loadCurrentSubscription();
  }, []);

  const loadPlans = async () => {
    try {
      const response = await subscriptionService.getPlans(token);
      const data = await response.json();
      if (data.success) {
        setPlans(data.plans);
      }
    } catch (error) {
      console.error('Failed to load plans:', error);
    }
  };

  const loadCurrentSubscription = async () => {
    try {
      const response = await subscriptionService.getCurrentSubscription(token);
      const data = await response.json();
      if (data.success) {
        setCurrentPlan(data.subscription.plan);
      }
    } catch (error) {
      console.error('Failed to load subscription:', error);
    }
  };

  const handleUpgrade = async (planId: string) => {
    if (planId === 'free') return;

    setIsLoading(true);
    try {
      const successUrl = `${window.location.origin}/subscription/success`;
      const cancelUrl = `${window.location.origin}/subscription`;

      const response = await subscriptionService.createCheckout(
        {
          plan: planId,
          success_url: successUrl,
          cancel_url: cancelUrl,
        },
        token
      );

      const data = await response.json();
      if (data.success) {
        // Redirect to Stripe Checkout
        window.location.href = data.checkout_url;
      }
    } catch (error) {
      console.error('Failed to create checkout:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
      <div className="text-center">
        <h2 className="text-3xl font-extrabold text-gray-900 dark:text-white sm:text-4xl">
          Choose Your Plan
        </h2>
        <p className="mt-4 text-lg text-gray-600 dark:text-gray-400">
          Select the perfect plan for your needs
        </p>
      </div>

      <div className="mt-12 grid gap-8 lg:grid-cols-3">
        {Object.entries(SUBSCRIPTION_PLANS).map(([planId, planConfig]) => {
          const isCurrent = currentPlan === planId;
          const isPro = planId === 'pro' || planId === 'enterprise';

          return (
            <div
              key={planId}
              className={`flex flex-col overflow-hidden rounded-lg shadow-lg ${
                isPro
                  ? 'border-2 border-indigo-500 dark:border-indigo-400'
                  : 'border border-gray-200 dark:border-gray-700'
              }`}
            >
              <div className="bg-white px-6 py-8 dark:bg-gray-800 sm:p-10 sm:pb-6">
                <div>
                  <h3 className="inline-flex rounded-full bg-indigo-100 px-4 py-1 text-sm font-semibold uppercase tracking-wide text-indigo-600 dark:bg-indigo-900 dark:text-indigo-300">
                    {planConfig.name}
                  </h3>
                </div>
                <div className="mt-4 flex items-baseline text-6xl font-extrabold text-gray-900 dark:text-white">
                  ${planConfig.price}
                  <span className="ml-1 text-2xl font-medium text-gray-500 dark:text-gray-400">
                    /mo
                  </span>
                </div>
                <p className="mt-5 text-lg text-gray-500 dark:text-gray-400">
                  {planConfig.requestLimit.toLocaleString()} requests per month
                </p>
              </div>

              <div className="flex flex-1 flex-col justify-between space-y-6 bg-gray-50 px-6 pb-8 pt-6 dark:bg-gray-900 sm:p-10 sm:pt-6">
                <ul className="space-y-4">
                  {planConfig.features.map((feature, index) => (
                    <li key={index} className="flex items-start">
                      <div className="flex-shrink-0">
                        <svg
                          className="h-6 w-6 text-green-500"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                      </div>
                      <p className="ml-3 text-base text-gray-700 dark:text-gray-300">
                        {feature}
                      </p>
                    </li>
                  ))}
                </ul>

                <div className="rounded-md shadow">
                  <button
                    onClick={() => handleUpgrade(planId)}
                    disabled={isCurrent || isLoading || planId === 'free'}
                    className={`flex w-full items-center justify-center rounded-md border border-transparent px-5 py-3 text-base font-medium ${
                      isCurrent
                        ? 'cursor-not-allowed bg-gray-300 text-gray-500 dark:bg-gray-700 dark:text-gray-400'
                        : isPro
                        ? 'bg-indigo-600 text-white hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600'
                        : 'bg-gray-800 text-white hover:bg-gray-900 dark:bg-gray-700 dark:hover:bg-gray-600'
                    } disabled:opacity-50`}
                  >
                    {isCurrent
                      ? 'Current Plan'
                      : planId === 'free'
                      ? 'Free Plan'
                      : 'Upgrade'}
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

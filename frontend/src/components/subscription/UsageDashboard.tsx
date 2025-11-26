import { useState, useEffect } from 'react';
import { useSelector } from 'react-redux';
import subscriptionService from '../../api/services/subscriptionService';
import { selectToken } from '../../preferences/preferenceSlice';

interface Subscription {
  plan: string;
  plan_config: {
    name: string;
  };
  requests_used: number;
  request_limit: number;
  current_period_end: string;
}

interface Analytics {
  period: {
    start: string;
    end: string;
  };
  totals: {
    requests: number;
    total_tokens: number;
    total_cost: number;
  };
  by_model: {
    [key: string]: {
      requests: number;
      cost: number;
    };
  };
}

export default function UsageDashboard() {
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [usage, setUsage] = useState<Analytics | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const token = useSelector(selectToken);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [subResponse, usageResponse] = await Promise.all([
        subscriptionService.getCurrentSubscription(token),
        subscriptionService.getUsage(token),
      ]);

      const subData = await subResponse.json();
      const usageData = await usageResponse.json();

      if (subData.success) {
        setSubscription(subData.subscription);
      }
      if (usageData.success) {
        setUsage(usageData.analytics);
      }
    } catch (error) {
      console.error('Failed to load data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="text-lg text-gray-600 dark:text-gray-400">
          Loading...
        </div>
      </div>
    );
  }

  const usagePercentage = subscription
    ? (subscription.requests_used / subscription.request_limit) * 100
    : 0;

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <h2 className="mb-6 text-2xl font-bold text-gray-900 dark:text-white">
        Usage Dashboard
      </h2>

      {/* Current Plan */}
      <div className="mb-6 rounded-lg bg-white p-6 shadow dark:bg-gray-800">
        <h3 className="mb-4 text-lg font-medium text-gray-900 dark:text-white">
          Current Plan: {subscription?.plan_config?.name || 'Free'}
        </h3>

        <div className="space-y-4">
          <div>
            <div className="mb-2 flex justify-between text-sm text-gray-600 dark:text-gray-400">
              <span>Requests Used</span>
              <span>
                {subscription?.requests_used || 0} /{' '}
                {subscription?.request_limit || 0}
              </span>
            </div>
            <div className="h-2.5 w-full rounded-full bg-gray-200 dark:bg-gray-700">
              <div
                className={`h-2.5 rounded-full ${
                  usagePercentage > 90
                    ? 'bg-red-600'
                    : usagePercentage > 75
                    ? 'bg-yellow-600'
                    : 'bg-green-600'
                }`}
                style={{ width: `${Math.min(usagePercentage, 100)}%` }}
              />
            </div>
          </div>

          {subscription?.current_period_end && (
            <div className="text-sm text-gray-600 dark:text-gray-400">
              Resets on:{' '}
              {new Date(subscription.current_period_end).toLocaleDateString()}
            </div>
          )}
        </div>
      </div>

      {/* Usage Analytics */}
      {usage && (
        <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800">
          <h3 className="mb-4 text-lg font-medium text-gray-900 dark:text-white">
            Usage Analytics
          </h3>

          <div className="mb-6 grid grid-cols-1 gap-6 md:grid-cols-3">
            <div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Total Requests
              </div>
              <div className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                {usage.totals?.requests || 0}
              </div>
            </div>

            <div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Total Tokens
              </div>
              <div className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                {usage.totals?.total_tokens?.toLocaleString() || 0}
              </div>
            </div>

            <div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Total Cost
              </div>
              <div className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                ${usage.totals?.total_cost?.toFixed(4) || 0}
              </div>
            </div>
          </div>

          {/* Model Usage Breakdown */}
          {usage.by_model && Object.keys(usage.by_model).length > 0 && (
            <div className="mt-6">
              <h4 className="mb-3 text-md font-medium text-gray-900 dark:text-white">
                Usage by Model
              </h4>
              <div className="space-y-2">
                {Object.entries(usage.by_model).map(([model, data]) => (
                  <div
                    key={model}
                    className="flex items-center justify-between rounded bg-gray-50 p-3 dark:bg-gray-900"
                  >
                    <span className="font-medium text-gray-900 dark:text-white">
                      {model}
                    </span>
                    <div className="text-right">
                      <div className="text-sm text-gray-600 dark:text-gray-400">
                        {data.requests} requests
                      </div>
                      <div className="text-sm font-medium text-gray-900 dark:text-white">
                        ${data.cost?.toFixed(4) || 0}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

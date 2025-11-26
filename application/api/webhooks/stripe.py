"""
Stripe webhook handlers for subscription events.
"""

import stripe
from flask import jsonify, make_response, request
from flask_restx import Namespace, Resource

from application.core.mongo_db import MongoDB
from application.core.settings import settings
from application.services.subscription_service import SubscriptionService

stripe.api_key = settings.STRIPE_SECRET_KEY

webhook_ns = Namespace("webhooks", description="Webhook handlers")

# Database
mongo = MongoDB.get_client()
db = mongo[settings.MONGO_DB_NAME]
users_collection = db["users"]


@webhook_ns.route("/stripe")
class StripeWebhook(Resource):
    """Handle Stripe webhook events"""

    @webhook_ns.doc("stripe_webhook")
    def post(self):
        """Process Stripe webhook events"""
        payload = request.data
        sig_header = request.headers.get("Stripe-Signature")

        # Verify webhook signature (if webhook secret is configured)
        if settings.STRIPE_WEBHOOK_SECRET:
            try:
                event = stripe.Webhook.construct_event(
                    payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
                )
            except stripe.error.SignatureVerificationError:
                return make_response(
                    jsonify({"success": False, "message": "Invalid signature"}), 400
                )
        else:
            event = stripe.Event.construct_from(request.json, stripe.api_key)

        # Handle event types
        event_type = event["type"]

        if event_type == "checkout.session.completed":
            session = event["data"]["object"]
            handle_checkout_completed(session)

        elif event_type == "customer.subscription.created":
            subscription = event["data"]["object"]
            handle_subscription_created(subscription)

        elif event_type == "customer.subscription.updated":
            subscription = event["data"]["object"]
            handle_subscription_updated(subscription)

        elif event_type == "customer.subscription.deleted":
            subscription = event["data"]["object"]
            handle_subscription_deleted(subscription)

        elif event_type == "invoice.payment_succeeded":
            invoice = event["data"]["object"]
            handle_payment_succeeded(invoice)

        elif event_type == "invoice.payment_failed":
            invoice = event["data"]["object"]
            handle_payment_failed(invoice)

        return jsonify({"success": True})


def handle_checkout_completed(session):
    """Handle completed checkout session"""
    customer_id = session.get("customer")
    subscription_id = session.get("subscription")
    metadata = session.get("metadata", {})
    user_id = metadata.get("user_id")
    plan = metadata.get("plan")

    if user_id and plan:
        # Upgrade user subscription
        SubscriptionService.upgrade_subscription(user_id, plan, subscription_id)


def handle_subscription_created(subscription):
    """Handle new subscription creation"""
    customer_id = subscription.get("customer")
    subscription_id = subscription["id"]

    # Find user by customer ID
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription ID
        users_collection.update_one(
            {"user_id": user["user_id"]},
            {"$set": {"stripe_subscription_id": subscription_id}},
        )


def handle_subscription_updated(subscription):
    """Handle subscription updates"""
    customer_id = subscription.get("customer")
    subscription_id = subscription["id"]
    status = subscription.get("status")

    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription status
        update_data = {
            "subscription_status": status,
            "stripe_subscription_id": subscription_id,
        }

        users_collection.update_one(
            {"user_id": user["user_id"]}, {"$set": update_data}
        )


def handle_subscription_deleted(subscription):
    """Handle subscription cancellation"""
    customer_id = subscription.get("customer")

    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Downgrade to free plan
        SubscriptionService.upgrade_subscription(user["user_id"], "free", None)


def handle_payment_succeeded(invoice):
    """Handle successful payment"""
    customer_id = invoice.get("customer")
    subscription_id = invoice.get("subscription")

    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription status to active
        users_collection.update_one(
            {"user_id": user["user_id"]}, {"$set": {"subscription_status": "active"}}
        )


def handle_payment_failed(invoice):
    """Handle failed payment"""
    customer_id = invoice.get("customer")

    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription status to past_due
        users_collection.update_one(
            {"user_id": user["user_id"]}, {"$set": {"subscription_status": "past_due"}}
        )

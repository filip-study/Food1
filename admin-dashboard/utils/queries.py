"""
Database queries for admin dashboard.

All queries use the service role client to bypass RLS
and access data across all users.

Data is cached for 60 seconds to prevent excessive API calls.
"""

import random
from datetime import datetime, timedelta, timezone
from typing import Optional
import pandas as pd
import streamlit as st
from .supabase_client import get_supabase_client


# Cache TTL in seconds (data refreshes after this time)
CACHE_TTL = 60


@st.cache_data(ttl=CACHE_TTL)
def get_all_users() -> pd.DataFrame:
    """
    Fetch all user profiles with subscription status.

    Returns DataFrame with columns:
    - id, email, full_name, created_at
    - subscription_type, trial_end_date
    """
    client = get_supabase_client()

    # Get profiles
    profiles = client.table("profiles").select("*").execute()

    # Get subscription status
    subscriptions = client.table("subscription_status").select("*").execute()

    # Convert to DataFrames
    profiles_df = pd.DataFrame(profiles.data) if profiles.data else pd.DataFrame()
    subs_df = pd.DataFrame(subscriptions.data) if subscriptions.data else pd.DataFrame()

    if profiles_df.empty:
        return pd.DataFrame()

    # Merge on user_id
    if not subs_df.empty:
        subs_df = subs_df.rename(columns={"user_id": "id"})
        profiles_df = profiles_df.merge(subs_df, on="id", how="left", suffixes=("", "_sub"))

    return profiles_df


@st.cache_data(ttl=CACHE_TTL)
def get_all_meals() -> pd.DataFrame:
    """
    Fetch all meals across all users.

    Returns DataFrame with all meal columns including:
    - id, user_id, name, emoji, meal_type
    - timestamp, photo_thumbnail_url
    - total_calories, total_protein_g, total_carbs_g, total_fat_g
    - sync_status, created_at
    """
    client = get_supabase_client()

    result = client.table("meals")\
        .select("*")\
        .is_("deleted_at", "null")\
        .order("timestamp", desc=True)\
        .execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()


@st.cache_data(ttl=CACHE_TTL)
def get_user_meals(user_id: str) -> pd.DataFrame:
    """
    Fetch all meals for a specific user.

    Args:
        user_id: UUID string of the user

    Returns DataFrame of user's meals, ordered by timestamp descending.
    """
    client = get_supabase_client()

    result = client.table("meals")\
        .select("*")\
        .eq("user_id", user_id)\
        .is_("deleted_at", "null")\
        .order("timestamp", desc=True)\
        .execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()


@st.cache_data(ttl=CACHE_TTL)
def get_all_ingredients() -> pd.DataFrame:
    """
    Fetch all meal ingredients across all users.

    Returns DataFrame with columns:
    - id, meal_id, name, quantity, unit
    - usda_fdc_id, usda_description, enrichment_attempted
    """
    client = get_supabase_client()

    result = client.table("meal_ingredients")\
        .select("*")\
        .execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()


@st.cache_data(ttl=CACHE_TTL)
def get_meal_ingredients(meal_id: str) -> pd.DataFrame:
    """
    Fetch ingredients for a specific meal.

    Args:
        meal_id: UUID string of the meal

    Returns DataFrame of meal's ingredients.
    """
    client = get_supabase_client()

    result = client.table("meal_ingredients")\
        .select("*")\
        .eq("meal_id", meal_id)\
        .execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()


def get_random_user() -> Optional[dict]:
    """
    Select a random user from the database.

    Returns dict with user profile data, or None if no users exist.
    """
    users_df = get_all_users()

    if users_df.empty:
        return None

    random_idx = random.randint(0, len(users_df) - 1)
    return users_df.iloc[random_idx].to_dict()


def get_user_by_id(user_id: str) -> Optional[dict]:
    """
    Fetch a specific user's profile.

    Args:
        user_id: UUID string of the user

    Returns dict with user profile data, or None if not found.
    """
    client = get_supabase_client()

    result = client.table("profiles")\
        .select("*")\
        .eq("id", user_id)\
        .execute()

    if result.data:
        user = result.data[0]

        # Also fetch subscription status
        sub_result = client.table("subscription_status")\
            .select("*")\
            .eq("user_id", user_id)\
            .execute()

        if sub_result.data:
            user.update(sub_result.data[0])

        return user

    return None


def get_activity_stats() -> dict:
    """
    Calculate aggregate activity statistics.

    Returns dict with:
    - total_users, total_meals, total_ingredients
    - meals_last_7_days, meals_last_30_days
    - active_users_7d, active_users_30d
    - avg_meals_per_user
    """
    users_df = get_all_users()
    meals_df = get_all_meals()
    ingredients_df = get_all_ingredients()

    now = datetime.now(timezone.utc)
    seven_days_ago = now - timedelta(days=7)
    thirty_days_ago = now - timedelta(days=30)

    # Basic counts
    stats = {
        "total_users": len(users_df),
        "total_meals": len(meals_df),
        "total_ingredients": len(ingredients_df),
    }

    if meals_df.empty:
        stats.update({
            "meals_last_7_days": 0,
            "meals_last_30_days": 0,
            "active_users_7d": 0,
            "active_users_30d": 0,
            "avg_meals_per_user": 0,
        })
        return stats

    # Convert timestamp to datetime
    meals_df["timestamp"] = pd.to_datetime(meals_df["timestamp"])

    # Recent meals
    recent_7d = meals_df[meals_df["timestamp"] >= seven_days_ago]
    recent_30d = meals_df[meals_df["timestamp"] >= thirty_days_ago]

    stats["meals_last_7_days"] = len(recent_7d)
    stats["meals_last_30_days"] = len(recent_30d)

    # Active users
    stats["active_users_7d"] = recent_7d["user_id"].nunique() if not recent_7d.empty else 0
    stats["active_users_30d"] = recent_30d["user_id"].nunique() if not recent_30d.empty else 0

    # Average meals per user
    if stats["total_users"] > 0:
        stats["avg_meals_per_user"] = round(stats["total_meals"] / stats["total_users"], 1)
    else:
        stats["avg_meals_per_user"] = 0

    return stats


def get_meals_per_day(days: int = 30) -> pd.DataFrame:
    """
    Get meal count per day for the last N days.

    Args:
        days: Number of days to look back

    Returns DataFrame with columns: date, count
    """
    meals_df = get_all_meals()

    if meals_df.empty:
        return pd.DataFrame(columns=["date", "count"])

    meals_df["timestamp"] = pd.to_datetime(meals_df["timestamp"])
    meals_df["date"] = meals_df["timestamp"].dt.date

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    recent = meals_df[meals_df["timestamp"] >= cutoff]

    daily_counts = recent.groupby("date").size().reset_index(name="count")
    daily_counts["date"] = pd.to_datetime(daily_counts["date"])

    return daily_counts.sort_values("date")


def get_meal_type_distribution() -> pd.DataFrame:
    """
    Get distribution of meal types (breakfast, lunch, dinner, snack).

    Returns DataFrame with columns: meal_type, count, percentage
    """
    meals_df = get_all_meals()

    if meals_df.empty:
        return pd.DataFrame(columns=["meal_type", "count", "percentage"])

    type_counts = meals_df["meal_type"].value_counts().reset_index()
    type_counts.columns = ["meal_type", "count"]
    type_counts["percentage"] = (type_counts["count"] / type_counts["count"].sum() * 100).round(1)

    return type_counts


def get_hourly_activity() -> pd.DataFrame:
    """
    Get meal logging activity by hour of day and day of week.

    Returns DataFrame suitable for heatmap with columns:
    - day_of_week (0=Monday, 6=Sunday)
    - hour (0-23)
    - count
    """
    meals_df = get_all_meals()

    if meals_df.empty:
        return pd.DataFrame(columns=["day_of_week", "hour", "count"])

    meals_df["timestamp"] = pd.to_datetime(meals_df["timestamp"])
    meals_df["day_of_week"] = meals_df["timestamp"].dt.dayofweek
    meals_df["hour"] = meals_df["timestamp"].dt.hour

    hourly = meals_df.groupby(["day_of_week", "hour"]).size().reset_index(name="count")

    return hourly


def get_top_ingredients(limit: int = 20) -> pd.DataFrame:
    """
    Get most frequently logged ingredients.

    Args:
        limit: Maximum number of ingredients to return

    Returns DataFrame with columns: name, count
    """
    ingredients_df = get_all_ingredients()

    if ingredients_df.empty:
        return pd.DataFrame(columns=["name", "count"])

    # Normalize ingredient names (lowercase, strip whitespace)
    ingredients_df["name_normalized"] = ingredients_df["name"].str.lower().str.strip()

    top = ingredients_df["name_normalized"].value_counts().head(limit).reset_index()
    top.columns = ["name", "count"]

    return top


def get_enrichment_stats() -> dict:
    """
    Calculate USDA enrichment statistics.

    Returns dict with:
    - total_ingredients
    - enrichment_attempted
    - enrichment_successful (has usda_fdc_id)
    - success_rate
    """
    ingredients_df = get_all_ingredients()

    if ingredients_df.empty:
        return {
            "total_ingredients": 0,
            "enrichment_attempted": 0,
            "enrichment_successful": 0,
            "success_rate": 0,
        }

    total = len(ingredients_df)
    attempted = ingredients_df["enrichment_attempted"].sum() if "enrichment_attempted" in ingredients_df.columns else 0
    successful = ingredients_df["usda_fdc_id"].notna().sum()

    return {
        "total_ingredients": total,
        "enrichment_attempted": int(attempted),
        "enrichment_successful": int(successful),
        "success_rate": round(successful / total * 100, 1) if total > 0 else 0,
    }


def get_sync_status_distribution() -> pd.DataFrame:
    """
    Get distribution of meal sync statuses.

    Returns DataFrame with columns: sync_status, count, percentage
    """
    meals_df = get_all_meals()

    if meals_df.empty:
        return pd.DataFrame(columns=["sync_status", "count", "percentage"])

    status_counts = meals_df["sync_status"].value_counts().reset_index()
    status_counts.columns = ["sync_status", "count"]
    status_counts["percentage"] = (status_counts["count"] / status_counts["count"].sum() * 100).round(1)

    return status_counts


def get_photo_stats() -> dict:
    """
    Calculate photo upload statistics.

    Returns dict with:
    - total_meals
    - meals_with_photos
    - photo_rate (percentage)
    """
    meals_df = get_all_meals()

    if meals_df.empty:
        return {
            "total_meals": 0,
            "meals_with_photos": 0,
            "photo_rate": 0,
        }

    total = len(meals_df)
    with_photos = meals_df["photo_thumbnail_url"].notna().sum()

    return {
        "total_meals": total,
        "meals_with_photos": int(with_photos),
        "photo_rate": round(with_photos / total * 100, 1) if total > 0 else 0,
    }


def get_avg_macros_by_meal_type() -> pd.DataFrame:
    """
    Calculate average macros grouped by meal type.

    Returns DataFrame with columns:
    - meal_type
    - avg_calories, avg_protein, avg_carbs, avg_fat
    """
    meals_df = get_all_meals()

    if meals_df.empty:
        return pd.DataFrame(columns=["meal_type", "avg_calories", "avg_protein", "avg_carbs", "avg_fat"])

    # Convert to numeric, handling None values
    for col in ["total_calories", "total_protein_g", "total_carbs_g", "total_fat_g"]:
        meals_df[col] = pd.to_numeric(meals_df[col], errors="coerce")

    # Group by meal type and calculate averages
    avg_macros = meals_df.groupby("meal_type").agg({
        "total_calories": "mean",
        "total_protein_g": "mean",
        "total_carbs_g": "mean",
        "total_fat_g": "mean",
    }).round(1).reset_index()

    avg_macros.columns = ["meal_type", "avg_calories", "avg_protein", "avg_carbs", "avg_fat"]

    return avg_macros


def get_user_subscription(user_id: str) -> Optional[dict]:
    """
    Fetch subscription status for a specific user.

    Args:
        user_id: UUID string of the user

    Returns dict with subscription data, or None if not found.
    """
    client = get_supabase_client()

    result = client.table("subscription_status")\
        .select("*")\
        .eq("user_id", user_id)\
        .execute()

    return result.data[0] if result.data else None


def update_user_subscription(
    user_id: str,
    trial_end_date: Optional[datetime] = None,
    subscription_type: Optional[str] = None,
    subscription_expires_at: Optional[datetime] = None
) -> bool:
    """
    Update a user's subscription status.

    Args:
        user_id: UUID string of the user
        trial_end_date: New trial end date (to extend/reset trial)
        subscription_type: New subscription type ('trial', 'active', 'expired', 'cancelled')
        subscription_expires_at: Subscription expiration date (for paid subscriptions)

    Returns True if successful, False otherwise.
    """
    client = get_supabase_client()

    update_data = {
        "updated_at": datetime.now(timezone.utc).isoformat()
    }

    if trial_end_date is not None:
        update_data["trial_end_date"] = trial_end_date.isoformat()

    if subscription_type is not None:
        update_data["subscription_type"] = subscription_type

    if subscription_expires_at is not None:
        update_data["subscription_expires_at"] = subscription_expires_at.isoformat()

    try:
        client.table("subscription_status")\
            .update(update_data)\
            .eq("user_id", user_id)\
            .execute()

        # Clear cache so changes are reflected immediately
        get_all_users.clear()

        return True
    except Exception as e:
        print(f"Error updating subscription: {e}")
        return False


def extend_user_trial(user_id: str, days: int) -> bool:
    """
    Extend a user's trial by a specified number of days.
    If trial has expired, resets subscription_type to 'trial' and sets new end date.

    Args:
        user_id: UUID string of the user
        days: Number of days to add (from today if trial expired, from current end date if active)

    Returns True if successful, False otherwise.
    """
    sub = get_user_subscription(user_id)
    if not sub:
        return False

    now = datetime.now(timezone.utc)

    # Parse current trial end date
    current_end = None
    if sub.get("trial_end_date"):
        try:
            current_end = datetime.fromisoformat(sub["trial_end_date"].replace("Z", "+00:00"))
        except:
            current_end = None

    # Calculate new end date
    if current_end and current_end > now:
        # Trial still active - extend from current end date
        new_end = current_end + timedelta(days=days)
    else:
        # Trial expired - extend from today
        new_end = now + timedelta(days=days)

    # Update subscription: set trial end date and ensure type is 'trial'
    return update_user_subscription(
        user_id=user_id,
        trial_end_date=new_end,
        subscription_type="trial"
    )


# ============================================================================
# ONBOARDING QUERIES
# ============================================================================

@st.cache_data(ttl=CACHE_TTL)
def get_all_onboarding() -> pd.DataFrame:
    """
    Fetch onboarding status for all users.

    Returns DataFrame with columns:
    - user_id, welcome_completed_at, meal_reminders_completed_at
    - profile_setup_completed_at, app_version_first_seen, created_at
    """
    client = get_supabase_client()

    result = client.table("user_onboarding").select("*").execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()


@st.cache_data(ttl=CACHE_TTL)
def get_meal_reminder_settings() -> pd.DataFrame:
    """
    Fetch meal reminder settings for all users.

    Returns DataFrame with columns:
    - user_id, is_enabled, lead_time_minutes, auto_dismiss_minutes
    - use_learning, onboarding_completed, created_at, updated_at
    """
    client = get_supabase_client()

    result = client.table("meal_reminder_settings").select("*").execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()


@st.cache_data(ttl=CACHE_TTL)
def get_meal_windows() -> pd.DataFrame:
    """
    Fetch all meal windows across all users.

    Returns DataFrame with columns:
    - id, user_id, name, target_time, learned_time
    - is_enabled, sort_order, created_at, updated_at
    """
    client = get_supabase_client()

    result = client.table("meal_windows").select("*").execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()


def get_onboarding_stats() -> dict:
    """
    Calculate onboarding completion statistics.

    Returns dict with:
    - total_users
    - welcome_completed, welcome_rate
    - meal_reminders_completed, meal_reminders_rate
    - profile_setup_completed, profile_setup_rate
    - fully_onboarded (all steps complete)
    """
    users_df = get_all_users()
    onboarding_df = get_all_onboarding()

    total_users = len(users_df)

    if onboarding_df.empty or total_users == 0:
        return {
            "total_users": total_users,
            "welcome_completed": 0,
            "welcome_rate": 0,
            "meal_reminders_completed": 0,
            "meal_reminders_rate": 0,
            "profile_setup_completed": 0,
            "profile_setup_rate": 0,
            "fully_onboarded": 0,
            "fully_onboarded_rate": 0,
        }

    welcome = onboarding_df["welcome_completed_at"].notna().sum()
    meal_reminders = onboarding_df["meal_reminders_completed_at"].notna().sum()
    profile_setup = onboarding_df["profile_setup_completed_at"].notna().sum()

    # Fully onboarded = all steps complete
    fully = (
        onboarding_df["welcome_completed_at"].notna() &
        onboarding_df["meal_reminders_completed_at"].notna() &
        onboarding_df["profile_setup_completed_at"].notna()
    ).sum()

    return {
        "total_users": total_users,
        "welcome_completed": int(welcome),
        "welcome_rate": round(welcome / total_users * 100, 1),
        "meal_reminders_completed": int(meal_reminders),
        "meal_reminders_rate": round(meal_reminders / total_users * 100, 1),
        "profile_setup_completed": int(profile_setup),
        "profile_setup_rate": round(profile_setup / total_users * 100, 1),
        "fully_onboarded": int(fully),
        "fully_onboarded_rate": round(fully / total_users * 100, 1),
    }


def get_meal_reminder_stats() -> dict:
    """
    Calculate meal reminder feature adoption statistics.

    Returns dict with:
    - total_configured (has settings)
    - feature_enabled (is_enabled = true)
    - learning_enabled (use_learning = true)
    - total_meal_windows
    - avg_windows_per_user
    """
    settings_df = get_meal_reminder_settings()
    windows_df = get_meal_windows()

    if settings_df.empty:
        return {
            "total_configured": 0,
            "feature_enabled": 0,
            "feature_enabled_rate": 0,
            "learning_enabled": 0,
            "total_meal_windows": 0,
            "avg_windows_per_user": 0,
        }

    total = len(settings_df)
    enabled = settings_df["is_enabled"].sum() if "is_enabled" in settings_df.columns else 0
    learning = settings_df["use_learning"].sum() if "use_learning" in settings_df.columns else 0

    total_windows = len(windows_df)
    avg_windows = round(total_windows / total, 1) if total > 0 else 0

    return {
        "total_configured": total,
        "feature_enabled": int(enabled),
        "feature_enabled_rate": round(enabled / total * 100, 1) if total > 0 else 0,
        "learning_enabled": int(learning),
        "total_meal_windows": total_windows,
        "avg_windows_per_user": avg_windows,
    }


def get_onboarding_funnel() -> pd.DataFrame:
    """
    Get onboarding funnel data for visualization.

    Returns DataFrame with columns: step, count, rate
    Ordered: Registered -> Welcome -> Meal Reminders -> Profile Setup
    """
    users_df = get_all_users()
    onboarding_df = get_all_onboarding()

    total = len(users_df)

    if total == 0:
        return pd.DataFrame(columns=["step", "count", "rate"])

    welcome = onboarding_df["welcome_completed_at"].notna().sum() if not onboarding_df.empty else 0
    meal_reminders = onboarding_df["meal_reminders_completed_at"].notna().sum() if not onboarding_df.empty else 0
    profile_setup = onboarding_df["profile_setup_completed_at"].notna().sum() if not onboarding_df.empty else 0

    funnel_data = [
        {"step": "Registered", "count": total, "rate": 100.0},
        {"step": "Welcome", "count": int(welcome), "rate": round(welcome / total * 100, 1)},
        {"step": "Meal Reminders", "count": int(meal_reminders), "rate": round(meal_reminders / total * 100, 1)},
        {"step": "Profile Setup", "count": int(profile_setup), "rate": round(profile_setup / total * 100, 1)},
    ]

    return pd.DataFrame(funnel_data)


def get_user_onboarding(user_id: str) -> Optional[dict]:
    """
    Fetch onboarding status for a specific user.

    Args:
        user_id: UUID string of the user

    Returns dict with onboarding data, or None if not found.
    """
    client = get_supabase_client()

    result = client.table("user_onboarding")\
        .select("*")\
        .eq("user_id", user_id)\
        .execute()

    return result.data[0] if result.data else None


def get_user_meal_reminder_settings(user_id: str) -> Optional[dict]:
    """
    Fetch meal reminder settings for a specific user.

    Args:
        user_id: UUID string of the user

    Returns dict with settings, or None if not configured.
    """
    client = get_supabase_client()

    result = client.table("meal_reminder_settings")\
        .select("*")\
        .eq("user_id", user_id)\
        .execute()

    return result.data[0] if result.data else None


def get_user_meal_windows(user_id: str) -> pd.DataFrame:
    """
    Fetch meal windows for a specific user.

    Args:
        user_id: UUID string of the user

    Returns DataFrame of user's meal windows.
    """
    client = get_supabase_client()

    result = client.table("meal_windows")\
        .select("*")\
        .eq("user_id", user_id)\
        .order("sort_order")\
        .execute()

    return pd.DataFrame(result.data) if result.data else pd.DataFrame()

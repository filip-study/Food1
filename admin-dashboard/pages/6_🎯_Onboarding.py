"""
Onboarding & Feature Adoption Tracking

Visual dashboard for monitoring:
- Onboarding funnel completion rates
- Meal reminder feature adoption
- User journey progression
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from utils.queries import (
    get_onboarding_stats,
    get_meal_reminder_stats,
    get_onboarding_funnel,
    get_all_onboarding,
    get_meal_reminder_settings,
    get_meal_windows,
    get_all_users,
)

st.set_page_config(page_title="Onboarding - Food1 Admin", page_icon="🎯", layout="wide")

st.title("🎯 Onboarding & Feature Adoption")
st.caption("Track user journey through onboarding and feature adoption rates")

# ============================================================================
# TOP METRICS
# ============================================================================

try:
    onboarding_stats = get_onboarding_stats()
    reminder_stats = get_meal_reminder_stats()

    # Key metrics row
    st.subheader("📊 Overview")
    col1, col2, col3, col4 = st.columns(4)

    col1.metric(
        "Total Users",
        onboarding_stats["total_users"],
        help="Total registered users"
    )
    col2.metric(
        "Fully Onboarded",
        f"{onboarding_stats['fully_onboarded_rate']}%",
        f"{onboarding_stats['fully_onboarded']} users",
        help="Users who completed all onboarding steps"
    )
    col3.metric(
        "Reminders Enabled",
        f"{reminder_stats['feature_enabled_rate']}%",
        f"{reminder_stats['feature_enabled']} users",
        help="Users with meal reminders turned on"
    )
    col4.metric(
        "Meal Windows",
        reminder_stats["total_meal_windows"],
        f"~{reminder_stats['avg_windows_per_user']} per user",
        help="Total configured meal time windows"
    )

    st.divider()

    # ============================================================================
    # ONBOARDING FUNNEL
    # ============================================================================

    st.subheader("🔄 Onboarding Funnel")

    funnel_df = get_onboarding_funnel()

    if not funnel_df.empty:
        # Create funnel chart
        fig = go.Figure(go.Funnel(
            y=funnel_df["step"],
            x=funnel_df["count"],
            textposition="inside",
            textinfo="value+percent initial",
            marker=dict(
                color=["#10b981", "#14b8a6", "#06b6d4", "#0ea5e9"]
            ),
            connector=dict(line=dict(color="lightgray", width=1))
        ))

        fig.update_layout(
            title="User Journey Through Onboarding",
            height=400,
            margin=dict(l=20, r=20, t=60, b=20),
        )

        st.plotly_chart(fig, use_container_width=True)

        # Drop-off analysis
        st.markdown("#### Drop-off Analysis")
        col1, col2, col3 = st.columns(3)

        if len(funnel_df) >= 2:
            welcome_dropoff = 100 - funnel_df.iloc[1]["rate"]
            col1.metric("Registration → Welcome", f"-{welcome_dropoff:.1f}%", delta_color="inverse")

        if len(funnel_df) >= 3:
            reminders_dropoff = funnel_df.iloc[1]["rate"] - funnel_df.iloc[2]["rate"]
            col2.metric("Welcome → Reminders", f"-{reminders_dropoff:.1f}%", delta_color="inverse")

        if len(funnel_df) >= 4:
            profile_dropoff = funnel_df.iloc[2]["rate"] - funnel_df.iloc[3]["rate"]
            col3.metric("Reminders → Profile", f"-{profile_dropoff:.1f}%", delta_color="inverse")
    else:
        st.info("No onboarding data yet. Users will appear here after they start onboarding.")

    st.divider()

    # ============================================================================
    # STEP COMPLETION DETAILS
    # ============================================================================

    st.subheader("📋 Step Completion Details")

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("#### Onboarding Steps")

        # Progress bars for each step
        steps = [
            ("Welcome", onboarding_stats["welcome_completed"], onboarding_stats["welcome_rate"]),
            ("Meal Reminders", onboarding_stats["meal_reminders_completed"], onboarding_stats["meal_reminders_rate"]),
            ("Profile Setup", onboarding_stats["profile_setup_completed"], onboarding_stats["profile_setup_rate"]),
        ]

        for step_name, count, rate in steps:
            st.markdown(f"**{step_name}** - {count} users ({rate}%)")
            st.progress(rate / 100)

    with col2:
        st.markdown("#### Meal Reminder Adoption")

        # Reminder-specific stats
        if reminder_stats["total_configured"] > 0:
            adoption_data = {
                "Feature Configured": reminder_stats["total_configured"],
                "Feature Enabled": reminder_stats["feature_enabled"],
                "Smart Learning On": reminder_stats["learning_enabled"],
            }

            for label, value in adoption_data.items():
                st.metric(label, value)
        else:
            st.info("No meal reminder configurations yet.")

    st.divider()

    # ============================================================================
    # MEAL WINDOWS ANALYSIS
    # ============================================================================

    st.subheader("⏰ Meal Windows Configuration")

    windows_df = get_meal_windows()

    if not windows_df.empty:
        col1, col2 = st.columns(2)

        with col1:
            # Distribution of window names
            name_counts = windows_df["name"].value_counts().reset_index()
            name_counts.columns = ["Meal Name", "Count"]

            fig = px.bar(
                name_counts.head(10),
                x="Meal Name",
                y="Count",
                title="Most Popular Meal Names",
                color="Count",
                color_continuous_scale="teal"
            )
            fig.update_layout(showlegend=False)
            st.plotly_chart(fig, use_container_width=True)

        with col2:
            # Target time distribution
            if "target_time" in windows_df.columns:
                # Parse time strings to hours
                def parse_time_to_hour(time_str):
                    try:
                        if pd.isna(time_str):
                            return None
                        parts = str(time_str).split(":")
                        return int(parts[0])
                    except:
                        return None

                windows_df["hour"] = windows_df["target_time"].apply(parse_time_to_hour)
                hour_counts = windows_df["hour"].dropna().value_counts().sort_index().reset_index()
                hour_counts.columns = ["Hour", "Count"]

                fig = px.bar(
                    hour_counts,
                    x="Hour",
                    y="Count",
                    title="Meal Times Distribution",
                    labels={"Hour": "Hour of Day", "Count": "Windows"},
                    color="Count",
                    color_continuous_scale="oranges"
                )
                fig.update_layout(showlegend=False)
                fig.update_xaxes(tickmode="linear", dtick=2)
                st.plotly_chart(fig, use_container_width=True)

        # Windows per user distribution
        windows_per_user = windows_df.groupby("user_id").size().reset_index(name="count")

        st.markdown("#### Windows per User Distribution")
        fig = px.histogram(
            windows_per_user,
            x="count",
            title="How Many Meal Windows Do Users Configure?",
            labels={"count": "Number of Windows", "count": "Users"},
            nbins=6,
            color_discrete_sequence=["#14b8a6"]
        )
        fig.update_layout(bargap=0.1)
        st.plotly_chart(fig, use_container_width=True)

    else:
        st.info("No meal windows configured yet. Data will appear after users complete onboarding.")

    st.divider()

    # ============================================================================
    # RAW DATA TABLE
    # ============================================================================

    with st.expander("📄 View Raw Onboarding Data"):
        onboarding_df = get_all_onboarding()
        users_df = get_all_users()

        if not onboarding_df.empty and not users_df.empty:
            # Merge with user emails
            merged = onboarding_df.merge(
                users_df[["id", "email"]],
                left_on="user_id",
                right_on="id",
                how="left"
            )

            # Select relevant columns
            display_cols = ["email", "welcome_completed_at", "meal_reminders_completed_at",
                           "profile_setup_completed_at", "app_version_first_seen", "created_at"]
            available_cols = [c for c in display_cols if c in merged.columns]

            st.dataframe(
                merged[available_cols],
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("No data available.")

    st.success("✅ Connected to Supabase")

except Exception as e:
    st.error(f"❌ Error loading data: {str(e)}")
    st.info("Make sure your `.env` file is configured correctly and the database tables exist.")
    st.code(str(e))

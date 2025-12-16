"""Overview Dashboard"""

import streamlit as st
import plotly.express as px
import pandas as pd

st.set_page_config(page_title="Overview", page_icon="📊", layout="wide")

try:
    from utils.queries import get_all_users, get_all_meals
    from utils.filters import render_filters, filter_by_user, filter_by_time, get_filter_description

    # Load data
    users_df = get_all_users()
    all_meals_df = get_all_meals()

    # Unified filters in header
    scope, user_id, user_info, time_cutoff, time_label = render_filters(
        title="Overview", icon="📊", users_df=users_df, key="overview", allow_global=True
    )

    # Apply filters
    meals_df = filter_by_user(all_meals_df, scope, user_id)
    meals_df = filter_by_time(meals_df, time_cutoff)

    st.caption(f"{get_filter_description(scope, user_info, time_label)} · {len(meals_df)} meals")
    st.markdown("---")

    # Metrics
    col1, col2, col3, col4 = st.columns(4)

    if scope == "global":
        col1.metric("Users", len(users_df))
        col2.metric("Meals", len(meals_df))
        active = meals_df["user_id"].nunique() if not meals_df.empty else 0
        col3.metric("Active", active)
        avg = round(len(meals_df) / active, 1) if active > 0 else 0
        col4.metric("Avg/User", avg)
    else:
        col1.metric("Meals", len(meals_df))
        photos = meals_df["photo_thumbnail_url"].notna().sum() if not meals_df.empty else 0
        col2.metric("Photos", int(photos))
        avg_cal = meals_df["total_calories"].mean() if not meals_df.empty else 0
        col3.metric("Avg Cal", f"{avg_cal:.0f}" if pd.notna(avg_cal) else "—")
        if not meals_df.empty:
            meals_df["timestamp"] = pd.to_datetime(meals_df["timestamp"])
            col4.metric("Last", str(meals_df["timestamp"].max())[:10])
        else:
            col4.metric("Last", "—")

    st.markdown("---")

    # Activity chart
    if not meals_df.empty:
        st.markdown("### Activity")
        chart_df = meals_df.copy()
        chart_df["timestamp"] = pd.to_datetime(chart_df["timestamp"])
        chart_df["date"] = chart_df["timestamp"].dt.date
        daily = chart_df.groupby("date").size().reset_index(name="count")
        daily["date"] = pd.to_datetime(daily["date"])

        fig = px.area(daily.sort_values("date"), x="date", y="count", color_discrete_sequence=["#3b82f6"])
        fig.update_layout(height=260, margin=dict(l=20, r=20, t=10, b=20), xaxis_title="", yaxis_title="Meals")
        fig.update_traces(fill="tozeroy")
        st.plotly_chart(fig, use_container_width=True)

    st.markdown("---")

    # Meal types
    if not meals_df.empty and "meal_type" in meals_df.columns:
        st.markdown("### Meal Types")
        col1, col2 = st.columns([1, 2])
        types = meals_df["meal_type"].value_counts().reset_index()
        types.columns = ["type", "count"]

        with col1:
            fig = px.pie(types, values="count", names="type", color="type",
                         color_discrete_map={"breakfast": "#f59e0b", "lunch": "#10b981", "dinner": "#6366f1", "snack": "#ec4899"})
            fig.update_layout(height=200, margin=dict(l=10, r=10, t=10, b=10), showlegend=False)
            fig.update_traces(textposition="inside", textinfo="percent+label")
            st.plotly_chart(fig, use_container_width=True)

        with col2:
            for _, row in types.iterrows():
                pct = round(row["count"] / len(meals_df) * 100, 1)
                st.metric(row["type"].title(), f"{row['count']} ({pct}%)")
    else:
        st.info("No data")

except Exception as e:
    st.error(f"Error: {e}")
    import traceback
    st.code(traceback.format_exc())

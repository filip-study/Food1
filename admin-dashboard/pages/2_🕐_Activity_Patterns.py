"""Activity Patterns Dashboard"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd

st.set_page_config(page_title="Activity", page_icon="🕐", layout="wide")

try:
    from utils.queries import get_all_users, get_all_meals
    from utils.filters import render_filters, filter_by_user, filter_by_time, get_filter_description

    # Load data
    users_df = get_all_users()
    all_meals_df = get_all_meals()

    # Unified filters
    scope, user_id, user_info, time_cutoff, time_label = render_filters(
        title="Activity Patterns", icon="🕐", users_df=users_df, key="activity", allow_global=True
    )

    # Apply filters
    meals_df = filter_by_user(all_meals_df, scope, user_id)
    meals_df = filter_by_time(meals_df, time_cutoff)

    st.caption(f"{get_filter_description(scope, user_info, time_label)} · {len(meals_df)} meals")

    if meals_df.empty:
        st.warning("No data")
        st.stop()

    meals_df = meals_df.copy()
    meals_df["timestamp"] = pd.to_datetime(meals_df["timestamp"])
    meals_df["day_of_week"] = meals_df["timestamp"].dt.dayofweek
    meals_df["hour"] = meals_df["timestamp"].dt.hour

    st.markdown("---")

    # Heatmap
    st.markdown("### When Meals Are Logged")
    hourly = meals_df.groupby(["day_of_week", "hour"]).size().reset_index(name="count")
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    full_grid = pd.DataFrame([{"day_of_week": d, "hour": h, "count": 0} for d in range(7) for h in range(24)])
    merged = full_grid.merge(hourly, on=["day_of_week", "hour"], how="left", suffixes=("_", ""))
    merged["count"] = merged["count"].fillna(0)
    pivot = merged.pivot(index="day_of_week", columns="hour", values="count")
    pivot.index = [days[i] for i in pivot.index]

    fig = go.Figure(data=go.Heatmap(z=pivot.values, x=[f"{h:02d}" for h in range(24)], y=days,
                                     colorscale="Blues", hovertemplate="%{y} %{x}:00<br>%{z} meals<extra></extra>"))
    fig.update_layout(height=230, margin=dict(l=50, r=20, t=10, b=30), xaxis_title="Hour")
    st.plotly_chart(fig, use_container_width=True)

    col1, col2, col3 = st.columns(3)
    hour_totals = hourly.groupby("hour")["count"].sum()
    day_totals = hourly.groupby("day_of_week")["count"].sum()
    if not hour_totals.empty:
        col1.metric("Peak Hour", f"{hour_totals.idxmax():02d}:00")
    if not day_totals.empty:
        col2.metric("Peak Day", days[day_totals.idxmax()])
    weekday = hourly[hourly["day_of_week"] < 5]["count"].sum()
    weekend = hourly[hourly["day_of_week"] >= 5]["count"].sum()
    if weekday + weekend > 0:
        col3.metric("Weekend %", f"{round(weekend / (weekday + weekend) * 100, 1)}%")

    st.markdown("---")

    # Meal types
    if "meal_type" in meals_df.columns:
        st.markdown("### Meal Types")
        types = meals_df["meal_type"].value_counts().reset_index()
        types.columns = ["type", "count"]
        fig = px.bar(types, x="type", y="count", color="type",
                     color_discrete_map={"breakfast": "#f59e0b", "lunch": "#10b981", "dinner": "#6366f1", "snack": "#ec4899"})
        fig.update_layout(height=200, margin=dict(l=20, r=20, t=10, b=20), showlegend=False, xaxis_title="", yaxis_title="")
        st.plotly_chart(fig, use_container_width=True)

except Exception as e:
    st.error(f"Error: {e}")
    import traceback
    st.code(traceback.format_exc())

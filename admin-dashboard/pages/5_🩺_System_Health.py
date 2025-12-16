"""System Health Dashboard - Global only"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
from datetime import datetime, timedelta, timezone

st.set_page_config(page_title="System Health", page_icon="🩺", layout="wide")

try:
    from utils.queries import get_all_meals, get_all_users
    from utils.filters import init_filter_state, filter_by_time

    init_filter_state()

    # Load data
    all_meals_df = get_all_meals()
    all_users_df = get_all_users()

    # Header with time only (always global)
    col1, col2, col3 = st.columns([2, 0.8, 1])
    with col1:
        st.markdown("## 🩺 System Health")
    with col2:
        st.markdown("<div style='height: 8px'></div>", unsafe_allow_html=True)
        st.info("🌍 Global")
    with col3:
        st.markdown("<div style='height: 8px'></div>", unsafe_allow_html=True)
        from utils.filters import TIME_KEY
        TIME_RANGES = {"24h": 24, "7d": 168, "30d": 720, "90d": 2160, "All": None}
        time_opts = list(TIME_RANGES.keys())

        # Pre-initialize widget key if not set
        if TIME_KEY not in st.session_state:
            st.session_state[TIME_KEY] = st.session_state.filter_time

        try:
            sel_time = st.segmented_control("Time", time_opts, key=TIME_KEY, label_visibility="collapsed")
        except:
            current_idx = time_opts.index(st.session_state[TIME_KEY]) if st.session_state[TIME_KEY] in time_opts else 4
            sel_time = st.selectbox("Time", time_opts, index=current_idx, key=TIME_KEY, label_visibility="collapsed")
        if sel_time:
            st.session_state.filter_time = sel_time

    # Calculate cutoff
    hours = TIME_RANGES.get(st.session_state.filter_time)
    time_cutoff = datetime.now(timezone.utc) - timedelta(hours=hours) if hours else None
    meals_df = filter_by_time(all_meals_df, time_cutoff)

    st.caption(f"All users · {st.session_state.filter_time} · {len(meals_df)} meals")
    st.markdown("---")

    # Overview
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Users", len(all_users_df))
    col2.metric("Total Meals", len(all_meals_df))
    col3.metric("Period Meals", len(meals_df))
    active = meals_df["user_id"].nunique() if not meals_df.empty else 0
    col4.metric("Active Users", active)

    st.markdown("---")

    # Photo health
    st.markdown("### Photo Uploads")
    if not meals_df.empty:
        total = len(meals_df)
        photos = meals_df["photo_thumbnail_url"].notna().sum()
        rate = round(photos / total * 100, 1)

        col1, col2 = st.columns([1, 2])
        with col1:
            fig = go.Figure(go.Indicator(mode="gauge+number", value=rate,
                gauge={"axis": {"range": [0, 100]}, "bar": {"color": "#3b82f6"},
                       "steps": [{"range": [0, 50], "color": "#fee2e2"}, {"range": [50, 75], "color": "#fef3c7"}, {"range": [75, 100], "color": "#d1fae5"}]}))
            fig.update_layout(height=180, margin=dict(l=20, r=20, t=30, b=10))
            st.plotly_chart(fig, use_container_width=True)
        with col2:
            c1, c2, c3 = st.columns(3)
            c1.metric("Meals", total)
            c2.metric("Photos", int(photos))
            c3.metric("Rate", f"{rate}%")

    st.markdown("---")

    # Sync status
    st.markdown("### Sync Status")
    if not meals_df.empty and "sync_status" in meals_df.columns:
        sync = meals_df["sync_status"].value_counts().reset_index()
        sync.columns = ["status", "count"]

        col1, col2 = st.columns([1, 1])
        with col1:
            colors = {"synced": "#10b981", "pending": "#f59e0b", "syncing": "#3b82f6", "error": "#ef4444"}
            fig = px.pie(sync, values="count", names="status", color="status", color_discrete_map=colors)
            fig.update_layout(height=220, margin=dict(l=10, r=10, t=10, b=10))
            fig.update_traces(textposition="inside", textinfo="percent+label")
            st.plotly_chart(fig, use_container_width=True)

        with col2:
            for _, row in sync.iterrows():
                pct = round(row["count"] / len(meals_df) * 100, 1)
                if row["status"] == "synced":
                    st.success(f"✅ Synced: {row['count']} ({pct}%)")
                elif row["status"] == "pending":
                    st.warning(f"⏳ Pending: {row['count']} ({pct}%)")
                elif row["status"] == "error":
                    st.error(f"❌ Error: {row['count']} ({pct}%)")
                else:
                    st.info(f"🔄 {row['status']}: {row['count']} ({pct}%)")

            synced = sync[sync["status"] == "synced"]["count"].sum() if "synced" in sync["status"].values else 0
            if synced / len(meals_df) >= 0.95:
                st.success("✅ Health: Excellent")
            elif synced / len(meals_df) >= 0.8:
                st.info("ℹ️ Health: Good")
            else:
                st.warning("⚠️ Check errors")

    st.markdown("---")

    # Errors
    st.markdown("### Errors")
    if not meals_df.empty:
        errors = meals_df[meals_df["sync_status"] == "error"]
        if not errors.empty:
            st.warning(f"{len(errors)} errors")
            display = errors[["name", "timestamp", "user_id"]].head(10).copy()
            display["timestamp"] = display["timestamp"].apply(lambda x: str(x)[:16])
            display["user_id"] = display["user_id"].apply(lambda x: str(x)[:8] + "...")
            st.dataframe(display, hide_index=True, use_container_width=True)
        else:
            st.success("✅ No errors")

except Exception as e:
    st.error(f"Error: {e}")
    import traceback
    st.code(traceback.format_exc())

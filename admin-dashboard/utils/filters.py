"""
Unified filters component - scope and time range.

Persists across all pages via session state using shared keys.
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta, timezone
from typing import Tuple, Optional
import random


# Time range options (5 options to fit on one row)
TIME_RANGES = {
    "24h": timedelta(hours=24),
    "7d": timedelta(days=7),
    "30d": timedelta(days=30),
    "90d": timedelta(days=90),
    "All": None,
}

# Shared keys for persistent state across pages
TIME_KEY = "global_time_selector"
SCOPE_KEY = "global_scope_selector"


def init_filter_state():
    """Initialize filter state if not exists."""
    if "filter_scope" not in st.session_state:
        st.session_state.filter_scope = "global"
    if "filter_user_id" not in st.session_state:
        st.session_state.filter_user_id = None
    if "filter_user_info" not in st.session_state:
        st.session_state.filter_user_info = None
    if "filter_time" not in st.session_state:
        st.session_state.filter_time = "30d"
    # Initialize widget keys with current values
    if TIME_KEY not in st.session_state:
        st.session_state[TIME_KEY] = st.session_state.filter_time


def render_filters(
    title: str,
    icon: str,
    users_df: pd.DataFrame,
    key: str,
    allow_global: bool = True,
) -> Tuple[str, Optional[str], Optional[dict], Optional[datetime], str]:
    """
    Render page header with unified filters (scope + time range).

    Returns:
        (scope_type, user_id, user_info, time_cutoff, time_label)
    """
    init_filter_state()

    # Build user options
    user_options = {}
    if not users_df.empty:
        for _, row in users_df.iterrows():
            uid = str(row.get("id", ""))
            email = row.get("email", "")
            name = row.get("full_name", "")
            display = email if email else (name if name else f"User {uid[:8]}...")
            user_options[display] = {"id": uid, "row": row.to_dict()}

    # Layout: Title | Scope | Time (wider columns to prevent wrapping)
    col_title, col_scope, col_time = st.columns([2, 1, 1.2])

    with col_title:
        st.markdown(f"## {icon} {title}")

    # Scope selector - compact labels, with top padding to align with title
    with col_scope:
        st.markdown("<div style='height: 8px'></div>", unsafe_allow_html=True)
        if allow_global:
            options = ["Global", "User", "Random"]
        else:
            options = ["User", "Random"]

        # Use page-specific key since options differ between pages
        scope_key = f"{key}_scope"

        # Get current scope value, ensuring it's valid for this page's options
        current_scope_value = "User"  # default
        if st.session_state.filter_scope == "global" and allow_global:
            current_scope_value = "Global"
        elif st.session_state.filter_scope == "random":
            current_scope_value = "Random"
        elif st.session_state.filter_scope == "user":
            current_scope_value = "User"

        # Pre-initialize widget key if not set
        if scope_key not in st.session_state:
            st.session_state[scope_key] = current_scope_value

        try:
            selected_scope = st.segmented_control(
                "Scope",
                options=options,
                key=scope_key,
                label_visibility="collapsed",
            )
        except:
            current_idx = options.index(st.session_state[scope_key]) if st.session_state[scope_key] in options else 0
            selected_scope = st.selectbox("Scope", options, index=current_idx,
                                          key=scope_key, label_visibility="collapsed")

        if selected_scope is None:
            selected_scope = options[0]

        # Update state based on selection
        if selected_scope == "Global":
            st.session_state.filter_scope = "global"
            st.session_state.filter_user_id = None
            st.session_state.filter_user_info = None
        elif selected_scope == "Random":
            st.session_state.filter_scope = "random"
        else:
            st.session_state.filter_scope = "user"

    # Time range selector - uses shared key across all pages
    with col_time:
        st.markdown("<div style='height: 8px'></div>", unsafe_allow_html=True)
        time_options = list(TIME_RANGES.keys())

        # Pre-initialize widget key if not set (before widget renders)
        if TIME_KEY not in st.session_state:
            st.session_state[TIME_KEY] = st.session_state.filter_time

        try:
            selected_time = st.segmented_control(
                "Time",
                options=time_options,
                key=TIME_KEY,  # Shared key - remembers selection across pages
                label_visibility="collapsed",
            )
        except:
            current_time_idx = time_options.index(st.session_state[TIME_KEY]) if st.session_state[TIME_KEY] in time_options else 4
            selected_time = st.selectbox("Time", time_options, index=current_time_idx,
                                         key=TIME_KEY, label_visibility="collapsed")

        # Sync back to filter_time for downstream use
        if selected_time:
            st.session_state.filter_time = selected_time

    # Handle user selection (below header if needed)
    scope_type = st.session_state.filter_scope
    user_id = st.session_state.filter_user_id
    user_info = st.session_state.filter_user_info

    if scope_type in ["user", "random"] and user_options:
        if scope_type == "random":
            col1, col2, col3 = st.columns([1, 2, 9])
            with col1:
                if st.button("🎲 New", key=f"{key}_rand"):
                    rand_key = random.choice(list(user_options.keys()))
                    st.session_state.filter_user_id = user_options[rand_key]["id"]
                    st.session_state.filter_user_info = user_options[rand_key]["row"]

            # Initialize random if not set
            if not st.session_state.filter_user_id:
                rand_key = random.choice(list(user_options.keys()))
                st.session_state.filter_user_id = user_options[rand_key]["id"]
                st.session_state.filter_user_info = user_options[rand_key]["row"]

            with col2:
                email = st.session_state.filter_user_info.get("email", "") if st.session_state.filter_user_info else ""
                st.info(f"👤 {email[:30]}" if email else "👤 Random user")

        else:  # specific user
            col1, col2 = st.columns([2, 10])
            with col1:
                # Find current user in options
                current_display = None
                for disp, info in user_options.items():
                    if info["id"] == st.session_state.filter_user_id:
                        current_display = disp
                        break

                sel = st.selectbox(
                    "User",
                    options=list(user_options.keys()),
                    index=list(user_options.keys()).index(current_display) if current_display else 0,
                    key=f"{key}_user",
                    label_visibility="collapsed",
                )
                if sel:
                    st.session_state.filter_user_id = user_options[sel]["id"]
                    st.session_state.filter_user_info = user_options[sel]["row"]

        user_id = st.session_state.filter_user_id
        user_info = st.session_state.filter_user_info

    # Calculate time cutoff
    time_delta = TIME_RANGES.get(st.session_state.filter_time)
    time_cutoff = datetime.now(timezone.utc) - time_delta if time_delta else None

    return scope_type, user_id, user_info, time_cutoff, st.session_state.filter_time


def get_filter_description(scope_type: str, user_info: Optional[dict], time_label: str) -> str:
    """Get compact description of current filters."""
    if scope_type == "global":
        scope_str = "All users"
    elif user_info:
        email = user_info.get("email", "")
        scope_str = email if email else f"User {str(user_info.get('id', ''))[:8]}..."
    else:
        scope_str = "Selected user"

    return f"{scope_str} · {time_label}"


def filter_by_user(
    df: pd.DataFrame,
    scope_type: str,
    user_id: Optional[str],
    user_column: str = "user_id",
) -> pd.DataFrame:
    """Filter DataFrame by user scope."""
    if scope_type == "global" or user_id is None:
        return df
    if df.empty or user_column not in df.columns:
        return df
    return df[df[user_column] == user_id]


def filter_by_time(
    df: pd.DataFrame,
    cutoff: Optional[datetime],
    timestamp_column: str = "timestamp",
) -> pd.DataFrame:
    """Filter DataFrame by time cutoff."""
    if df.empty or cutoff is None:
        return df
    if timestamp_column not in df.columns:
        return df
    df = df.copy()
    df[timestamp_column] = pd.to_datetime(df[timestamp_column])
    return df[df[timestamp_column] >= cutoff]

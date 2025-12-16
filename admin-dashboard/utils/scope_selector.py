"""
Scope selector component - segmented button style.
"""

import streamlit as st
import pandas as pd
from typing import Tuple, Optional
import random


def render_header_with_scope(
    title: str,
    icon: str,
    users_df: pd.DataFrame,
    key: str,
    allow_global: bool = True,
) -> Tuple[str, Optional[str], Optional[dict]]:
    """
    Render page header with scope selector (segmented buttons) on the right.
    """
    # Build user options first
    user_options = {}
    if not users_df.empty:
        for _, row in users_df.iterrows():
            user_id = str(row.get("id", ""))
            email = row.get("email", "")
            name = row.get("full_name", "")
            display = email if email else (name if name else f"User {user_id[:8]}...")
            user_options[display] = {"id": user_id, "row": row.to_dict()}

    # Header row
    col_title, col_scope = st.columns([2, 1])

    with col_title:
        st.title(f"{icon} {title}")

    with col_scope:
        # Scope options
        if allow_global:
            options = ["🌍 Global", "👤 User", "🎲 Random"]
        else:
            options = ["👤 User", "🎲 Random"]

        # Use segmented control (Streamlit 1.34+) or fall back to selectbox
        try:
            selected = st.segmented_control(
                "Scope",
                options=options,
                default=options[0],
                key=f"{key}_scope_seg",
                label_visibility="collapsed",
            )
        except AttributeError:
            # Fallback for older Streamlit
            selected = st.selectbox(
                "Scope",
                options=options,
                key=f"{key}_scope_sel",
                label_visibility="collapsed",
            )

        if selected is None:
            selected = options[0]

        # Handle Global
        if "Global" in selected:
            return "global", None, None

        if not user_options:
            st.warning("No users")
            return "global", None, None

        # Handle Random
        if "Random" in selected:
            col1, col2 = st.columns([1, 1])
            with col1:
                if st.button("🎲 New", key=f"{key}_rand_btn", use_container_width=True):
                    st.session_state[f"{key}_rand"] = random.choice(list(user_options.keys()))

            if f"{key}_rand" not in st.session_state:
                st.session_state[f"{key}_rand"] = random.choice(list(user_options.keys()))

            sel_display = st.session_state[f"{key}_rand"]
            user_info = user_options.get(sel_display, list(user_options.values())[0])

            with col2:
                st.caption(sel_display[:25])

            return "random", user_info["id"], user_info["row"]

        # Handle User
        else:
            sel_display = st.selectbox(
                "Select user",
                options=list(user_options.keys()),
                key=f"{key}_user_sel",
                label_visibility="collapsed",
            )
            user_info = user_options.get(sel_display)
            if user_info:
                return "user", user_info["id"], user_info["row"]
            return "global", None, None


def get_scope_description(scope_type: str, user_info: Optional[dict] = None) -> str:
    """Get display text for current scope."""
    if scope_type == "global":
        return "All users"
    if user_info:
        email = user_info.get("email", "")
        name = user_info.get("full_name", "")
        if email:
            return email
        elif name:
            return name
        return f"User {str(user_info.get('id', ''))[:8]}..."
    return "Selected user"


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

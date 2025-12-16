"""
Shared time range filter component for dashboard pages.

Provides consistent time filtering across all views.
"""

import streamlit as st
from datetime import datetime, timedelta, timezone
from typing import Tuple, Optional
import pandas as pd


# Time range options with their timedelta values
TIME_RANGES = {
    "1 hour": timedelta(hours=1),
    "12 hours": timedelta(hours=12),
    "24 hours": timedelta(hours=24),
    "7 days": timedelta(days=7),
    "30 days": timedelta(days=30),
    "90 days": timedelta(days=90),
    "All time": None,  # None means no filter
}


def time_range_selector(
    key: str = "time_range",
    default: str = "7 days",
    sidebar: bool = True,
) -> Tuple[Optional[datetime], str]:
    """
    Display a time range selector and return the cutoff datetime.

    Args:
        key: Unique key for the streamlit widget
        default: Default selected time range
        sidebar: If True, display in sidebar; else in main area

    Returns:
        Tuple of (cutoff_datetime, selected_range_label)
        cutoff_datetime is None for "All time"
    """
    container = st.sidebar if sidebar else st

    selected = container.selectbox(
        "Time Range",
        options=list(TIME_RANGES.keys()),
        index=list(TIME_RANGES.keys()).index(default),
        key=key,
    )

    delta = TIME_RANGES[selected]

    if delta is None:
        return None, selected

    cutoff = datetime.now(timezone.utc) - delta
    return cutoff, selected


def filter_dataframe_by_time(
    df: pd.DataFrame,
    cutoff: Optional[datetime],
    timestamp_column: str = "timestamp",
) -> pd.DataFrame:
    """
    Filter a DataFrame by time range.

    Args:
        df: DataFrame to filter
        cutoff: Cutoff datetime (rows before this are excluded)
        timestamp_column: Name of the timestamp column

    Returns:
        Filtered DataFrame
    """
    if df.empty or cutoff is None:
        return df

    # Ensure timestamp column is datetime
    if timestamp_column in df.columns:
        df = df.copy()
        df[timestamp_column] = pd.to_datetime(df[timestamp_column])

        # Filter to only rows after cutoff
        return df[df[timestamp_column] >= cutoff]

    return df


def get_time_range_description(selected: str) -> str:
    """
    Get a human-readable description of the time range.

    Args:
        selected: Selected time range label

    Returns:
        Description string
    """
    if selected == "All time":
        return "all recorded data"
    return f"the last {selected}"

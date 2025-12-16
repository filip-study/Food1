"""
Food1 Admin Analytics Dashboard
"""

import streamlit as st

st.set_page_config(
    page_title="Food1 Admin",
    page_icon="🍽️",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown("""
<style>
    div[data-testid="metric-container"] {
        background-color: #f8fafc;
        border: 1px solid #e2e8f0;
        padding: 0.8rem;
        border-radius: 0.5rem;
    }
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
</style>
""", unsafe_allow_html=True)

st.sidebar.title("🍽️ Food1 Admin")

# Main content
st.title("🍽️ Dashboard")

try:
    from utils.queries import get_activity_stats

    stats = get_activity_stats()

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Users", stats["total_users"])
    col2.metric("Meals", stats["total_meals"])
    col3.metric("Active (7d)", stats["active_users_7d"])
    col4.metric("Avg/User", stats["avg_meals_per_user"])

    st.success("✅ Connected to Supabase")

except Exception as e:
    st.error(f"❌ Connection failed: {str(e)}")
    st.info("Check your `.env` file")

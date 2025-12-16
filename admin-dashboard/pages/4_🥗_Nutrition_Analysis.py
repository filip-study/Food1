"""Nutrition Analysis Dashboard"""

import streamlit as st
import plotly.express as px
import pandas as pd

st.set_page_config(page_title="Nutrition", page_icon="🥗", layout="wide")

try:
    from utils.queries import get_all_users, get_all_meals, get_all_ingredients
    from utils.filters import render_filters, filter_by_user, filter_by_time, get_filter_description

    # Load data
    users_df = get_all_users()
    all_meals_df = get_all_meals()
    all_ingredients_df = get_all_ingredients()

    # Unified filters
    scope, user_id, user_info, time_cutoff, time_label = render_filters(
        title="Nutrition Analysis", icon="🥗", users_df=users_df, key="nutrition", allow_global=True
    )

    # Apply filters
    meals_df = filter_by_user(all_meals_df, scope, user_id)
    meals_df = filter_by_time(meals_df, time_cutoff)

    # Filter ingredients
    if not meals_df.empty and not all_ingredients_df.empty:
        meal_ids = set(meals_df["id"].tolist())
        ingredients_df = all_ingredients_df[all_ingredients_df["meal_id"].isin(meal_ids)]
    else:
        ingredients_df = pd.DataFrame()

    st.caption(f"{get_filter_description(scope, user_info, time_label)} · {len(meals_df)} meals")

    if meals_df.empty:
        st.warning("No data")
        st.stop()

    st.markdown("---")

    # USDA stats
    st.markdown("### USDA Enrichment")
    if not ingredients_df.empty:
        total = len(ingredients_df)
        matched = ingredients_df["usda_fdc_id"].notna().sum()
        unmatched = total - matched
        rate = round(matched / total * 100, 1)
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Ingredients", total)
        col2.metric("Matched", int(matched))
        col3.metric("Unmatched", int(unmatched))
        col4.metric("Success Rate", f"{rate}%")

        # Show top unmatched ingredients
        if unmatched > 0:
            st.markdown("#### ❌ Top Unmatched Ingredients")
            unmatched_df = ingredients_df[ingredients_df["usda_fdc_id"].isna()].copy()
            unmatched_df["name_norm"] = unmatched_df["name"].str.lower().str.strip()
            top_unmatched = unmatched_df["name_norm"].value_counts().head(15).reset_index()
            top_unmatched.columns = ["Ingredient", "Count"]

            col1, col2 = st.columns([2, 1])
            with col1:
                fig = px.bar(top_unmatched, x="Count", y="Ingredient", orientation="h",
                             color="Count", color_continuous_scale="Reds")
                fig.update_layout(height=280, margin=dict(l=20, r=20, t=10, b=20),
                                  yaxis=dict(categoryorder="total ascending"), coloraxis_showscale=False,
                                  xaxis_title="", yaxis_title="")
                st.plotly_chart(fig, use_container_width=True)
            with col2:
                st.dataframe(top_unmatched, hide_index=True, use_container_width=True)

    st.markdown("---")

    # Top ingredients
    st.markdown("### Top Ingredients")
    if not ingredients_df.empty:
        ingredients_df = ingredients_df.copy()
        ingredients_df["name_norm"] = ingredients_df["name"].str.lower().str.strip()
        top = ingredients_df["name_norm"].value_counts().head(12).reset_index()
        top.columns = ["name", "count"]
        fig = px.bar(top, x="count", y="name", orientation="h", color="count", color_continuous_scale="Blues")
        fig.update_layout(height=320, margin=dict(l=20, r=20, t=10, b=20),
                          yaxis=dict(categoryorder="total ascending"), coloraxis_showscale=False, xaxis_title="", yaxis_title="")
        st.plotly_chart(fig, use_container_width=True)

    st.markdown("---")

    # Macros by type
    st.markdown("### Avg Macros by Meal Type")
    if "meal_type" in meals_df.columns:
        meals_df = meals_df.copy()
        for col in ["total_calories", "total_protein_g", "total_carbs_g", "total_fat_g"]:
            if col in meals_df.columns:
                meals_df[col] = pd.to_numeric(meals_df[col], errors="coerce")

        avg = meals_df.groupby("meal_type").agg({
            "total_calories": "mean", "total_protein_g": "mean",
            "total_carbs_g": "mean", "total_fat_g": "mean"
        }).round(1).reset_index()

        if not avg.empty:
            col1, col2 = st.columns([2, 1])
            with col1:
                melted = avg.melt(id_vars=["meal_type"], var_name="macro", value_name="value")
                melted["macro"] = melted["macro"].map({
                    "total_calories": "Cal", "total_protein_g": "Pro",
                    "total_carbs_g": "Carb", "total_fat_g": "Fat"})
                fig = px.bar(melted, x="meal_type", y="value", color="macro", barmode="group",
                             color_discrete_map={"Cal": "#f59e0b", "Pro": "#3b82f6", "Carb": "#10b981", "Fat": "#ef4444"})
                fig.update_layout(height=260, margin=dict(l=20, r=20, t=10, b=20), xaxis_title="", yaxis_title="")
                st.plotly_chart(fig, use_container_width=True)
            with col2:
                display = avg.copy()
                display.columns = ["Type", "Cal", "Pro", "Carb", "Fat"]
                st.dataframe(display, hide_index=True, use_container_width=True)

except Exception as e:
    st.error(f"Error: {e}")
    import traceback
    st.code(traceback.format_exc())

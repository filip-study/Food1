"""User Explorer - Compact view for individual users"""

import streamlit as st
import pandas as pd

st.set_page_config(page_title="User Explorer", page_icon="👤", layout="wide")

try:
    from utils.queries import get_all_users, get_user_meals, get_meal_ingredients, get_user_by_id
    from utils.filters import render_filters, filter_by_time

    users_df = get_all_users()
    if users_df.empty:
        st.warning("No users")
        st.stop()

    scope, user_id, user_info, time_cutoff, time_label = render_filters(
        title="User Explorer", icon="👤", users_df=users_df, key="explorer", allow_global=False
    )

    if not user_id:
        st.info("Select a user")
        st.stop()

    user = get_user_by_id(user_id)
    user_meals = get_user_meals(user_id)
    user_meals = filter_by_time(user_meals, time_cutoff)

    # User info
    if user:
        email = user.get("email") or "—"
        name = user.get("full_name") or ""
        status = user.get("subscription_type") or "free"
        joined = str(user.get("created_at", ""))[:10]
        info = f"**{email}**" + (f" ({name})" if name else "") + f" · {status} · joined {joined}"
        st.caption(info)

    if user_meals.empty:
        st.info("No meals in this time range")
        st.stop()

    # Prepare data
    user_meals = user_meals.copy()
    user_meals["timestamp"] = pd.to_datetime(user_meals["timestamp"])
    user_meals = user_meals.sort_values("timestamp", ascending=False)
    user_meals["date"] = user_meals["timestamp"].dt.date
    user_meals["time_str"] = user_meals["timestamp"].dt.strftime("%H:%M")

    # Stats
    photos_count = user_meals["photo_thumbnail_url"].notna().sum()
    avg_cal = user_meals["total_calories"].mean()
    st.markdown(f"**{len(user_meals)}** meals · **{photos_count}** photos · **{avg_cal:.0f}** avg cal")
    st.markdown("---")

    # Selected meal index
    if "selected_meal_idx" not in st.session_state:
        st.session_state.selected_meal_idx = 0

    meal_list = user_meals.head(30).reset_index(drop=True)

    col_list, col_detail = st.columns([1.2, 1])

    with col_list:
        # Group by date
        current_date = None

        for i, meal in meal_list.iterrows():
            meal_date = meal["date"]

            # Day header
            if meal_date != current_date:
                current_date = meal_date
                day_label = pd.Timestamp(meal_date).strftime("%a, %b %d")
                st.markdown(f"**{day_label}**")

            # Meal button
            has_photo = pd.notna(meal.get("photo_thumbnail_url"))
            has_prompt = pd.notna(meal.get("user_prompt"))
            meal_name = meal.get("name") or "Unnamed meal"
            time_str = meal["time_str"]

            # Icon: 📷 for photo, ✏️ for text entry, space for neither
            if has_photo:
                icon = "📷"
            elif has_prompt:
                icon = "✏️"
            else:
                icon = "　"  # wide space for alignment
            label = f"{icon} {time_str}  {meal_name}"

            is_selected = st.session_state.selected_meal_idx == i

            if st.button(
                label,
                key=f"m_{i}",
                use_container_width=True,
                type="primary" if is_selected else "secondary"
            ):
                st.session_state.selected_meal_idx = i
                st.rerun()

    with col_detail:
        st.markdown("##### Details")

        idx = st.session_state.selected_meal_idx
        if idx < len(meal_list):
            meal = meal_list.iloc[idx]

            # Photo
            if pd.notna(meal.get("photo_thumbnail_url")):
                st.image(meal["photo_thumbnail_url"], use_container_width=True)

            # Name and type
            meal_name = meal.get("name") or "Unnamed"
            meal_type = meal.get("meal_type") or ""
            st.markdown(f"**{meal_name}**")
            st.caption(f"{meal_type} · {meal['timestamp'].strftime('%Y-%m-%d %H:%M')}")

            # Macros
            c1, c2, c3, c4 = st.columns(4)
            cal = meal.get("total_calories")
            c1.metric("Cal", f"{cal:.0f}" if pd.notna(cal) else "—")
            c2.metric("Pro", f"{meal.get('total_protein_g', 0):.1f}g")
            c3.metric("Carb", f"{meal.get('total_carbs_g', 0):.1f}g")
            c4.metric("Fat", f"{meal.get('total_fat_g', 0):.1f}g")

            # User prompt (for text-based entries)
            user_prompt = meal.get("user_prompt")
            if user_prompt and pd.notna(user_prompt):
                st.markdown("**User prompt:**")
                st.info(f'"{user_prompt}"')

            # Ingredients
            meal_id = meal.get("id")
            if meal_id:
                ings = get_meal_ingredients(str(meal_id))
                if not ings.empty:
                    st.markdown("**Ingredients:**")
                    for _, ing in ings.iterrows():
                        qty = ing.get("quantity_g")
                        qty_str = f" ({qty:.0f}g)" if pd.notna(qty) and qty else ""
                        usda = "✓" if pd.notna(ing.get("usda_fdc_id")) else "✗"
                        st.caption(f"{usda} {ing['name']}{qty_str}")

    # Photo gallery
    st.markdown("---")
    with st.expander(f"📷 All Photos ({photos_count})"):
        with_photos = user_meals[user_meals["photo_thumbnail_url"].notna()]
        if with_photos.empty:
            st.caption("No photos")
        else:
            cols = st.columns(6)
            for i, (_, m) in enumerate(with_photos.head(18).iterrows()):
                with cols[i % 6]:
                    st.image(m["photo_thumbnail_url"], use_container_width=True)

except Exception as e:
    st.error(f"Error: {e}")
    import traceback
    st.code(traceback.format_exc())

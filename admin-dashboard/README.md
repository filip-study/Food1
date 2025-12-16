# Food1 Admin Analytics Dashboard

A local Streamlit dashboard for analyzing app usage patterns, viewing user activity, and monitoring system health.

## Features

- **Global Overview** - Aggregate metrics, user counts, activity trends
- **User Behavior** - Activity heatmaps, meal type distribution, patterns by time
- **User Drill-Down** - View individual users, their photos, timeline, and nutrition data
- **Meal Insights** - Top ingredients, average macros, USDA enrichment stats
- **App Health** - Sync status, photo upload rates, error monitoring

## Quick Start

```bash
# Navigate to dashboard directory
cd admin-dashboard

# Install dependencies
pip install -r requirements.txt

# Configure credentials
cp .env.example .env
# Edit .env with your Supabase credentials

# Run the dashboard
streamlit run app.py
```

The dashboard will open at `http://localhost:8501`

## Configuration

Edit `.env` with your Supabase credentials:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

**Where to find the Service Role Key:**
1. Go to Supabase Dashboard
2. Select your project
3. Navigate to: Project Settings > API
4. Copy the `service_role` key (NOT the `anon` key)

**Security Note:** The service role key bypasses Row Level Security (RLS). Never expose this key publicly or commit it to version control.

## Pages

| Page | Description |
|------|-------------|
| Overview | Total users, meals, daily activity chart |
| User Behavior | Activity heatmap, meal types, timing patterns |
| User Drill-Down | Individual user analysis with photos and timeline |
| Meal Insights | Ingredient frequency, macros by meal type |
| App Health | Sync status, photo rates, error monitoring |

## Tech Stack

- **Streamlit** - Dashboard framework
- **Supabase** - Database backend
- **Plotly** - Interactive charts
- **Pandas** - Data manipulation

## Security

- Runs locally only (not deployed)
- Uses service role key for admin access
- Credentials stored in `.env` (gitignored)
- No modifications to production data

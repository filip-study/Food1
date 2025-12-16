"""
Supabase client for admin dashboard.

Uses Service Role Key to bypass RLS and access all user data.
This is admin-only functionality - never expose this key publicly.
"""

import os
from functools import lru_cache
from dotenv import load_dotenv
from supabase import create_client, Client

# Load environment variables from .env file
load_dotenv()


@lru_cache(maxsize=1)
def get_supabase_client() -> Client:
    """
    Create and cache Supabase client with service role key.

    Service role key bypasses Row Level Security (RLS) policies,
    allowing admin access to all user data.
    """
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not url or not key:
        raise ValueError(
            "Missing Supabase credentials. "
            "Copy .env.example to .env and fill in your credentials."
        )

    return create_client(url, key)


def get_storage_url(bucket: str, path: str) -> str:
    """
    Construct a public storage URL for a file.

    Args:
        bucket: Storage bucket name (e.g., 'meal-photos')
        path: File path within the bucket

    Returns:
        Full public URL to the file
    """
    url = os.getenv("SUPABASE_URL")
    return f"{url}/storage/v1/object/public/{bucket}/{path}"

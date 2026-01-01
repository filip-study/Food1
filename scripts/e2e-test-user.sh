#!/bin/bash
#
# e2e-test-user.sh
#
# Creates or deletes a pre-confirmed test user via Supabase Admin API.
# Used by E2E tests to have a real user account to test with.
#
# USAGE:
#   ./scripts/e2e-test-user.sh create   # Creates user, outputs credentials
#   ./scripts/e2e-test-user.sh delete   # Deletes the test user
#
# REQUIRED ENVIRONMENT VARIABLES:
#   SUPABASE_URL          - Your Supabase project URL
#   SUPABASE_SERVICE_KEY  - Service role key (NOT anon key)
#
# The script generates a unique test email for each run to avoid conflicts.
#

set -e

ACTION="${1:-create}"
TEST_EMAIL="${TEST_USER_EMAIL:-e2e-test-$(date +%s)@test.prismae.net}"
TEST_PASSWORD="${TEST_USER_PASSWORD:-TestPassword123!}"

# Validate required env vars
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo "ERROR: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set"
    exit 1
fi

# Supabase Admin API endpoint
ADMIN_API="$SUPABASE_URL/auth/v1/admin"

case "$ACTION" in
    create)
        echo "Creating test user: $TEST_EMAIL"

        # Create user via Admin API (automatically confirmed)
        RESPONSE=$(curl -s -X POST "$ADMIN_API/users" \
            -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
            -H "apikey: $SUPABASE_SERVICE_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"email\": \"$TEST_EMAIL\",
                \"password\": \"$TEST_PASSWORD\",
                \"email_confirm\": true
            }")

        # Check for error
        if echo "$RESPONSE" | grep -q '"error"'; then
            echo "ERROR: Failed to create user"
            echo "$RESPONSE"
            exit 1
        fi

        # Extract user ID
        USER_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -z "$USER_ID" ]; then
            echo "ERROR: Could not extract user ID from response"
            echo "$RESPONSE"
            exit 1
        fi

        echo "SUCCESS: Created user $USER_ID"
        echo ""
        echo "# Add these to your environment or GitHub Secrets:"
        echo "export TEST_USER_EMAIL='$TEST_EMAIL'"
        echo "export TEST_USER_PASSWORD='$TEST_PASSWORD'"
        echo "export TEST_USER_ID='$USER_ID'"

        # Output for GitHub Actions
        if [ -n "$GITHUB_OUTPUT" ]; then
            echo "test_email=$TEST_EMAIL" >> "$GITHUB_OUTPUT"
            echo "test_password=$TEST_PASSWORD" >> "$GITHUB_OUTPUT"
            echo "test_user_id=$USER_ID" >> "$GITHUB_OUTPUT"
        fi
        ;;

    delete)
        # Need user ID to delete - try to find by email first
        if [ -z "$TEST_USER_ID" ]; then
            echo "Looking up user by email: $TEST_EMAIL"

            # List users and find by email
            RESPONSE=$(curl -s -X GET "$ADMIN_API/users" \
                -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
                -H "apikey: $SUPABASE_SERVICE_KEY")

            TEST_USER_ID=$(echo "$RESPONSE" | grep -B5 "\"email\":\"$TEST_EMAIL\"" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        fi

        if [ -z "$TEST_USER_ID" ]; then
            echo "WARNING: Could not find user to delete (may already be deleted)"
            exit 0
        fi

        echo "Deleting test user: $TEST_USER_ID"

        # Delete user via Admin API
        RESPONSE=$(curl -s -X DELETE "$ADMIN_API/users/$TEST_USER_ID" \
            -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
            -H "apikey: $SUPABASE_SERVICE_KEY")

        echo "SUCCESS: Deleted user $TEST_USER_ID"
        ;;

    *)
        echo "Usage: $0 [create|delete]"
        exit 1
        ;;
esac

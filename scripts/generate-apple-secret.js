#!/usr/bin/env node
//
// generate-apple-secret.js
//
// Generates JWT secret for Supabase Apple Sign In configuration
// Usage: node generate-apple-secret.js
//

const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

// Configuration
const KEY_ID = 'ZLLU5U5574'; // From your .p8 filename
const TEAM_ID = 'UJ4482ZF9C'; // Your Apple Developer Team ID
const SERVICE_ID = 'com.filipolszak.Food1.signin'; // Your Service ID
const KEY_FILE = path.join(process.env.HOME, 'Downloads', 'AuthKey_ZLLU5U5574.p8');

// Validate configuration
if (!TEAM_ID) {
    console.error('❌ Error: TEAM_ID is not set!');
    console.log('\nTo find your Team ID:');
    console.log('1. Go to https://developer.apple.com/account');
    console.log('2. Look at the top right corner');
    console.log('3. Copy your Team ID (format: ABC123DEFG)');
    console.log('4. Update the TEAM_ID variable in this script\n');
    process.exit(1);
}

// Check if key file exists
if (!fs.existsSync(KEY_FILE)) {
    console.error(`❌ Error: Key file not found at ${KEY_FILE}`);
    console.log('\nMake sure AuthKey_ZLLU5U5574.p8 is in your Downloads folder\n');
    process.exit(1);
}

try {
    // Read the private key
    const privateKey = fs.readFileSync(KEY_FILE, 'utf8');

    // Generate JWT
    const token = jwt.sign(
        {}, // Empty payload
        privateKey,
        {
            algorithm: 'ES256',
            expiresIn: '180d', // 6 months (maximum allowed)
            audience: 'https://appleid.apple.com',
            issuer: TEAM_ID,
            subject: SERVICE_ID,
            keyid: KEY_ID
        }
    );

    console.log('✅ Apple Sign In JWT Secret Generated!\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('Copy this JWT and paste it into Supabase Dashboard:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log(token);
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('Configuration Summary:');
    console.log(`  Key ID:      ${KEY_ID}`);
    console.log(`  Team ID:     ${TEAM_ID}`);
    console.log(`  Service ID:  ${SERVICE_ID}`);
    console.log(`  Expires:     180 days from now`);
    console.log('\nIn Supabase Dashboard → Authentication → Providers → Apple:');
    console.log(`  1. Apple client ID:  ${SERVICE_ID}`);
    console.log(`  2. Apple secret key: [paste JWT above]`);
    console.log(`  3. Redirect URL:     com.filipolszak.food1://auth/callback`);
    console.log('\n');

} catch (error) {
    console.error('❌ Error generating JWT:', error.message);

    if (error.message.includes('jsonwebtoken')) {
        console.log('\n📦 Missing dependency! Install it with:');
        console.log('   cd scripts && npm install jsonwebtoken\n');
    }

    process.exit(1);
}

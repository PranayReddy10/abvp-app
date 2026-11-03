<?php

return [

    /*
    | One-time passwords sent by SMS for sign-in.
    */
    'otp' => [
        'length' => 6,
        'ttl_minutes' => (int) env('OTP_TTL_MINUTES', 5),
        'max_attempts' => 5,
        // Only honoured when APP_ENV is local or testing. Never set in production.
        'fixed_code' => env('OTP_FIXED_CODE'),
    ],

    'sms' => [
        // "log" writes the message to the Laravel log (development).
        // "msg91" sends through MSG91's Flow API (production, DLT-registered).
        'driver' => env('SMS_DRIVER', 'log'),
        'msg91' => [
            'auth_key' => env('MSG91_AUTH_KEY'),
            'otp_template_id' => env('MSG91_OTP_TEMPLATE_ID'),
        ],
    ],

    // Disk for member photos and documents. Use "spaces" in production.
    'media_disk' => env('MEDIA_DISK', 'local'),

    // Secret used to sign member QR tokens. Falls back to APP_KEY.
    'qr_secret' => env('QR_SECRET'),

    /*
    | Access roles. A role is always held inside a scope (an organisational unit
    | and everything below it). "rank" decides who may assign which role:
    | an admin can only assign roles ranked lower than their own.
    */
    'roles' => [
        'super_admin' => ['label' => 'Super Admin', 'rank' => 100],
        'national_admin' => ['label' => 'National Admin', 'rank' => 90],
        'state_admin' => ['label' => 'State Admin', 'rank' => 70],
        'district_admin' => ['label' => 'District Admin', 'rank' => 50],
        'vibhag_admin' => ['label' => 'Vibhag Admin', 'rank' => 40],
        'verification_officer' => ['label' => 'Verification Officer', 'rank' => 30],
    ],

    'permissions' => [
        'admin.access' => ['super_admin', 'national_admin', 'state_admin', 'district_admin', 'vibhag_admin', 'verification_officer'],
        'members.view' => ['super_admin', 'national_admin', 'state_admin', 'district_admin', 'vibhag_admin', 'verification_officer'],
        'members.review' => ['super_admin', 'national_admin', 'state_admin', 'district_admin', 'verification_officer'],
        'org.manage' => ['super_admin', 'national_admin', 'state_admin'],
        'vibhags.manage' => ['super_admin', 'national_admin'],
        'roles.assign' => ['super_admin', 'national_admin', 'state_admin', 'district_admin'],
        'responsibilities.manage' => ['super_admin', 'national_admin', 'state_admin', 'district_admin'],
        'audit.view' => ['super_admin', 'national_admin'],
    ],

    'unit_types' => ['national', 'state', 'district', 'unit'],

    // Who can see a profile field. Members choose per field.
    'privacy_levels' => ['nobody', 'office_bearers', 'my_unit', 'members'],
    'privacy_defaults' => [
        'mobile' => 'nobody',
        'email' => 'office_bearers',
        'institution' => 'members',
        'date_of_birth' => 'nobody',
    ],
];

<?php

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    // The admin panel's own domain. The mobile app is not a browser and needs no CORS.
    // The admin panel and the public website (abvpconnect.org) call the API from the browser.
    'allowed_origins' => array_values(array_filter(array_map('trim', array_merge(
        explode(',', (string) env('ADMIN_URL', 'http://localhost:5173')),
        explode(',', (string) env('WEB_URL', 'http://localhost:5175')),
    )))),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => ['X-Request-Id'],
    'max_age' => 3600,
    'supports_credentials' => false,
];

<?php

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    // The admin panel's own domain. The mobile app is not a browser and needs no CORS.
    'allowed_origins' => array_filter(explode(',', env('ADMIN_URL', 'http://localhost:5173'))),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => ['X-Request-Id'],
    'max_age' => 3600,
    'supports_credentials' => false,
];

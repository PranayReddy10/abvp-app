<?php

namespace App\Support;

use RuntimeException;

/** A business-rule failure with a stable, machine-readable code. */
class ApiException extends RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status = 422,
    ) {
        parent::__construct($message);
    }
}

<?php

use App\Http\Middleware\AssignRequestId;
use App\Support\ApiException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Routing\Exceptions\InvalidSignatureException;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->api(prepend: [AssignRequestId::class]);
        // Behind Hostinger's proxy layer.
        $middleware->trustProxies(at: '*');
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Every API error uses the same envelope: { success: false, error: { code, message } }.
        $exceptions->render(function (Throwable $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            [$status, $code, $message, $fields] = match (true) {
                $e instanceof ApiException => [$e->status, $e->errorCode, $e->getMessage(), null],
                $e instanceof ValidationException => [422, 'VALIDATION_FAILED', $e->validator->errors()->first(), $e->errors()],
                $e instanceof AuthenticationException => [401, 'UNAUTHENTICATED', 'Sign in to continue.', null],
                $e instanceof ThrottleRequestsException => [429, 'RATE_LIMITED', 'Too many requests. Wait a moment and try again.', null],
                $e instanceof InvalidSignatureException => [403, 'LINK_EXPIRED', 'This link has expired.', null],
                $e instanceof ModelNotFoundException, $e instanceof NotFoundHttpException => [404, 'NOT_FOUND', 'Not found.', null],
                $e instanceof HttpExceptionInterface => [$e->getStatusCode(), 'HTTP_'.$e->getStatusCode(), $e->getMessage() ?: 'Request failed.', null],
                default => [500, 'SERVER_ERROR', config('app.debug') ? $e->getMessage() : 'Something went wrong on our side.', null],
            };

            return response()->json(array_filter([
                'success' => false,
                'error' => array_filter(['code' => $code, 'message' => $message, 'fields' => $fields]),
                'meta' => ['request_id' => $request->attributes->get('request_id')],
            ]), $status);
        });
    })->create();

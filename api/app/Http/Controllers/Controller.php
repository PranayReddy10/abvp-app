<?php

namespace App\Http\Controllers;

use App\Services\AccessControl;
use App\Support\ApiException;
use Illuminate\Http\JsonResponse;
use Illuminate\Pagination\LengthAwarePaginator;

abstract class Controller
{
    /** Standard envelope: { success, data, meta }. */
    protected function ok(mixed $data = null, int $status = 200, array $meta = []): JsonResponse
    {
        if ($data instanceof \Illuminate\Http\Resources\Json\AnonymousResourceCollection
            && $data->resource instanceof LengthAwarePaginator) {
            $p = $data->resource;
            $meta += ['page' => $p->currentPage(), 'per_page' => $p->perPage(), 'total' => $p->total(), 'last_page' => $p->lastPage()];
            $data = $data->collection;
        }

        return response()->json([
            'success' => true,
            'data' => $data,
            'meta' => $meta + ['request_id' => request()->attributes->get('request_id')],
        ], $status);
    }

    protected function authorizeIn(string $permission, $unit = null): void
    {
        $access = app(AccessControl::class);
        $allowed = $unit === null ? $access->can(request()->user(), $permission) : $access->canIn(request()->user(), $permission, $unit);

        if (! $allowed) {
            throw new ApiException('FORBIDDEN_SCOPE', 'You are not authorised for this action in this area.', 403);
        }
    }
}

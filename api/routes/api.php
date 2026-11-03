<?php

use App\Http\Controllers\Api\V1\Admin;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\DirectoryController;
use App\Http\Controllers\Api\V1\MediaController;
use App\Http\Controllers\Api\V1\MembershipController;
use App\Http\Controllers\Api\V1\OrganisationController;
use App\Http\Controllers\Api\V1\ProfileController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // Sign-in
    Route::middleware('throttle:otp')->group(function () {
        Route::post('auth/send-otp', [AuthController::class, 'sendOtp']);
        Route::post('auth/verify-otp', [AuthController::class, 'verifyOtp']);
    });

    // Lookups for the application form
    Route::get('org/units', [OrganisationController::class, 'units']);
    Route::get('vibhags', [OrganisationController::class, 'vibhags']);

    // Private photos, reached only through signed links
    Route::get('media/photos/{profile}', [MediaController::class, 'photo'])
        ->middleware('signed')->name('media.photo');

    Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/logout', [AuthController::class, 'logout']);

        Route::get('me/profile', [ProfileController::class, 'show']);
        Route::patch('me/profile', [ProfileController::class, 'update']);
        Route::put('me/privacy', [ProfileController::class, 'privacy']);
        Route::post('me/photo', [ProfileController::class, 'photo']);
        Route::get('me/qr', [MembershipController::class, 'qr']);

        Route::post('membership/application', [MembershipController::class, 'submit']);

        Route::get('members/{memberId}', [DirectoryController::class, 'show']);
        Route::post('qr/verify', [DirectoryController::class, 'verifyQr']);

        Route::prefix('admin')->group(function () {
            Route::get('dashboard', Admin\DashboardController::class);

            Route::get('applications', [Admin\ApplicationController::class, 'index']);
            Route::get('applications/{application}', [Admin\ApplicationController::class, 'show']);
            Route::post('applications/{application}/approve', [Admin\ApplicationController::class, 'approve']);
            Route::post('applications/{application}/return', [Admin\ApplicationController::class, 'returnForCorrection']);
            Route::post('applications/{application}/reject', [Admin\ApplicationController::class, 'reject']);

            Route::get('members', [Admin\MemberController::class, 'index']);
            Route::get('members/{profile}', [Admin\MemberController::class, 'show']);

            Route::get('vibhags', [Admin\VibhagController::class, 'index']);
            Route::post('vibhags', [Admin\VibhagController::class, 'store']);
            Route::patch('vibhags/{vibhag}', [Admin\VibhagController::class, 'update']);

            Route::post('org-units', [Admin\OrgUnitController::class, 'store']);
            Route::patch('org-units/{orgUnit}', [Admin\OrgUnitController::class, 'update']);

            Route::get('role-assignments', [Admin\RoleAssignmentController::class, 'index']);
            Route::post('role-assignments', [Admin\RoleAssignmentController::class, 'store']);
            Route::delete('role-assignments/{roleAssignment}', [Admin\RoleAssignmentController::class, 'destroy']);

            Route::post('responsibilities', [Admin\ResponsibilityController::class, 'store']);
            Route::patch('responsibilities/{responsibility}', [Admin\ResponsibilityController::class, 'update']);

            Route::get('audit-logs', [Admin\AuditLogController::class, 'index']);
        });
    });
});

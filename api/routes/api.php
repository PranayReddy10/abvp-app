<?php

use App\Http\Controllers\Api\V1\Admin;
use App\Http\Controllers\Api\V1\ActivityReportController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CircularController;
use App\Http\Controllers\Api\V1\DirectoryController;
use App\Http\Controllers\Api\V1\MediaController;
use App\Http\Controllers\Api\V1\MeetingController;
use App\Http\Controllers\Api\V1\MembershipController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\OrganisationController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\VibhagSpaceController;
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
    Route::get('media/circulars/{circular}', [MediaController::class, 'circular'])
        ->middleware('signed')->name('media.circular');
    Route::get('media/reports/{report}/{index}', [MediaController::class, 'report'])
        ->whereNumber('index')->middleware('signed')->name('media.report');

    Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/logout', [AuthController::class, 'logout']);

        Route::get('me/profile', [ProfileController::class, 'show']);
        Route::patch('me/profile', [ProfileController::class, 'update']);
        Route::put('me/privacy', [ProfileController::class, 'privacy']);
        Route::post('me/photo', [ProfileController::class, 'photo']);
        Route::get('me/qr', [MembershipController::class, 'qr']);

        Route::post('membership/application', [MembershipController::class, 'submit']);

        Route::get('directory', [DirectoryController::class, 'search']);
        Route::get('members/{memberId}', [DirectoryController::class, 'show']);

        // Phase 2: Vibhag spaces
        Route::get('spaces', [VibhagSpaceController::class, 'index']);
        Route::get('spaces/{vibhag}', [VibhagSpaceController::class, 'show']);
        Route::post('spaces/{vibhag}/join', [VibhagSpaceController::class, 'join']);
        Route::delete('spaces/{vibhag}/join', [VibhagSpaceController::class, 'leave']);
        Route::get('spaces/{vibhag}/posts', [VibhagSpaceController::class, 'posts']);
        Route::post('spaces/{vibhag}/posts', [VibhagSpaceController::class, 'storePost']);
        Route::get('spaces/{vibhag}/members', [VibhagSpaceController::class, 'members']);

        // Meetings and calls
        Route::get('meetings', [MeetingController::class, 'index']);
        Route::post('meetings', [MeetingController::class, 'store']);
        Route::get('meetings/{meeting}', [MeetingController::class, 'show']);
        Route::post('meetings/{meeting}/rsvp', [MeetingController::class, 'rsvp']);
        Route::post('meetings/{meeting}/join', [MeetingController::class, 'join']);
        Route::post('meetings/{meeting}/cancel', [MeetingController::class, 'cancel']);
        Route::put('meetings/{meeting}/minutes', [MeetingController::class, 'minutes']);
        Route::get('meetings/{meeting}/calendar.ics', [MeetingController::class, 'ics']);
        Route::get('me/action-items', [MeetingController::class, 'myActionItems']);
        Route::post('action-items/{actionItem}/done', [MeetingController::class, 'completeActionItem']);

        // Circulars, activity reports, notifications
        Route::get('circulars', [CircularController::class, 'index']);
        Route::get('circulars/{id}', [CircularController::class, 'show'])->whereNumber('id');
        Route::get('activity-reports/types', [ActivityReportController::class, 'types']);
        Route::post('activity-reports', [ActivityReportController::class, 'store']);
        Route::get('me/activity-reports', [ActivityReportController::class, 'mine']);
        Route::get('notifications', [NotificationController::class, 'index']);
        Route::post('notifications/read-all', [NotificationController::class, 'readAll']);
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

            Route::get('analytics', Admin\AnalyticsController::class);
            Route::get('circulars', [Admin\CircularController::class, 'index']);
            Route::post('circulars', [Admin\CircularController::class, 'store']);
            Route::post('circulars/{circular}/remind', [Admin\CircularController::class, 'remind']);
            Route::get('meetings', [Admin\MeetingController::class, 'index']);
            Route::get('activity-reports', [Admin\ActivityReportController::class, 'index']);
        });
    });
});

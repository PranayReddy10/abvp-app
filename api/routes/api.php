<?php

use App\Http\Controllers\Api\V1\Admin;
use App\Http\Controllers\Api\V1\ActivityReportController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CheckInController;
use App\Http\Controllers\Api\V1\CircularController;
use App\Http\Controllers\Api\V1\EventController;
use App\Http\Controllers\Api\V1\FeedController;
use App\Http\Controllers\Api\V1\DirectoryController;
use App\Http\Controllers\Api\V1\LogisticsController;
use App\Http\Controllers\Api\V1\MediaController;
use App\Http\Controllers\Api\V1\MeetingController;
use App\Http\Controllers\Api\V1\MembershipController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\OperationsController;
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
    Route::get('media/posts/{post}/{index}', [MediaController::class, 'post'])
        ->whereNumber('index')->middleware('signed')->name('media.post');
    Route::get('media/events/{event}/cover', [MediaController::class, 'eventCover'])
        ->middleware('signed')->name('media.event');

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

        // Phase 3: events, passes, gate check-in
        Route::get('events', [EventController::class, 'index']);
        Route::get('events/{event}', [EventController::class, 'show']);
        Route::post('events/{event}/register', [EventController::class, 'register']);
        Route::post('events/{event}/cancel-registration', [EventController::class, 'cancel']);
        Route::get('me/passes', [EventController::class, 'passes']);
        Route::get('me/check-in-events', [CheckInController::class, 'myEvents']);
        Route::get('events/{event}/roster', [CheckInController::class, 'roster']);
        Route::get('events/{event}/check-in/search', [CheckInController::class, 'search']);
        Route::post('events/{event}/check-in', [CheckInController::class, 'scan']);
        Route::post('events/{event}/check-in/batch', [CheckInController::class, 'batch']);
        Route::post('events/{event}/registrations/{registration}/check-in', [CheckInController::class, 'manual']);

        // Phase 4: event-day operations
        Route::get('me/duties', [OperationsController::class, 'myDuties']);
        Route::post('duties/{duty}/respond', [OperationsController::class, 'respond']);
        Route::post('duties/{duty}/progress', [OperationsController::class, 'progress']);
        Route::get('me/teams', [OperationsController::class, 'myTeams']);
        Route::get('events/{event}/announcements', [OperationsController::class, 'announcements']);
        Route::post('events/{event}/help', [OperationsController::class, 'raiseHelp']);
        Route::get('me/help', [OperationsController::class, 'myHelp']);
        Route::post('help/{help}/reply', [OperationsController::class, 'reply']);

        // Phase 5: logistics and opt-in live location
        Route::get('events/{event}/my-logistics', [LogisticsController::class, 'mine']);
        Route::put('events/{event}/travel', [LogisticsController::class, 'saveTravel']);
        Route::get('events/{event}/meal-sessions', [LogisticsController::class, 'meals']);
        Route::post('events/{event}/meal-sessions/{meal}/serve', [LogisticsController::class, 'serve']);
        Route::post('events/{event}/location-sessions', [LogisticsController::class, 'startSharing']);
        Route::post('location-sessions/{session}/points', [LogisticsController::class, 'point'])->middleware('throttle:20,1');
        Route::post('location-sessions/{session}/stop', [LogisticsController::class, 'stopSharing']);
        Route::get('events/{event}/team-locations', [LogisticsController::class, 'teamLocations']);

        // Phase 6: community feed
        Route::get('feed', [FeedController::class, 'feed']);
        Route::get('feed/trending', [FeedController::class, 'trending']);
        Route::post('posts', [FeedController::class, 'store'])->middleware('throttle:posts');
        Route::get('posts/{id}', [FeedController::class, 'show'])->whereNumber('id');
        Route::delete('posts/{post}', [FeedController::class, 'destroy']);
        Route::post('posts/{id}/like', [FeedController::class, 'like'])->whereNumber('id');
        Route::post('posts/{id}/comments', [FeedController::class, 'comment'])->whereNumber('id')->middleware('throttle:posts');
        Route::delete('comments/{comment}', [FeedController::class, 'deleteComment']);
        Route::post('posts/{id}/report', [FeedController::class, 'report'])->whereNumber('id');
        Route::post('members/{memberId}/follow', [FeedController::class, 'follow']);
        Route::get('members/{memberId}/posts', [FeedController::class, 'memberPosts']);
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
            Route::post('members/{profile}/verify', [Admin\MemberController::class, 'verify']);

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

            Route::get('events', [Admin\EventController::class, 'index']);
            Route::post('events', [Admin\EventController::class, 'store']);
            Route::get('events/{event}', [Admin\EventController::class, 'show']);
            Route::patch('events/{event}', [Admin\EventController::class, 'update']);
            Route::post('events/{event}/publish', [Admin\EventController::class, 'publish']);
            Route::post('events/{event}/cancel', [Admin\EventController::class, 'cancel']);
            Route::get('events/{event}/registrations', [Admin\EventController::class, 'registrations']);
            Route::post('events/{event}/registrations/{registration}/decide', [Admin\EventController::class, 'decide']);
            Route::post('events/{event}/guests', [Admin\EventController::class, 'inviteGuest']);
            Route::get('events/{event}/staff', [Admin\EventController::class, 'staff']);
            Route::post('events/{event}/staff', [Admin\EventController::class, 'addStaff']);
            Route::delete('events/{event}/staff/{staff}', [Admin\EventController::class, 'removeStaff']);
            Route::get('events/{event}/live', [Admin\EventController::class, 'live']);
            Route::get('events/{event}/teams', [Admin\OperationsController::class, 'teams']);
            Route::post('events/{event}/teams', [Admin\OperationsController::class, 'storeTeam']);
            Route::delete('events/{event}/teams/{team}', [Admin\OperationsController::class, 'deleteTeam']);
            Route::get('events/{event}/duties', [Admin\OperationsController::class, 'duties']);
            Route::post('events/{event}/duties', [Admin\OperationsController::class, 'assign']);
            Route::patch('events/{event}/duties/{duty}', [Admin\OperationsController::class, 'updateDuty']);
            Route::delete('events/{event}/duties/{duty}', [Admin\OperationsController::class, 'cancelDuty']);
            Route::get('events/{event}/help', [Admin\OperationsController::class, 'help']);
            Route::patch('events/{event}/help/{help}', [Admin\OperationsController::class, 'updateHelp']);
            Route::get('events/{event}/announcements', [Admin\OperationsController::class, 'announcements']);
            Route::post('events/{event}/announcements', [Admin\OperationsController::class, 'announce']);
            Route::get('events/{event}/logistics', [Admin\LogisticsController::class, 'overview']);
            Route::post('events/{event}/cover', [Admin\EventController::class, 'cover']);
            Route::get('moderation', [Admin\ModerationController::class, 'index']);
            Route::post('moderation/posts/{post}', [Admin\ModerationController::class, 'act']);
            Route::get('settings/storage', [Admin\SettingsController::class, 'storage']);
            Route::put('settings/storage', [Admin\SettingsController::class, 'update']);
            Route::post('settings/storage/test', [Admin\SettingsController::class, 'test']);
            Route::post('settings/storage/copy', [Admin\SettingsController::class, 'copyToSpaces']);
            Route::post('events/{event}/stays', [Admin\LogisticsController::class, 'storeStay']);
            Route::delete('events/{event}/stays/{stay}', [Admin\LogisticsController::class, 'deleteStay']);
            Route::post('events/{event}/rooms/{room}/allocate', [Admin\LogisticsController::class, 'allocate']);
            Route::post('events/{event}/stays/auto-allocate', [Admin\LogisticsController::class, 'autoAllocate']);
            Route::post('events/{event}/allocations/{allocation}', [Admin\LogisticsController::class, 'stayAction']);
            Route::post('events/{event}/meal-sessions', [Admin\LogisticsController::class, 'storeMeal']);
            Route::delete('events/{event}/meal-sessions/{meal}', [Admin\LogisticsController::class, 'deleteMeal']);
            Route::post('events/{event}/vehicles', [Admin\LogisticsController::class, 'storeVehicle']);
            Route::delete('events/{event}/vehicles/{vehicle}', [Admin\LogisticsController::class, 'deleteVehicle']);
            Route::get('events/{event}/arrivals', [Admin\LogisticsController::class, 'arrivals']);
            Route::post('events/{event}/arrivals/assign', [Admin\LogisticsController::class, 'assignVehicle']);
            Route::post('events/{event}/arrivals/{travel}/picked-up', [Admin\LogisticsController::class, 'pickedUp']);
        });
    });
});

<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\ApplicationEvent;
use App\Models\MemberProfile;
use App\Models\MembershipApplication as Application;
use App\Models\OrgUnit;
use App\Models\Post;
use App\Services\AccessControl;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function __invoke(Request $request, AccessControl $access)
    {
        $user = $request->user();
        $this->authorizeIn('admin.access');

        $scope = $access->primaryScope($user);
        $apps = fn () => $access->scopeQuery(Application::query(), $user, 'members.view');
        $members = fn () => $access->scopeQuery(MemberProfile::query(), $user, 'members.view');

        $pending = $apps()->where('status', Application::SUBMITTED);

        // Pending applications grouped by the child units directly under the scope.
        $byUnit = collect();
        if ($scope) {
            $children = OrgUnit::where('parent_id', $scope->id)->get();
            $byUnit = $children->map(fn (OrgUnit $c) => [
                'org_unit' => ['id' => $c->id, 'name' => $c->name],
                'pending' => $apps()->where('status', Application::SUBMITTED)
                    ->whereIn('org_unit_id', OrgUnit::within($c)->select('id'))->count(),
            ])->filter(fn ($r) => $r['pending'] > 0)->sortByDesc('pending')->take(8)->values();
        }

        $recent = ApplicationEvent::whereIn('membership_application_id', $apps()->select('id'))
            ->whereIn('action', ['approved', 'returned', 'rejected'])
            ->with('actor.profile')
            ->latest('id')->limit(8)->get()
            ->map(fn ($e) => [
                'action' => $e->action,
                'actor' => $e->actor?->profile?->full_name ?? $e->actor?->name,
                'at' => $e->created_at?->toIso8601String(),
            ]);

        return $this->ok([
            'scope' => $scope ? ['id' => $scope->id, 'name' => $scope->name, 'type' => $scope->type, 'label' => $scope->label() ?: $scope->name] : null,
            'approved_members' => $members()->where('membership_status', MemberProfile::STATUS_APPROVED)->count(),
            'approved_this_month' => $members()->where('membership_status', MemberProfile::STATUS_APPROVED)->where('approved_at', '>=', now()->startOfMonth())->count(),
            'pending_applications' => (clone $pending)->count(),
            'pending_over_7_days' => (clone $pending)->where('submitted_at', '<', now()->subDays(7))->count(),
            'returned_for_correction' => $apps()->where('status', Application::MORE_INFO)->count(),
            'decided_today' => $apps()->whereIn('status', [Application::APPROVED, Application::REJECTED, Application::MORE_INFO])->where('decided_at', '>=', now()->startOfDay())->count(),
            'pending_by_unit' => $byUnit,
            'recent_decisions' => $recent,
            'reported_posts' => $access->can($user, 'feed.moderate')
                ? Post::whereIn('user_id', $access->scopeQuery(MemberProfile::query(), $user, 'feed.moderate')->select('user_id'))
                    ->where('reports_count', '>', 0)->whereNull('reviewed_at')->count()
                : 0,
        ]);
    }
}

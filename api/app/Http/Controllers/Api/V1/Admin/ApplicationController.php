<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ApplicationResource;
use App\Models\MemberProfile;
use App\Models\MembershipApplication as Application;
use App\Services\AccessControl;
use App\Services\Audit;
use App\Services\MemberIdGenerator;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ApplicationController extends Controller
{
    public function __construct(private AccessControl $access) {}

    public function index(Request $request)
    {
        $request->validate([
            'status' => ['nullable', 'in:submitted,more_info_required,approved,rejected'],
            'q' => ['nullable', 'string', 'max:60'],
            'per_page' => ['nullable', 'integer', 'min:5', 'max:100'],
        ]);
        $this->authorizeIn('members.view');

        $status = $request->input('status', Application::SUBMITTED);

        $query = $this->access->scopeQuery(Application::query(), $request->user(), 'members.view')
            ->where('status', $status)
            ->with('user.profile', 'orgUnit');

        if ($q = $request->input('q')) {
            $query->whereHas('user', fn ($u) => $u->where('mobile', 'like', "%$q%")
                ->orWhereHas('profile', fn ($p) => $p->where('full_name', 'like', "%$q%")));
        }

        // Oldest first for the review queue, newest first for decided lists.
        $status === Application::SUBMITTED ? $query->orderBy('submitted_at') : $query->orderByDesc('decided_at');

        return $this->ok(ApplicationResource::collection($query->paginate($request->integer('per_page', 25))));
    }

    public function show(Request $request, Application $application)
    {
        $this->authorizeIn('members.view', $application->orgUnit);

        return $this->ok($this->detail($application));
    }

    public function approve(Request $request, Application $application, MemberIdGenerator $ids)
    {
        $request->validate(['note' => ['nullable', 'string', 'max:500']]);
        $this->guardDecision($request, $application);

        DB::transaction(function () use ($request, $application, $ids) {
            $profile = $application->user->profile;
            $profile->membership_status = MemberProfile::STATUS_APPROVED;
            $profile->approved_at = now();
            $profile->member_id ??= $ids->next($profile->orgUnit);
            $profile->save();

            $this->decide($request, $application, Application::APPROVED, 'approved');
            Audit::record('membership.approved', $application, null, ['member_id' => $profile->member_id]);
        });

        return $this->ok($this->detail($application));
    }

    public function returnForCorrection(Request $request, Application $application)
    {
        $request->validate(['note' => ['required', 'string', 'min:5', 'max:500']]);
        $this->guardDecision($request, $application);

        DB::transaction(function () use ($request, $application) {
            $application->user->profile->forceFill(['membership_status' => MemberProfile::STATUS_MORE_INFO])->save();
            $this->decide($request, $application, Application::MORE_INFO, 'returned');
            Audit::record('membership.returned', $application, null, ['note' => $request->input('note')]);
        });

        return $this->ok($this->detail($application));
    }

    public function reject(Request $request, Application $application)
    {
        $request->validate(['note' => ['required', 'string', 'min:5', 'max:500']]);
        $this->guardDecision($request, $application);

        DB::transaction(function () use ($request, $application) {
            $application->user->profile->forceFill(['membership_status' => MemberProfile::STATUS_REJECTED])->save();
            $this->decide($request, $application, Application::REJECTED, 'rejected');
            Audit::record('membership.rejected', $application, null, ['note' => $request->input('note')]);
        });

        return $this->ok($this->detail($application));
    }

    private function guardDecision(Request $request, Application $application): void
    {
        $this->authorizeIn('members.review', $application->orgUnit);

        if ($application->user_id === $request->user()->id) {
            throw new ApiException('OWN_APPLICATION', 'You cannot decide your own application.', 403);
        }
        if (! $application->isOpen()) {
            throw new ApiException('ALREADY_DECIDED', 'This application has already been decided.', 409);
        }
    }

    private function decide(Request $request, Application $application, string $status, string $action): void
    {
        $application->forceFill([
            'status' => $status,
            'decided_at' => now(),
            'decided_by' => $request->user()->id,
            'decision_note' => $request->input('note'),
        ])->save();

        $application->events()->create([
            'actor_id' => $request->user()->id,
            'action' => $action,
            'note' => $request->input('note'),
        ]);
    }

    private function detail(Application $application): ApplicationResource
    {
        $application->refresh()->load('user.profile.orgUnit', 'user.vibhags', 'user.responsibilities', 'orgUnit', 'events.actor.profile');

        return (new ApplicationResource($application))->detailed();
    }
}

<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProfileResource;
use App\Models\MemberProfile;
use App\Models\OrgUnit;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class ProfileController extends Controller
{
    public function show(Request $request)
    {
        $profile = $request->user()->profile;

        return $this->ok($profile ? new ProfileResource($profile->load('orgUnit', 'user.vibhags', 'user.responsibilities')) : null);
    }

    public function update(Request $request)
    {
        $user = $request->user();
        $profile = $user->profile;

        $data = $request->validate([
            'full_name' => [$profile ? 'sometimes' : 'required', 'string', 'min:2', 'max:120'],
            'gender' => ['nullable', 'in:male,female,other'],
            'date_of_birth' => ['nullable', 'date', 'before:-14 years', 'after:-60 years'],
            'org_unit_id' => ['sometimes', 'integer', Rule::exists('org_units', 'id')->where('is_active', true)],
            'institution' => ['nullable', 'string', 'max:160'],
            'course' => ['nullable', 'string', 'max:120'],
            'study_year' => ['nullable', 'string', 'max:16'],
            'bio' => ['nullable', 'string', 'max:500'],
            'languages' => ['nullable', 'array', 'max:8'],
            'languages.*' => ['string', 'max:30'],
            'skills' => ['nullable', 'array', 'max:12'],
            'skills.*' => ['string', 'max:40'],
            'links' => ['nullable', 'array', 'max:5'],
            'links.*.label' => ['required_with:links', 'string', 'max:30'],
            'links.*.url' => ['required_with:links', 'url:https', 'max:255'],
            'vibhag_ids' => ['nullable', 'array', 'max:10'],
            'vibhag_ids.*' => ['integer', Rule::exists('vibhags', 'id')->where('is_active', true)],
        ]);

        if (isset($data['org_unit_id'])) {
            $unit = OrgUnit::find($data['org_unit_id']);
            if (! in_array($unit->type, ['district', 'unit'], true)) {
                throw new ApiException('UNIT_TOO_BROAD', 'Choose your district or unit, not a state.');
            }
            if ($profile && $profile->membership_status === MemberProfile::STATUS_APPROVED && $profile->org_unit_id !== $unit->id) {
                throw new ApiException('UNIT_LOCKED', 'Approved members change their unit through their district office.');
            }
        }

        $profile ??= new MemberProfile(['user_id' => $user->id]);
        $profile->user_id = $user->id;
        $profile->fill(collect($data)->except('vibhag_ids')->all())->save();
        $user->setRelation('profile', $profile);

        if (array_key_exists('vibhag_ids', $data)) {
            $user->vibhags()->sync(collect($data['vibhag_ids'] ?? [])->mapWithKeys(fn ($id) => [$id => ['joined_at' => now()]]));
        }

        if (isset($data['full_name'])) {
            $user->update(['name' => $data['full_name']]);
        }

        return $this->ok(new ProfileResource($profile->fresh()->load('orgUnit', 'user.vibhags', 'user.responsibilities')));
    }

    public function privacy(Request $request)
    {
        $levels = config('abvp.privacy_levels');
        $fields = array_keys(config('abvp.privacy_defaults'));

        $data = $request->validate(collect($fields)->mapWithKeys(fn ($f) => [$f => ['sometimes', Rule::in($levels)]])->all());

        $profile = $request->user()->profile ?? throw new ApiException('PROFILE_REQUIRED', 'Create your profile first.');
        $profile->privacy = array_merge($profile->privacy ?? [], $data);
        $profile->save();

        return $this->ok(new ProfileResource($profile->load('orgUnit', 'user.vibhags', 'user.responsibilities')));
    }

    public function photo(Request $request)
    {
        $request->validate(['photo' => ['required', 'image', 'mimes:jpeg,png,webp', 'max:2048', 'dimensions:min_width=200,min_height=200']]);

        $profile = $request->user()->profile ?? throw new ApiException('PROFILE_REQUIRED', 'Create your profile first.');
        $disk = Storage::disk(config('abvp.media_disk'));

        $path = $request->file('photo')->storeAs(
            'photos/'.$profile->user_id,
            Str::uuid().'.'.$request->file('photo')->extension(),
            ['disk' => config('abvp.media_disk'), 'visibility' => 'private'],
        );

        if ($profile->photo_path) {
            $disk->delete($profile->photo_path);
        }

        $profile->photo_path = $path;
        $profile->save();

        return $this->ok(new ProfileResource($profile->load('orgUnit', 'user.vibhags', 'user.responsibilities')));
    }
}

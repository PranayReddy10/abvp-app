<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\GuideContact;
use App\Models\GuideItem;
use App\Models\MemberProfile;
use App\Services\AccessControl;
use App\Services\Audit;
use App\Services\GuidePresenter;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/** Organisers fill the conference guide: places, how to reach them and whom to call. */
class GuideController extends Controller
{
    public function __construct(private AccessControl $access) {}

    public function index(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $items = GuideItem::where('event_id', $event->id)->with('contacts.user.profile')->orderBy('kind')->orderBy('sort')->orderBy('id')->get();

        return $this->ok([
            'settings' => [
                'guide_enabled' => $event->guide_enabled,
                'venue_lat' => $event->venue_lat,
                'venue_lng' => $event->venue_lng,
                'helpline_phone' => $event->helpline_phone,
            ],
            'kinds' => GuidePresenter::kinds(),
            'prants' => config('abvp.prants'),
            'items' => $items->map(fn ($i) => GuidePresenter::item($i, $event))->values(),
        ]);
    }

    public function settings(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $data = $request->validate([
            'guide_enabled' => ['required', 'boolean'],
            'venue_lat' => ['nullable', 'numeric', 'between:-90,90'],
            'venue_lng' => ['nullable', 'numeric', 'between:-180,180'],
            'helpline_phone' => ['nullable', 'string', 'max:20', 'regex:/^[0-9+ -]{3,20}$/'],
        ]);
        $before = $event->only(array_keys($data));
        $event->fill($data)->save();
        Audit::record('event.guide_settings', $event, $before, $data);

        return $this->index($request, $event);
    }

    public function store(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $item = DB::transaction(function () use ($request, $event) {
            $data = $this->validated($request);
            $item = GuideItem::create($data['item'] + ['event_id' => $event->id, 'sort' => (int) GuideItem::where('event_id', $event->id)->where('kind', $data['item']['kind'])->max('sort') + 1]);
            $this->saveContacts($item, $data['contacts']);

            return $item;
        });
        Audit::record('guide.created', $item, null, ['kind' => $item->kind, 'title' => $item->title]);

        return $this->ok(GuidePresenter::item($item->fresh('contacts.user.profile'), $event), 201);
    }

    public function update(Request $request, GuideItem $item)
    {
        $event = $item->event;
        $this->guard($request, $event);
        DB::transaction(function () use ($request, $item) {
            $data = $this->validated($request, $item);
            $item->fill($data['item'])->save();
            $this->saveContacts($item, $data['contacts']);
        });
        Audit::record('guide.updated', $item, null, ['title' => $item->title]);

        return $this->ok(GuidePresenter::item($item->fresh('contacts.user.profile'), $event));
    }

    public function destroy(Request $request, GuideItem $item)
    {
        $this->guard($request, $item->event);
        $disk = Storage::disk(config('abvp.media_disk'));
        foreach ($item->photos ?? [] as $path) {
            $disk->delete($path);
        }
        Audit::record('guide.deleted', $item, ['kind' => $item->kind, 'title' => $item->title]);
        $item->delete();

        return $this->ok(['deleted' => true]);
    }

    public function reorder(Request $request, Event $event)
    {
        $this->guard($request, $event);
        $data = $request->validate(['ids' => ['required', 'array', 'max:300'], 'ids.*' => ['integer']]);
        foreach ($data['ids'] as $i => $id) {
            GuideItem::where('event_id', $event->id)->whereKey($id)->update(['sort' => $i + 1]);
        }

        return $this->ok(['sorted' => count($data['ids'])]);
    }

    public function addPhoto(Request $request, GuideItem $item)
    {
        $this->guard($request, $item->event);
        $request->validate(['photo' => ['required', 'image', 'mimes:jpeg,png,webp', 'max:4096']]);
        $photos = $item->photos ?? [];
        if (count($photos) >= 8) {
            throw new ApiException('TOO_MANY_PHOTOS', 'Up to 8 photos per place. Remove one first.', 422);
        }
        $photos[] = $request->file('photo')->storeAs('guide/'.$item->event_id, Str::uuid().'.'.$request->file('photo')->extension(), ['disk' => config('abvp.media_disk'), 'visibility' => 'private']);
        $item->forceFill(['photos' => $photos])->save();

        return $this->ok(GuidePresenter::item($item->fresh('contacts.user.profile'), $item->event));
    }

    public function removePhoto(Request $request, GuideItem $item, int $index)
    {
        $this->guard($request, $item->event);
        $photos = $item->photos ?? [];
        abort_unless(isset($photos[$index]), 404);
        Storage::disk(config('abvp.media_disk'))->delete($photos[$index]);
        array_splice($photos, $index, 1);
        $item->forceFill(['photos' => $photos ?: null])->save();

        return $this->ok(GuidePresenter::item($item->fresh('contacts.user.profile'), $item->event));
    }

    /** @return array{item: array, contacts: array} */
    private function validated(Request $request, ?GuideItem $item = null): array
    {
        $data = $request->validate([
            'kind' => [$item ? 'sometimes' : 'required', Rule::in(array_keys(config('abvp.guide_kinds')))],
            'title' => ['required', 'string', 'max:120'],
            'subtitle' => ['nullable', 'string', 'max:160'],
            'region' => ['nullable', Rule::requiredIf(($request->input('kind') ?? $item?->kind) === 'stay'), 'string', 'max:80'],
            'description' => ['nullable', 'string', 'max:5000'],
            'location' => ['nullable', 'string', 'max:160'],
            'landmark' => ['nullable', 'string', 'max:160'],
            'color' => ['nullable', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'timings' => ['nullable', 'string', 'max:120'],
            'tags' => ['nullable', 'array', 'max:8'],
            'tags.*' => ['nullable', 'string', 'max:30'],
            'steps' => ['nullable', 'array', 'max:12'],
            'steps.*' => ['nullable', 'string', 'max:200'],
            'map_url' => ['nullable', 'url', 'max:500'],
            'lat' => ['nullable', 'numeric', 'between:-90,90', 'required_with:lng'],
            'lng' => ['nullable', 'numeric', 'between:-180,180', 'required_with:lat'],
            'distance_km' => ['nullable', 'numeric', 'min:0', 'max:9999'],
            'travel_time' => ['nullable', 'string', 'max:60'],
            'contacts' => ['nullable', 'array', 'max:20'],
            'contacts.*.name' => ['required_without:contacts.*.member_id', 'nullable', 'string', 'max:100'],
            'contacts.*.role' => ['nullable', 'string', 'max:80'],
            'contacts.*.phone' => ['nullable', 'string', 'regex:/^[0-9+ -]{3,20}$/'],
            'contacts.*.member_id' => ['nullable', 'string', 'max:40'],
            'contacts.*.is_lead' => ['nullable', 'boolean'],
        ], ['region.required' => 'Choose the prant (state) this stay is for.', 'contacts.*.phone.regex' => 'Phone numbers use digits only.']);

        $contacts = $data['contacts'] ?? [];
        unset($data['contacts']);
        $data['tags'] = array_values(array_filter($data['tags'] ?? [])) ?: null;
        $data['steps'] = array_values(array_filter($data['steps'] ?? [])) ?: null;

        return ['item' => $data, 'contacts' => $contacts];
    }

    private function saveContacts(GuideItem $item, array $contacts): void
    {
        $item->contacts()->delete();
        foreach (array_values($contacts) as $i => $c) {
            $userId = null;
            $name = $c['name'] ?? null;
            if (! empty($c['member_id'])) {
                $profile = MemberProfile::where('member_id', $c['member_id'])->first();
                if (! $profile) {
                    throw \Illuminate\Validation\ValidationException::withMessages(["contacts.$i.member_id" => "No member with ID {$c['member_id']}."]);
                }
                $userId = $profile->user_id;
                $name = $name ?: $profile->full_name;
            }
            GuideContact::create([
                'guide_item_id' => $item->id, 'user_id' => $userId, 'name' => $name, 'role' => $c['role'] ?? null,
                'phone' => $c['phone'] ?? null, 'is_lead' => (bool) ($c['is_lead'] ?? false), 'sort' => $i,
            ]);
        }
    }

    private function guard(Request $request, Event $event): void
    {
        if (! $this->access->canIn($request->user(), 'events.manage', $event->orgUnit)) {
            throw new ApiException('FORBIDDEN_SCOPE', 'This event is outside your area.', 403);
        }
    }
}

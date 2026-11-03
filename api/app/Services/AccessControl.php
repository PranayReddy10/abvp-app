<?php

namespace App\Services;

use App\Models\OrgUnit;
use App\Models\RoleAssignment;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

/**
 * Role + scope checks. A role grants an action only inside the org unit it was
 * assigned for, and every unit below it. Default is deny.
 */
class AccessControl
{
    /** @var array<int, Collection<int, RoleAssignment>> */
    private array $cache = [];

    /** @return Collection<int, RoleAssignment> */
    public function rolesOf(User $user): Collection
    {
        return $this->cache[$user->id] ??= $user->roleAssignments()->active()->with('orgUnit')->get();
    }

    /** Assignments that grant the permission, anywhere. */
    public function grants(User $user, string $permission): Collection
    {
        $allowed = config("abvp.permissions.$permission", []);

        return $this->rolesOf($user)->filter(fn (RoleAssignment $r) => in_array($r->role, $allowed, true));
    }

    public function can(User $user, string $permission): bool
    {
        return $this->grants($user, $permission)->isNotEmpty();
    }

    public function canIn(User $user, string $permission, ?OrgUnit $unit): bool
    {
        if (! $unit) {
            return false;
        }

        return $this->grants($user, $permission)->contains(fn (RoleAssignment $r) => $r->orgUnit?->contains($unit));
    }

    /**
     * Restrict a query to rows whose org unit sits inside the user's scope for
     * the permission. $unitColumn is the foreign key column on the queried table.
     */
    public function scopeQuery(Builder $query, User $user, string $permission, string $unitColumn = 'org_unit_id'): Builder
    {
        $paths = $this->grants($user, $permission)->map(fn ($r) => $r->orgUnit?->path)->filter()->unique()->values();

        if ($paths->isEmpty()) {
            return $query->whereRaw('1 = 0');
        }

        $table = $query->getModel()->getTable();

        return $query->whereIn("$table.$unitColumn", function ($sub) use ($paths) {
            $sub->select('id')->from('org_units')->where(function ($w) use ($paths) {
                foreach ($paths as $path) {
                    $w->orWhere('path', 'like', $path.'%');
                }
            });
        });
    }

    /** Highest role rank the user holds over this unit. */
    public function rankIn(User $user, OrgUnit $unit): int
    {
        return (int) $this->rolesOf($user)
            ->filter(fn (RoleAssignment $r) => $r->orgUnit?->contains($unit))
            ->map(fn (RoleAssignment $r) => $r->rank())
            ->max();
    }

    /** The widest unit the user administers, used as the default dashboard scope. */
    public function primaryScope(User $user): ?OrgUnit
    {
        return $this->grants($user, 'admin.access')
            ->map(fn ($r) => $r->orgUnit)
            ->filter()
            ->sortBy('depth')
            ->first();
    }

    public function forget(User $user): void
    {
        unset($this->cache[$user->id]);
    }
}

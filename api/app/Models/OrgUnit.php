<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class OrgUnit extends Model
{
    use HasFactory;

    protected $fillable = ['parent_id', 'type', 'name', 'name_local', 'code', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    protected static function booted(): void
    {
        // Keep the materialised path in sync. Units are not re-parented in phase 1.
        static::created(function (OrgUnit $unit) {
            $parent = $unit->parent;
            $unit->path = ($parent?->path ?? '/').$unit->id.'/';
            $unit->depth = $parent ? $parent->depth + 1 : 0;
            $unit->saveQuietly();
        });
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(OrgUnit::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(OrgUnit::class, 'parent_id')->orderBy('name');
    }

    /** This unit and every unit below it. */
    public function scopeWithin(Builder $query, OrgUnit $unit): Builder
    {
        return $query->where('path', 'like', $unit->path.'%');
    }

    public function contains(OrgUnit $other): bool
    {
        return str_starts_with($other->path, $this->path);
    }

    /** Ancestors from the top down, including this unit. */
    public function lineage()
    {
        $ids = array_values(array_filter(explode('/', $this->path)));

        return static::whereIn('id', $ids)->orderBy('depth')->get();
    }

    /** "Telangana › Hyderabad › Osmania University" */
    public function label(): string
    {
        return $this->lineage()->where('type', '!=', 'national')->pluck('name')->implode(' › ');
    }

    public function ancestorOfType(string $type): ?OrgUnit
    {
        return $this->lineage()->firstWhere('type', $type);
    }
}

<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ResponsibilityResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'org_unit' => $this->orgUnit ? ['id' => $this->orgUnit->id, 'name' => $this->orgUnit->name] : null,
            'vibhag' => $this->vibhag ? ['id' => $this->vibhag->id, 'name' => $this->vibhag->name] : null,
            'starts_on' => $this->starts_on?->toDateString(),
            'ends_on' => $this->ends_on?->toDateString(),
            'is_current' => $this->ends_on === null || $this->ends_on->isFuture(),
        ];
    }
}

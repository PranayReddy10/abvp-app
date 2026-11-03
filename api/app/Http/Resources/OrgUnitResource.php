<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrgUnitResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'parent_id' => $this->parent_id,
            'type' => $this->type,
            'name' => $this->name,
            'name_local' => $this->name_local,
            'code' => $this->code,
            'is_active' => $this->is_active,
            'children_count' => $this->whenCounted('children'),
        ];
    }
}

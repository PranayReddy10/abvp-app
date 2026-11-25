<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationsTest extends TestCase
{
    use RefreshDatabase;

    public function test_notification_data_is_always_an_object(): void
    {
        $u = User::create(['mobile' => '+919811177788', 'name' => 'Asha']);
        AppNotification::sendMany([$u->id], 'event_registration_decided', 'Confirmed', null, []);
        AppNotification::sendMany([$u->id], 'post_comment', 'Reply', null, ['post_id' => 5]);
        Sanctum::actingAs($u);

        $raw = $this->getJson('/api/v1/notifications')->assertOk()->getContent();
        $this->assertStringContainsString('"data":{}', $raw);
        $this->assertStringContainsString('"data":{"post_id":5}', $raw);
    }
}

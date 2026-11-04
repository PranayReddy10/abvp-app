<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Community feed: short posts with up to four photos, for approved members only.
        Schema::create('posts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('body')->nullable();
            // members = every approved member · area = the author's district · vibhag = one Vibhag
            $table->string('audience', 8)->default('members');
            $table->foreignId('org_unit_id')->nullable()->constrained('org_units');
            $table->foreignId('vibhag_id')->nullable()->constrained('vibhags');
            $table->foreignId('repost_of_id')->nullable()->constrained('posts')->nullOnDelete();
            $table->json('photos')->nullable();
            $table->unsignedInteger('likes_count')->default(0);
            $table->unsignedInteger('comments_count')->default(0);
            $table->unsignedInteger('reposts_count')->default(0);
            $table->unsignedInteger('reports_count')->default(0);
            $table->timestamp('hidden_at')->nullable();
            $table->foreignId('hidden_by')->nullable()->constrained('users');
            $table->string('hidden_reason', 200)->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
            $table->index(['hidden_at', 'id']);
            $table->index(['user_id', 'id']);
        });

        Schema::create('post_likes', function (Blueprint $table) {
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('created_at')->nullable();
            $table->primary(['post_id', 'user_id']);
        });

        Schema::create('post_comments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('body', 500);
            $table->timestamps();
            $table->index(['post_id', 'id']);
        });

        Schema::create('post_tags', function (Blueprint $table) {
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->string('tag', 40);
            $table->timestamp('created_at')->nullable();
            $table->primary(['post_id', 'tag']);
            $table->index(['tag', 'created_at']);
        });

        Schema::create('post_reports', function (Blueprint $table) {
            $table->foreignId('post_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('reason', 30); // abuse | false_info | spam | private_info | other
            $table->string('note', 300)->nullable();
            $table->timestamp('created_at')->nullable();
            $table->primary(['post_id', 'user_id']);
        });

        Schema::create('follows', function (Blueprint $table) {
            $table->foreignId('follower_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('followee_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('created_at')->nullable();
            $table->primary(['follower_id', 'followee_id']);
            $table->index('followee_id');
        });

        Schema::table('events', function (Blueprint $table) {
            $table->string('cover_path')->nullable()->after('venue_map_url');
        });
    }

    public function down(): void
    {
        Schema::table('events', fn (Blueprint $t) => $t->dropColumn('cover_path'));
        foreach (['follows', 'post_reports', 'post_tags', 'post_comments', 'post_likes', 'posts'] as $t) {
            Schema::dropIfExists($t);
        }
    }
};

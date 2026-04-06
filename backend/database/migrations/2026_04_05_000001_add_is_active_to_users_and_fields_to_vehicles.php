<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Add is_active to users
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_active')->default(true)->after('profile_picture');
        });

        // Add missing vehicle fields
        Schema::table('vehicles', function (Blueprint $table) {
            $table->string('vehicle_name')->nullable()->after('id');
            $table->string('type')->nullable()->after('vehicle_name');
            $table->integer('capacity')->nullable()->after('type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('is_active');
        });

        Schema::table('vehicles', function (Blueprint $table) {
            $table->dropColumn(['vehicle_name', 'type', 'capacity']);
        });
    }
};

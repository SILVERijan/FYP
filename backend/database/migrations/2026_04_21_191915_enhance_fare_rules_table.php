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
        Schema::table('fare_rules', function (Blueprint $table) {
            $table->string('vehicle_type')->nullable()->after('max_km');
            $table->unsignedBigInteger('route_id')->nullable()->after('vehicle_type');
            
            $table->foreign('route_id')->references('id')->on('routes')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('fare_rules', function (Blueprint $table) {
            $table->dropForeign(['route_id']);
            $table->dropColumn(['vehicle_type', 'route_id']);
        });
    }
};

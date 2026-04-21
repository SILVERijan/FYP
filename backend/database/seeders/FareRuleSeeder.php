<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class FareRuleSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        \App\Models\FareRule::create(['min_km' => 0, 'max_km' => 5, 'fare' => 18]);
        \App\Models\FareRule::create(['min_km' => 5, 'max_km' => 10, 'fare' => 24]);
        \App\Models\FareRule::create(['min_km' => 10, 'max_km' => 15, 'fare' => 29]);
        \App\Models\FareRule::create(['min_km' => 15, 'max_km' => 20, 'fare' => 32]);
        \App\Models\FareRule::create(['min_km' => 20, 'max_km' => null, 'fare' => 37]);
    }
}

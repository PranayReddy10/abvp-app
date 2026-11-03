<?php

namespace Database\Seeders;

use App\Models\Vibhag;
use Illuminate\Database\Seeder;

/**
 * Sample Vibhags to start with. The official list of about 70 is managed from
 * the admin panel (Vibhags) and is not hard-coded anywhere.
 */
class VibhagSeeder extends Seeder
{
    public function run(): void
    {
        $sample = [
            ['SFD', 'Students for Development'],
            ['THINK-INDIA', 'Think India'],
            ['RKM', 'Rashtriya Kala Manch'],
            ['MEDIVISION', 'Medivision'],
            ['AGRIVISION', 'Agrivision'],
            ['MISSION-SAHASI', 'Mission Sahasi'],
            ['KHELO-BHARAT', 'Khelo Bharat'],
            ['SEIL', 'SEIL'],
            ['WOSY', 'WOSY'],
        ];

        foreach ($sample as $i => [$code, $name]) {
            Vibhag::firstOrCreate(['code' => $code], ['name' => $name, 'sort_order' => $i]);
        }
    }
}

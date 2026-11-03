<?php

namespace Database\Seeders;

use App\Models\OrgUnit;
use Illuminate\Database\Seeder;

/**
 * Starter hierarchy for the Telangana pilot. Replace or extend with the
 * approved national list; units can also be added from the admin panel.
 */
class OrganisationSeeder extends Seeder
{
    public function run(): void
    {
        $india = OrgUnit::firstOrCreate(['parent_id' => null, 'name' => 'Bharat'], ['type' => 'national', 'code' => 'IN']);

        $states = [
            ['Telangana', 'TS', 'తెలంగాణ', [
                ['Hyderabad', 'HYD', ['Osmania University', 'Secunderabad', 'Kukatpally', 'LB Nagar', 'Charminar']],
                ['Warangal', 'WGL', ['Kakatiya University', 'Hanamkonda']],
                ['Karimnagar', 'KNR', ['Karimnagar Town']],
                ['Nizamabad', 'NZB', ['Nizamabad Town']],
                ['Khammam', 'KMM', ['Khammam Town']],
            ]],
            ['Andhra Pradesh', 'AP', 'ఆంధ్రప్రదేశ్', [
                ['Visakhapatnam', 'VSP', ['Andhra University']],
                ['Vijayawada', 'VJA', ['Vijayawada Town']],
            ]],
        ];

        foreach ($states as [$name, $code, $local, $districts]) {
            $state = OrgUnit::firstOrCreate(['parent_id' => $india->id, 'name' => $name], ['type' => 'state', 'code' => $code, 'name_local' => $local]);

            foreach ($districts as [$dName, $dCode, $units]) {
                $district = OrgUnit::firstOrCreate(['parent_id' => $state->id, 'name' => $dName], ['type' => 'district', 'code' => $dCode]);

                foreach ($units as $uName) {
                    OrgUnit::firstOrCreate(['parent_id' => $district->id, 'name' => $uName], ['type' => 'unit']);
                }
            }
        }
    }
}

import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from export_sunshine import aggregate


class SunshineTests(unittest.TestCase):
    def payload(self):
        return {'daily_units':{'sunshine_duration':'s'},'daily':{
            'time':[f'2024-02-{day:02d}' for day in range(1,30)],
            'sunshine_duration':[7200]*29}}

    def test_complete_month_and_explicit_threshold(self):
        d=self.payload()
        row=aggregate(d)[0]
        self.assertEqual(row['sunshine_hours_total'],58)
        self.assertEqual(row['sunshine_hours_daily_mean'],2)
        self.assertIsNone(row['sunny_days_custom_threshold'])
        self.assertEqual(aggregate(d,2)[0]['sunny_days_custom_threshold'],29)
        self.assertEqual(aggregate(d,3)[0]['sunny_days_custom_threshold'],0)

    def test_missing_day_not_silent_zero(self):
        d=self.payload();d['daily']['sunshine_duration'][4]=None
        row=aggregate(d)[0]
        self.assertFalse(row['complete'])
        self.assertIsNone(row['sunshine_hours_total'])

    def test_units_rejected(self):
        d=self.payload();d['daily_units']['sunshine_duration']='h'
        with self.assertRaises(ValueError):aggregate(d)

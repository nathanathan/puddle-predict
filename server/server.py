from __future__ import print_function
import pandas as pd
import geopandas as gp
from rasterstats import zonal_stats
from affine import Affine
import numpy as np
import h5py
from osgeo import gdal
import datetime
import json

from flask import Flask, jsonify, Response
app = Flask(__name__)

data = pd.read_pickle('all-data-district-week-timeseries.p')
uganda_shapes = pd.read_pickle('uganda_shapes.p')
uganda_shapes.geometry = uganda_shapes.geometry.simplify(.002)

features = [
    'district_mean_rainfall_mm_above_median',
    'case_ratio_above_median',
    'cases_anomoly'
]
feature_groups = data.groupby(features).agg({
    'future_outbreak': ['sum', 'count'],
    'mean_future_case_multiple': 'median'
}).reset_index()
feature_groups.columns = [
    '_'.join(filter(lambda x:x, col))
    for col in feature_groups.columns.values]
    
feature_groups = feature_groups.rename(
    columns={
        'future_outbreak_count': 'occurrences',
        'future_outbreak_sum': 'future_outbreaks'})
print("Collecting most recent district stats...")
as_of_week = data.week.max()
most_recent_stats = data[data.week == as_of_week]
most_recent_stats = most_recent_stats.merge(feature_groups, on=features)
most_recent_stats = most_recent_stats.drop(list(set(uganda_shapes.columns) - set(['district'])), 1)
most_recent_stats['projected_cases'] = most_recent_stats.mean_future_case_multiple_median * most_recent_stats.malaria_cases_wep
most_recent_stats = uganda_shapes.merge(most_recent_stats, on='district', how='outer')
most_recent_stats = most_recent_stats[[
    'projected_cases',
    'geometry',
    'district',
    'week',
    'malaria_cases_wep',
    'occurrences',
    'future_outbreaks',
    'outbreak_threshold',
    'district_mean_rainfall_mm'] + features]
most_recent_stats['week'] = most_recent_stats.week.map(lambda d: d.isoformat())
print(len(most_recent_stats))
@app.route('/stats.json')
def stats():
    jsonOutput = json.loads(most_recent_stats.to_json())
    jsonOutput['asOfDate'] = as_of_week.isoformat()
    jsonOutput['medianCasesOverPopulation'] = data.case_ratio.median()
    jsonOutput['medianWeeklyRainfallMm'] = data.district_mean_rainfall_mm.median()
    return jsonify(jsonOutput)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3333, debug=True)

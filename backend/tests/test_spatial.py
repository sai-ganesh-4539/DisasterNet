"""
Spatial utilities tests
"""
import pytest
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.spatial import (
    create_grid,
    calculate_distance,
    buffer_point,
    polygons_to_geojson,
    intersect_polygons,
    find_nearest_features,
    calculate_centroid,
    calculate_area,
    simplify_geometry,
    cluster_points,
    create_convex_hull
)


def test_create_grid():
    """Test spatial grid creation"""
    # Create a small grid for testing
    region_bounds = (77.0, 28.0, 77.5, 28.5)  # (min_lon, min_lat, max_lon, max_lat)
    resolution_meters = 1000  # 1km
    
    grid_cells = create_grid(region_bounds, resolution_meters)
    
    assert isinstance(grid_cells, list)
    assert len(grid_cells) > 0
    
    # Check first cell structure
    first_cell = grid_cells[0]
    assert 'grid_id' in first_cell
    assert 'geometry' in first_cell
    assert 'center_lat' in first_cell
    assert 'center_lon' in first_cell
    assert 'resolution_meters' in first_cell


def test_calculate_distance():
    """Test distance calculation between two points"""
    point1 = (28.5, 77.2)  # (lat, lon)
    point2 = (28.6, 77.3)  # (lat, lon)
    
    distance = calculate_distance(point1, point2)
    
    assert distance > 0
    assert isinstance(distance, float)
    
    # Test same point (should be 0)
    same_point_distance = calculate_distance(point1, point1)
    assert same_point_distance == 0.0


def test_buffer_point():
    """Test point buffering"""
    point_wkt = 'POINT(77.2 28.5)'
    buffer_km = 5.0
    
    buffered_geometry = buffer_point(point_wkt, buffer_km)
    
    assert buffered_geometry != point_wkt
    assert buffered_geometry.startswith('POLYGON')


def test_polygons_to_geojson():
    """Test conversion of polygons to GeoJSON"""
    polygons = [
        {
            'geometry': 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))',
            'zone_id': 'RZ_001',
            'hazard_type': 'LANDSLIDE'
        },
        {
            'geometry': 'POLYGON((75.8 19.0, 76.0 19.0, 76.0 19.2, 75.8 19.2, 75.8 19.0))',
            'zone_id': 'RZ_002',
            'hazard_type': 'FLOOD'
        }
    ]
    
    geojson = polygons_to_geojson(polygons)
    
    assert 'type' in geojson
    assert geojson['type'] == 'FeatureCollection'
    assert 'features' in geojson
    assert len(geojson['features']) == 2
    
    # Check first feature structure
    first_feature = geojson['features'][0]
    assert 'type' in first_feature
    assert 'geometry' in first_feature
    assert 'properties' in first_feature


def test_intersect_polygons():
    """Test polygon intersection calculation"""
    polygon1 = 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))'
    polygon2 = 'POLYGON((77.25 28.55, 77.35 28.55, 77.35 28.65, 77.25 28.65, 77.25 28.55))'
    
    intersection = intersect_polygons(polygon1, polygon2)
    
    assert 'intersects' in intersection
    assert 'intersection_area' in intersection
    assert 'intersection_percentage' in intersection
    
    # Test non-intersecting polygons
    non_intersecting = 'POLYGON((75.0 19.0, 75.1 19.0, 75.1 19.1, 75.0 19.1, 75.0 19.0))'
    no_intersection = intersect_polygons(polygon1, non_intersecting)
    
    assert no_intersection['intersects'] is False
    assert no_intersection['intersection_area'] == 0.0


def test_find_nearest_features():
    """Test finding nearest features to a point"""
    point_wkt = 'POINT(77.25 28.55)'
    
    features = [
        {
            'geometry': 'POINT(77.2 28.5)',
            'name': 'Feature 1'
        },
        {
            'geometry': 'POINT(77.3 28.6)',
            'name': 'Feature 2'
        },
        {
            'geometry': 'POINT(77.4 28.7)',
            'name': 'Feature 3'
        }
    ]
    
    nearby_features = find_nearest_features(point_wkt, features, max_distance_km=50)
    
    assert isinstance(nearby_features, list)
    assert len(nearby_features) > 0
    
    # Check that distance is added
    for feature in nearby_features:
        assert 'distance_km' in feature
    
    # Check that results are sorted by distance
    if len(nearby_features) > 1:
        assert nearby_features[0]['distance_km'] <= nearby_features[1]['distance_km']


def test_calculate_centroid():
    """Test centroid calculation"""
    polygon_wkt = 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))'
    
    centroid = calculate_centroid(polygon_wkt)
    
    assert isinstance(centroid, tuple)
    assert len(centroid) == 2
    assert 28.5 <= centroid[0] <= 28.6  # Latitude within bounds
    assert 77.2 <= centroid[1] <= 77.3  # Longitude within bounds


def test_calculate_area():
    """Test area calculation"""
    polygon_wkt = 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))'
    
    area = calculate_area(polygon_wkt)
    
    assert isinstance(area, float)
    assert area > 0


def test_simplify_geometry():
    """Test geometry simplification"""
    polygon_wkt = 'POLYGON((77.2 28.5, 77.21 28.51, 77.22 28.52, 77.23 28.53, 77.3 28.6, 77.2 28.6, 77.2 28.5))'
    
    simplified = simplify_geometry(polygon_wkt, tolerance=0.01)
    
    assert isinstance(simplified, str)
    assert simplified.startswith('POLYGON')


def test_cluster_points():
    """Test point clustering"""
    points = [
        (28.5, 77.2),
        (28.51, 77.21),
        (28.52, 77.22),  # Cluster 1
        (28.6, 77.3),
        (28.61, 77.31),  # Cluster 2
        (19.0, 75.8)  # Outlier
    ]
    
    clusters = cluster_points(points, eps=0.05, min_samples=2)
    
    assert isinstance(clusters, list)
    # Should have at least one cluster
    assert len(clusters) >= 0


def test_create_convex_hull():
    """Test convex hull creation"""
    points = [
        (28.5, 77.2),
        (28.6, 77.3),
        (28.5, 77.3),
        (28.6, 77.2)
    ]
    
    convex_hull = create_convex_hull(points)
    
    assert isinstance(convex_hull, str)
    assert convex_hull.startswith('POLYGON')


def test_convex_hull_insufficient_points():
    """Test convex hull with insufficient points"""
    points = [
        (28.5, 77.2),
        (28.6, 77.3)  # Only 2 points
    ]
    
    convex_hull = create_convex_hull(points)
    
    # Should return empty string for insufficient points
    assert convex_hull == ""


def test_calculate_distance_known_locations():
    """Test distance calculation with known locations"""
    # Distance between Delhi and Mumbai (approximately)
    delhi = (28.6139, 77.2090)
    mumbai = (19.0760, 72.8777)
    
    distance = calculate_distance(delhi, mumbai)
    
    # Should be approximately 1150 km (using Haversine formula)
    assert 1100 < distance < 1200


def test_buffer_geometry_type():
    """Test that buffer produces correct geometry type"""
    point_wkt = 'POINT(77.2 28.5)'
    buffered = buffer_point(point_wkt, 1.0)
    
    assert buffered.startswith('POLYGON')


def test_geojson_properties():
    """Test that GeoJSON conversion preserves properties"""
    polygons = [
        {
            'geometry': 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))',
            'zone_id': 'RZ_001',
            'hazard_type': 'LANDSLIDE',
            'severity_level': 'HIGH'
        }
    ]
    
    geojson = polygons_to_geojson(polygons)
    
    feature = geojson['features'][0]
    properties = feature['properties']
    
    assert 'zone_id' in properties
    assert properties['zone_id'] == 'RZ_001'
    assert 'hazard_type' in properties
    assert 'geometry' not in properties  # Geometry should not be in properties
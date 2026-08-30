"""
Spatial utility functions for geographic operations
"""
from typing import Dict, List, Any, Optional, Tuple
import logging
from shapely.geometry import Point, Polygon, MultiPolygon
from shapely.wkt import loads as wkt_loads, dumps as wkt_dumps
from shapely.ops import unary_union
import geopandas as gpd
import numpy as np

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def create_grid(region_bounds: Tuple[float, float, float, float], 
                resolution_meters: int) -> List[Dict[str, Any]]:
    """
    Create a spatial grid for a region
    
    Args:
        region_bounds: (min_lon, min_lat, max_lon, max_lat)
        resolution_meters: Grid resolution in meters
    
    Returns:
        List of grid cell dictionaries with geometry and metadata
    """
    min_lon, min_lat, max_lon, max_lat = region_bounds
    
    # Convert resolution to degrees (approximate)
    # 1 degree ≈ 111 km at equator
    resolution_degrees = resolution_meters / 111000.0
    
    grid_cells = []
    
    # Generate grid cells
    lat = min_lat
    row = 0
    while lat < max_lat:
        lon = min_lon
        col = 0
        while lon < max_lon:
            # Create grid cell polygon
            cell_bounds = [
                (lon, lat),
                (lon + resolution_degrees, lat),
                (lon + resolution_degrees, lat + resolution_degrees),
                (lon, lat + resolution_degrees),
                (lon, lat)
            ]
            
            cell_polygon = Polygon(cell_bounds)
            center_point = cell_polygon.centroid
            
            grid_cells.append({
                'grid_id': f"GRID_{row}_{col}",
                'geometry': cell_polygon.wkt,
                'center_lat': center_point.y,
                'center_lon': center_point.x,
                'resolution_meters': resolution_meters,
                'row': row,
                'col': col,
                'bounds': cell_bounds
            })
            
            lon += resolution_degrees
            col += 1
        
        lat += resolution_degrees
        row += 1
    
    logger.info(f"Created {len(grid_cells)} grid cells with {resolution_meters}m resolution")
    return grid_cells


def calculate_distance(point1: Tuple[float, float], 
                      point2: Tuple[float, float]) -> float:
    """
    Calculate Haversine distance between two points in kilometers
    
    Args:
        point1: (latitude, longitude)
        point2: (latitude, longitude)
    
    Returns:
        Distance in kilometers
    """
    from math import radians, cos, sin, asin, sqrt
    
    lat1, lon1 = point1
    lat2, lon2 = point2
    
    # Convert to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    
    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    
    # Radius of Earth in kilometers
    r = 6371
    
    return c * r


def buffer_point(point_wkt: str, buffer_km: float) -> str:
    """
    Create a buffer around a point
    
    Args:
        point_wkt: Point geometry in WKT format
        buffer_km: Buffer distance in kilometers
    
    Returns:
        Buffered polygon in WKT format
    """
    try:
        point = wkt_loads(point_wkt)
        # Convert km to degrees (approximate)
        buffer_degrees = buffer_km / 111.0
        buffered = point.buffer(buffer_degrees)
        return buffered.wkt
    except Exception as e:
        logger.error(f"Error buffering point: {str(e)}")
        return point_wkt


def polygons_to_geojson(polygons: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Convert polygon data to GeoJSON format
    
    Args:
        polygons: List of polygon dictionaries with 'geometry' and properties
    
    Returns:
        GeoJSON FeatureCollection
    """
    features = []
    
    for polygon_data in polygons:
        try:
            geometry_wkt = polygon_data.get('geometry', '')
            properties = {k: v for k, v in polygon_data.items() if k != 'geometry'}
            
            geometry = wkt_loads(geometry_wkt)
            
            # Convert to GeoJSON format
            if geometry.geom_type == 'Polygon':
                geojson_geom = {
                    "type": "Polygon",
                    "coordinates": [list(geometry.exterior.coords)]
                }
            elif geometry.geom_type == 'MultiPolygon':
                geojson_geom = {
                    "type": "MultiPolygon",
                    "coordinates": [[list(poly.exterior.coords) for poly in geometry.geoms]]
                }
            else:
                continue
            
            feature = {
                "type": "Feature",
                "geometry": geojson_geom,
                "properties": properties
            }
            
            features.append(feature)
            
        except Exception as e:
            logger.warning(f"Error converting polygon to GeoJSON: {str(e)}")
            continue
    
    return {
        "type": "FeatureCollection",
        "features": features
    }


def intersect_polygons(polygon1_wkt: str, polygon2_wkt: str) -> Dict[str, Any]:
    """
    Calculate intersection between two polygons
    
    Args:
        polygon1_wkt: First polygon in WKT format
        polygon2_wkt: Second polygon in WKT format
    
    Returns:
        Dictionary with intersection information
    """
    try:
        poly1 = wkt_loads(polygon1_wkt)
        poly2 = wkt_loads(polygon2_wkt)
        
        if not poly1.intersects(poly2):
            return {
                'intersects': False,
                'intersection_area': 0.0,
                'intersection_percentage': 0.0
            }
        
        intersection = poly1.intersection(poly2)
        intersection_area = intersection.area
        poly1_area = poly1.area
        
        intersection_percentage = (intersection_area / poly1_area * 100) if poly1_area > 0 else 0
        
        return {
            'intersects': True,
            'intersection_area': intersection_area,
            'intersection_percentage': round(intersection_percentage, 2),
            'intersection_geometry': intersection.wkt
        }
        
    except Exception as e:
        logger.error(f"Error calculating polygon intersection: {str(e)}")
        return {
            'intersects': False,
            'error': str(e)
        }


def find_nearest_features(point_wkt: str, features: List[Dict[str, Any]], 
                         max_distance_km: float = 50.0) -> List[Dict[str, Any]]:
    """
    Find nearest features to a point
    
    Args:
        point_wkt: Point geometry in WKT format
        features: List of feature dictionaries with 'geometry'
        max_distance_km: Maximum search distance in kilometers
    
    Returns:
        List of features sorted by distance, with distance added
    """
    try:
        point = wkt_loads(point_wkt)
        point_coords = (point.y, point.x)
        
        nearby_features = []
        
        for feature in features:
            try:
                feature_geom = wkt_loads(feature.get('geometry', ''))
                
                # For point-to-point distance, use direct calculation
                if feature_geom.geom_type == 'Point':
                    feature_coords = (feature_geom.y, feature_geom.x)
                    distance = calculate_distance(point_coords, feature_coords)
                else:
                    # For other geometry types, find nearest point
                    nearest_point = feature_geom.nearest(point)
                    nearest_coords = (nearest_point.y, nearest_point.x)
                    distance = calculate_distance(point_coords, nearest_coords)
                
                if distance <= max_distance_km:
                    feature_with_distance = feature.copy()
                    feature_with_distance['distance_km'] = round(distance, 2)
                    nearby_features.append(feature_with_distance)
                    
            except Exception as e:
                logger.warning(f"Error processing feature: {str(e)}")
                continue
        
        # Sort by distance
        nearby_features.sort(key=lambda x: x['distance_km'])
        
        return nearby_features
        
    except Exception as e:
        logger.error(f"Error finding nearest features: {str(e)}")
        return []


def calculate_centroid(polygon_wkt: str) -> Tuple[float, float]:
    """
    Calculate centroid of a polygon
    
    Args:
        polygon_wkt: Polygon geometry in WKT format
    
    Returns:
        Tuple of (latitude, longitude)
    """
    try:
        polygon = wkt_loads(polygon_wkt)
        centroid = polygon.centroid
        return (centroid.y, centroid.x)
    except Exception as e:
        logger.error(f"Error calculating centroid: {str(e)}")
        return (0.0, 0.0)


def calculate_area(polygon_wkt: str) -> float:
    """
    Calculate area of a polygon in square kilometers
    
    Args:
        polygon_wkt: Polygon geometry in WKT format
    
    Returns:
        Area in square kilometers
    """
    try:
        polygon = wkt_loads(polygon_wkt)
        # Convert from degrees to square kilometers (approximate)
        area_degrees = polygon.area
        area_sq_km = area_degrees * (111.0 * 111.0)  # Rough conversion
        return round(area_sq_km, 3)
    except Exception as e:
        logger.error(f"Error calculating area: {str(e)}")
        return 0.0


def simplify_geometry(geometry_wkt: str, tolerance: float = 0.0001) -> str:
    """
    Simplify a geometry while preserving its basic shape
    
    Args:
        geometry_wkt: Geometry in WKT format
        tolerance: Simplification tolerance in degrees
    
    Returns:
        Simplified geometry in WKT format
    """
    try:
        geometry = wkt_loads(geometry_wkt)
        simplified = geometry.simplify(tolerance, preserve_topology=True)
        return simplified.wkt
    except Exception as e:
        logger.error(f"Error simplifying geometry: {str(e)}")
        return geometry_wkt


def cluster_points(points: List[Tuple[float, float]], 
                  eps: float = 0.01, 
                  min_samples: int = 3) -> List[List[int]]:
    """
    Cluster points using DBSCAN algorithm
    
    Args:
        points: List of (latitude, longitude) tuples
        eps: Maximum distance between points in same cluster (degrees)
        min_samples: Minimum points required to form a cluster
    
    Returns:
        List of clusters, where each cluster is a list of point indices
    """
    try:
        from sklearn.cluster import DBSCAN
        
        if not points:
            return []
        
        # Convert to numpy array
        points_array = np.array(points)
        
        # Perform clustering
        clustering = DBSCAN(eps=eps, min_samples=min_samples).fit(points_array)
        labels = clustering.labels_
        
        # Group points by cluster
        clusters = {}
        for idx, label in enumerate(labels):
            if label != -1:  # Ignore noise points
                if label not in clusters:
                    clusters[label] = []
                clusters[label].append(idx)
        
        return list(clusters.values())
        
    except Exception as e:
        logger.error(f"Error clustering points: {str(e)}")
        return []


def create_convex_hull(points: List[Tuple[float, float]]) -> str:
    """
    Create convex hull from a set of points
    
    Args:
        points: List of (latitude, longitude) tuples
    
    Returns:
        Convex hull polygon in WKT format
    """
    try:
        from shapely.geometry import MultiPoint
        
        if len(points) < 3:
            logger.warning("Need at least 3 points to create convex hull")
            return ""
        
        # Convert to (lon, lat) for shapely
        shapely_points = [(lon, lat) for lat, lon in points]
        multi_point = MultiPoint(shapely_points)
        convex_hull = multi_point.convex_hull
        
        return convex_hull.wkt
        
    except Exception as e:
        logger.error(f"Error creating convex hull: {str(e)}")
        return ""
"""
Abstract database repository pattern for spatial operations
This pattern allows seamless transition between Python-side spatial operations (development)
and database-level PostGIS operations (production)
"""
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional, Tuple
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class DatabaseBackend(Enum):
    """Database backend types"""
    SQLITE = "sqlite"
    POSTGIS = "postgis"


class SpatialRepository(ABC):
    """Abstract base class for spatial repository operations"""
    
    def __init__(self, backend: DatabaseBackend = DatabaseBackend.SQLITE):
        self.backend = backend
        self._initialize_backend()
    
    def _initialize_backend(self):
        """Initialize the appropriate backend"""
        if self.backend == DatabaseBackend.SQLITE:
            logger.info("Using Python-side spatial operations (SQLite backend)")
        elif self.backend == DatabaseBackend.POSTGIS:
            logger.info("Using database-level PostGIS operations")
        else:
            raise ValueError(f"Unknown backend: {self.backend}")
    
    @abstractmethod
    def calculate_distance(self, point1: Tuple[float, float], 
                          point2: Tuple[float, float]) -> float:
        """Calculate distance between two points"""
        pass
    
    @abstractmethod
    def intersects_polygon(self, geometry_wkt: str, 
                          polygon_wkt: str) -> Dict[str, Any]:
        """Check if geometry intersects with polygon"""
        pass
    
    @abstractmethod
    def buffer_point(self, point_wkt: str, buffer_distance: float) -> str:
        """Buffer a point by given distance"""
        pass
    
    @abstractmethod
    def create_grid(self, bounds: Tuple[float, float, float, float], 
                   resolution: float) -> List[Dict[str, Any]]:
        """Create spatial grid for region"""
        pass
    
    @abstractmethod
    def find_nearest(self, point_wkt: str, features: List[Dict[str, Any]], 
                    max_distance: float) -> List[Dict[str, Any]]:
        """Find nearest features to a point"""
        pass


class PythonSpatialRepository(SpatialRepository):
    """Python-side spatial operations using Shapely (for SQLite/development)"""
    
    def __init__(self):
        super().__init__(DatabaseBackend.SQLITE)
        self._load_spatial_libraries()
    
    def _load_spatial_libraries(self):
        """Load Shapely and other spatial libraries"""
        try:
            from shapely.geometry import Point, Polygon
            from shapely.wkt import loads as wkt_loads, dumps as wkt_dumps
            from shapely.ops import unary_union
            from shapely import __version__ as shapely_version
            self.Point = Point
            self.Polygon = Polygon
            self.wkt_loads = wkt_loads
            self.wkt_dumps = wkt_dumps
            self.unary_union = unary_union
            logger.info(f"Shapely {shapely_version} loaded successfully")
        except ImportError as e:
            logger.error(f"Failed to load spatial libraries: {e}")
            raise
    
    def calculate_distance(self, point1: Tuple[float, float], 
                          point2: Tuple[float, float]) -> float:
        """Calculate Haversine distance between two points in kilometers"""
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
    
    def intersects_polygon(self, geometry_wkt: str, 
                          polygon_wkt: str) -> Dict[str, Any]:
        """Check if geometry intersects with polygon"""
        try:
            geom = self.wkt_loads(geometry_wkt)
            polygon = self.wkt_loads(polygon_wkt)
            
            if not geom.intersects(polygon):
                return {
                    'intersects': False,
                    'intersection_area': 0.0,
                    'intersection_percentage': 0.0
                }
            
            intersection = geom.intersection(polygon)
            intersection_area = intersection.area
            geom_area = geom.area
            
            intersection_percentage = (intersection_area / geom_area * 100) if geom_area > 0 else 0
            
            return {
                'intersects': True,
                'intersection_area': intersection_area,
                'intersection_percentage': round(intersection_percentage, 2),
                'intersection_geometry': intersection.wkt
            }
        except Exception as e:
            logger.error(f"Error in polygon intersection: {str(e)}")
            return {
                'intersects': False,
                'error': str(e)
            }
    
    def buffer_point(self, point_wkt: str, buffer_distance: float) -> str:
        """Buffer a point by given distance in kilometers"""
        try:
            point = self.wkt_loads(point_wkt)
            # Convert km to degrees (approximate)
            buffer_degrees = buffer_distance / 111.0
            buffered = point.buffer(buffer_degrees)
            return buffered.wkt
        except Exception as e:
            logger.error(f"Error buffering point: {str(e)}")
            return point_wkt
    
    def create_grid(self, bounds: Tuple[float, float, float, float], 
                   resolution: float) -> List[Dict[str, Any]]:
        """Create spatial grid for region using Python"""
        min_lon, min_lat, max_lon, max_lat = bounds
        
        # Convert resolution to degrees (approximate)
        resolution_degrees = resolution / 111000.0
        
        grid_cells = []
        
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
                
                cell_polygon = self.Polygon(cell_bounds)
                center_point = cell_polygon.centroid
                
                grid_cells.append({
                    'grid_id': f"GRID_{row}_{col}",
                    'geometry': cell_polygon.wkt,
                    'center_lat': center_point.y,
                    'center_lon': center_point.x,
                    'resolution_meters': resolution,
                    'row': row,
                    'col': col,
                    'bounds': cell_bounds
                })
                
                lon += resolution_degrees
                col += 1
            
            lat += resolution_degrees
            row += 1
        
        return grid_cells
    
    def find_nearest(self, point_wkt: str, features: List[Dict[str, Any]], 
                    max_distance: float) -> List[Dict[str, Any]]:
        """Find nearest features to a point using Python"""
        try:
            point = self.wkt_loads(point_wkt)
            point_coords = (point.y, point.x)
            
            nearby_features = []
            
            for feature in features:
                try:
                    feature_geom = self.wkt_loads(feature.get('geometry', ''))
                    
                    # Get nearest point on feature
                    nearest_point = feature_geom.nearest(point)
                    nearest_coords = (nearest_point.y, nearest_point.x)
                    
                    # Calculate distance
                    distance = self.calculate_distance(point_coords, nearest_coords)
                    
                    if distance <= max_distance:
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


class PostGISSpatialRepository(SpatialRepository):
    """Database-level PostGIS operations (for production)"""
    
    def __init__(self, db_session):
        super().__init__(DatabaseBackend.POSTGIS)
        self.db = db_session
    
    def calculate_distance(self, point1: Tuple[float, float], 
                          point2: Tuple[float, float]) -> float:
        """Calculate distance using PostGIS ST_DistanceSphere"""
        try:
            from sqlalchemy import text
            query = text("""
                SELECT ST_DistanceSphere(
                    ST_SetSRID(ST_MakePoint(:lon1, :lat1), 4326),
                    ST_SetSRID(ST_MakePoint(:lon2, :lat2), 4326)
                ) / 1000 as distance_km
            """)
            result = self.db.execute(query, {
                'lat1': point1[0], 'lon1': point1[1],
                'lat2': point2[0], 'lon2': point2[1]
            })
            return float(result.scalar())
        except Exception as e:
            logger.error(f"PostGIS distance calculation failed: {e}")
            # Fallback to Python calculation
            return PythonSpatialRepository().calculate_distance(point1, point2)
    
    def intersects_polygon(self, geometry_wkt: str, 
                          polygon_wkt: str) -> Dict[str, Any]:
        """Check intersection using PostGIS ST_Intersects"""
        try:
            from sqlalchemy import text
            query = text("""
                SELECT 
                    ST_Intersects(
                        ST_GeomFromText(:geom1, 4326),
                        ST_GeomFromText(:geom2, 4326)
                ) as intersects,
                    ST_Area(
                        ST_Intersection(
                            ST_GeomFromText(:geom1, 4326),
                            ST_GeomFromText(:geom2, 4326)
                        )
                    ) / ST_Area(ST_GeomFromText(:geom1, 4326)) * 100 as intersection_percentage
            """)
            result = self.db.execute(query, {'geom1': geometry_wkt, 'geom2': polygon_wkt})
            row = result.fetchone()
            
            return {
                'intersects': bool(row[0]),
                'intersection_percentage': round(float(row[1]) if row[1] else 0, 2)
            }
        except Exception as e:
            logger.error(f"PostGIS intersection check failed: {e}")
            # Fallback to Python calculation
            return PythonSpatialRepository().intersects_polygon(geometry_wkt, polygon_wkt)
    
    def buffer_point(self, point_wkt: str, buffer_distance: float) -> str:
        """Buffer point using PostGIS ST_Buffer"""
        try:
            from sqlalchemy import text
            query = text("""
                SELECT ST_AsText(
                    ST_Buffer(
                        ST_GeomFromText(:geom, 4326),
                        :buffer / 111.0,
                        'quad_segs=8'
                    )
                ) as buffered_geom
            """)
            result = self.db.execute(query, {'geom': point_wkt, 'buffer': buffer_distance})
            return result.scalar()
        except Exception as e:
            logger.error(f"PostGIS buffer failed: {e}")
            # Fallback to Python calculation
            return PythonSpatialRepository().buffer_point(point_wkt, buffer_distance)
    
    def create_grid(self, bounds: Tuple[float, float, float, float], 
                   resolution: float) -> List[Dict[str, Any]]:
        """Create grid using PostGIS spatial functions"""
        # For now, fallback to Python implementation
        # Could be enhanced with PostGIS ST_SquareGrid in future
        return PythonSpatialRepository().create_grid(bounds, resolution)
    
    def find_nearest(self, point_wkt: str, features: List[Dict[str, Any]], 
                    max_distance: float) -> List[Dict[str, Any]]:
        """Find nearest features using PostGIS ST_Distance"""
        # For now, fallback to Python implementation
        # Could be enhanced with PostGIS KNN functions in future
        return PythonSpatialRepository().find_nearest(point_wkt, features, max_distance)


class SpatialRepositoryFactory:
    """Factory for creating appropriate spatial repository"""
    
    @staticmethod
    def create_repository(db_session=None, backend: DatabaseBackend = DatabaseBackend.SQLITE) -> SpatialRepository:
        """Create spatial repository based on backend type"""
        if backend == DatabaseBackend.POSTGIS and db_session:
            return PostGISSpatialRepository(db_session)
        else:
            return PythonSpatialRepository()
    
    @staticmethod
    def get_backend_from_config() -> DatabaseBackend:
        """Determine backend from configuration"""
        from app.core.config import settings
        
        if settings.database_url.startswith('postgresql'):
            return DatabaseBackend.POSTGIS
        elif settings.database_url.startswith('sqlite'):
            return DatabaseBackend.SQLITE
        else:
            logger.warning(f"Unknown database URL format, defaulting to SQLite")
            return DatabaseBackend.SQLITE


# Global repository instance
_spatial_repository: Optional[SpatialRepository] = None


def get_spatial_repository(db_session=None) -> SpatialRepository:
    """Get the appropriate spatial repository for current configuration"""
    global _spatial_repository
    
    if _spatial_repository is None:
        backend = SpatialRepositoryFactory.get_backend_from_config()
        _spatial_repository = SpatialRepositoryFactory.create_repository(db_session, backend)
    
    return _spatial_repository


def reset_spatial_repository():
    """Reset the spatial repository (useful for testing)"""
    global _spatial_repository
    _spatial_repository = None
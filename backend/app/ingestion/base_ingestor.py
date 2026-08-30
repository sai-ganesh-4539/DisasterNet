"""
Base class for data ingestion
"""
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any
from datetime import datetime
import logging
from sqlalchemy.orm import Session
from app.models.database import SessionLocal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BaseIngestor(ABC):
    """Abstract base class for data ingestion"""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self.logger = logger
        self.db = SessionLocal()
    
    @abstractmethod
    def fetch_data(self) -> List[Dict[str, Any]]:
        """Fetch data from the source"""
        pass
    
    @abstractmethod
    def validate_data(self, data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Validate and clean the data"""
        pass
    
    @abstractmethod
    def transform_data(self, data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Transform data to database format"""
        pass
    
    @abstractmethod
    def save_data(self, data: List[Dict[str, Any]]) -> bool:
        """Save data to database"""
        pass
    
    def log_ingestion(self, status: str, record_count: int = 0, 
                     error_message: Optional[str] = None) -> None:
        """Log ingestion operation"""
        log_entry = {
            'data_source': self.__class__.__name__,
            'status': status,
            'record_count': record_count,
            'error_message': error_message,
            'timestamp': datetime.utcnow().isoformat()
        }
        self.logger.info(f"Ingestion log: {log_entry}")
    
    def ingest(self) -> Dict[str, Any]:
        """Main ingestion pipeline"""
        result = {
            'success': False,
            'records_processed': 0,
            'errors': [],
            'start_time': datetime.utcnow(),
            'end_time': None
        }
        
        try:
            self.logger.info(f"Starting ingestion for {self.__class__.__name__}")
            
            # Fetch data
            raw_data = self.fetch_data()
            self.logger.info(f"Fetched {len(raw_data)} records")
            
            # Validate data
            validated_data = self.validate_data(raw_data)
            self.logger.info(f"Validated {len(validated_data)} records")
            
            # Transform data
            transformed_data = self.transform_data(validated_data)
            self.logger.info(f"Transformed {len(transformed_data)} records")
            
            # Save data
            save_success = self.save_data(transformed_data)
            
            if save_success:
                result['success'] = True
                result['records_processed'] = len(transformed_data)
                self.log_ingestion('COMPLETED', len(transformed_data))
            else:
                result['errors'].append('Failed to save data to database')
                self.log_ingestion('FAILED', 0, 'Failed to save data')
                
        except Exception as e:
            error_msg = f"Ingestion failed: {str(e)}"
            result['errors'].append(error_msg)
            self.logger.error(error_msg, exc_info=True)
            self.log_ingestion('FAILED', 0, error_msg)
        
        finally:
            result['end_time'] = datetime.utcnow()
            self.db.close()
        
        return result
    
    def __del__(self):
        """Cleanup database connection"""
        if hasattr(self, 'db'):
            self.db.close()
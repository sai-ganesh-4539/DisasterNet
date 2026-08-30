"""
Data ingestion scheduler
"""
import schedule
import time
import logging
from typing import Dict, Any
from datetime import datetime
from app.ingestion.isro_bhuvan import ISROBhuvanIngestor
from app.ingestion.imd_rainfall import IMDRainfallIngestor
from app.ingestion.census_data import CensusDataIngestor
from app.core.config import settings, yaml_config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataIngestionScheduler:
    """Scheduler for automated data ingestion"""
    
    def __init__(self):
        self.is_running = False
        self.ingestion_config = yaml_config.get('data_ingestion', {})
    
    def schedule_isro_bhuvan(self):
        """Schedule ISRO Bhuvan data ingestion"""
        config = self.ingestion_config.get('isro_bhuvan', {})
        
        if not config.get('enabled', True):
            logger.info("ISRO Bhuvan ingestion is disabled")
            return
        
        frequency = config.get('update_frequency', 'weekly')
        
        if frequency == 'daily':
            schedule.every().day.at("02:00").do(self._run_isro_ingestion)
        elif frequency == 'weekly':
            schedule.every().sunday.at("02:00").do(self._run_isro_ingestion)
        elif frequency == 'monthly':
            schedule.every().month.do(self._run_isro_ingestion)
        else:
            logger.warning(f"Unknown frequency for ISRO Bhuvan: {frequency}")
        
        logger.info(f"Scheduled ISRO Bhuvan ingestion with frequency: {frequency}")
    
    def schedule_imd_rainfall(self):
        """Schedule IMD rainfall data ingestion"""
        config = self.ingestion_config.get('imd_rainfall', {})
        
        if not config.get('enabled', True):
            logger.info("IMD rainfall ingestion is disabled")
            return
        
        frequency = config.get('update_frequency', 'hourly')
        
        if frequency == 'hourly':
            schedule.every().hour.do(self._run_imd_ingestion)
        elif frequency == 'daily':
            schedule.every().day.at("01:00").do(self._run_imd_ingestion)
        elif frequency == 'realtime':
            # For realtime, run every 15 minutes
            schedule.every(15).minutes.do(self._run_imd_ingestion)
        else:
            logger.warning(f"Unknown frequency for IMD rainfall: {frequency}")
        
        logger.info(f"Scheduled IMD rainfall ingestion with frequency: {frequency}")
    
    def schedule_census_data(self):
        """Schedule Census data ingestion"""
        config = self.ingestion_config.get('census', {})
        
        if not config.get('enabled', True):
            logger.info("Census data ingestion is disabled")
            return
        
        frequency = config.get('update_frequency', 'yearly')
        
        if frequency == 'yearly':
            schedule.every().year.do(self._run_census_ingestion)
        elif frequency == 'monthly':
            schedule.every().month.do(self._run_census_ingestion)
        elif frequency == 'manual':
            logger.info("Census data ingestion set to manual only")
        else:
            logger.warning(f"Unknown frequency for Census data: {frequency}")
        
        logger.info(f"Scheduled Census data ingestion with frequency: {frequency}")
    
    def _run_isro_ingestion(self):
        """Run ISRO Bhuvan ingestion"""
        logger.info("Starting ISRO Bhuvan ingestion job")
        try:
            config = self.ingestion_config.get('isro_bhuvan', {})
            ingestor = ISROBhuvanIngestor(config)
            result = ingestor.ingest()
            logger.info(f"ISRO Bhuvan ingestion completed: {result}")
        except Exception as e:
            logger.error(f"ISRO Bhuvan ingestion failed: {str(e)}")
    
    def _run_imd_ingestion(self):
        """Run IMD rainfall ingestion"""
        logger.info("Starting IMD rainfall ingestion job")
        try:
            config = self.ingestion_config.get('imd_rainfall', {})
            ingestor = IMDRainfallIngestor(config)
            result = ingestor.ingest()
            logger.info(f"IMD rainfall ingestion completed: {result}")
        except Exception as e:
            logger.error(f"IMD rainfall ingestion failed: {str(e)}")
    
    def _run_census_ingestion(self):
        """Run Census data ingestion"""
        logger.info("Starting Census data ingestion job")
        try:
            config = self.ingestion_config.get('census', {})
            ingestor = CensusDataIngestor(config)
            result = ingestor.ingest()
            logger.info(f"Census data ingestion completed: {result}")
        except Exception as e:
            logger.error(f"Census data ingestion failed: {str(e)}")
    
    def setup_all_schedules(self):
        """Set up all ingestion schedules"""
        logger.info("Setting up data ingestion schedules")
        self.schedule_isro_bhuvan()
        self.schedule_imd_rainfall()
        self.schedule_census_data()
        
        # Display scheduled jobs
        logger.info("Scheduled jobs:")
        for job in schedule.jobs:
            logger.info(f"  - {job}")
    
    def run_scheduled_jobs(self):
        """Run scheduled jobs (blocking call)"""
        logger.info("Starting scheduler")
        self.is_running = True
        
        try:
            while self.is_running:
                schedule.run_pending()
                time.sleep(60)  # Check every minute
        except KeyboardInterrupt:
            logger.info("Scheduler stopped by user")
        except Exception as e:
            logger.error(f"Scheduler error: {str(e)}")
        finally:
            self.is_running = False
    
    def stop(self):
        """Stop the scheduler"""
        logger.info("Stopping scheduler")
        self.is_running = False
        schedule.clear()
    
    def run_manual_ingestion(self, source: str) -> Dict[str, Any]:
        """Run manual ingestion for a specific source"""
        logger.info(f"Running manual ingestion for: {source}")
        
        try:
            if source == 'isro_bhuvan':
                config = self.ingestion_config.get('isro_bhuvan', {})
                ingestor = ISROBhuvanIngestor(config)
            elif source == 'imd_rainfall':
                config = self.ingestion_config.get('imd_rainfall', {})
                ingestor = IMDRainfallIngestor(config)
            elif source == 'census':
                config = self.ingestion_config.get('census', {})
                ingestor = CensusDataIngestor(config)
            else:
                return {'success': False, 'error': f'Unknown source: {source}'}
            
            result = ingestor.ingest()
            return result
            
        except Exception as e:
            logger.error(f"Manual ingestion failed for {source}: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def get_next_run_time(self, source: str) -> str:
        """Get next scheduled run time for a source"""
        for job in schedule.jobs:
            if source.lower() in str(job).lower():
                return job.next_run.strftime("%Y-%m-%d %H:%M:%S")
        return "Not scheduled"


def main():
    """Main entry point for running the scheduler"""
    scheduler = DataIngestionScheduler()
    scheduler.setup_all_schedules()
    
    # Run one-time ingestion on startup
    logger.info("Running initial data ingestion on startup")
    scheduler.run_manual_ingestion('imd_rainfall')
    
    # Start the scheduler
    scheduler.run_scheduled_jobs()


if __name__ == "__main__":
    main()
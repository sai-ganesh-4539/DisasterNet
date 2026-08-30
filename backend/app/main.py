"""
Main FastAPI application for Disaster Management Platform
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging
from contextlib import asynccontextmanager
from app.core.config import settings
from app.ml.model_registry import initialize_models

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events"""
    # Startup
    logger.info("Starting Disaster Management Platform API")
    
    # Initialize ML models
    try:
        model_load_results = initialize_models()
        logger.info(f"ML models initialized: {model_load_results}")
    except Exception as e:
        logger.error(f"Error initializing ML models: {str(e)}")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Disaster Management Platform API")


# Create FastAPI application
app = FastAPI(
    title="Disaster Management Platform API",
    description="AI-driven GIS platform for hazard identification, carrying capacity assessment, and relocation prioritization",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "Disaster Management Platform API",
        "version": "1.0.0"
    }


# Include API routers
from app.api.v1.api import api_router

app.include_router(api_router, prefix="/api/v1")


# Global exception handlers
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "error": str(exc) if settings.debug else "An error occurred"
        }
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "backend.app.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.api_reload
    )
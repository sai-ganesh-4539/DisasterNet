-- Spatial Extensions Setup
-- This script enables required PostgreSQL extensions for spatial data processing

-- Enable PostGIS for spatial data types and functions
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable PostGIS topology for advanced spatial operations
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Enable UUID extension for generating unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for cryptographic functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enable btree_gist for GiST indexes on scalar data types
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Enable unaccent for text processing (useful for location names)
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Verify installation
SELECT postgis_version();

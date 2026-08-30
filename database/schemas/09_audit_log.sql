-- System Audit Log Schema
-- This schema provides comprehensive audit logging for compliance and security

-- Note: The audit_log table is already created in 08_users_roles.sql
-- This file contains additional audit-related tables and functions

-- Data change log table (for tracking data modifications)
CREATE TABLE data_change_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    change_id VARCHAR(100) UNIQUE NOT NULL,  -- Unique change identifier
    
    -- Change details
    table_name VARCHAR(100) NOT NULL,  -- Table that was changed
    operation_type VARCHAR(20) NOT NULL,  -- Operation: INSERT, UPDATE, DELETE
    record_id VARCHAR(100),  -- ID of the affected record
    
    -- Data snapshots
    old_data JSONB,  -- Previous data state
    new_data JSONB,  -- New data state
    changed_columns TEXT[],  -- List of changed columns
    
    -- Context
    user_id UUID,  -- User who made the change
    username VARCHAR(100),  -- Username
    role_name VARCHAR(50),  -- Role at time of change
    ip_address VARCHAR(45),  -- IP address
    user_agent TEXT,  -- User agent
    
    -- Business context
    change_reason TEXT,  -- Reason for the change
    business_process VARCHAR(100),  -- Business process that triggered change
    correlation_id VARCHAR(100),  -- Correlation ID for related changes
    
    -- Approval workflow
    requires_approval BOOLEAN DEFAULT FALSE,  -- Whether change required approval
    approved_by VARCHAR(100),  -- User who approved
    approved_at TIMESTAMP WITH TIME ZONE,  -- Approval timestamp
    approval_status VARCHAR(20),  -- Approval status: PENDING, APPROVED, REJECTED
    
    -- Timing
    change_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processing_time_ms INTEGER,  -- Processing time
    
    -- Replication status
    replicated BOOLEAN DEFAULT FALSE,  -- Whether change has been replicated
    replication_timestamp TIMESTAMP WITH TIME ZONE,  -- Replication timestamp
    
    -- Metadata
    source_system VARCHAR(50),  -- Source system: API, WEB, BATCH, SYNC
    additional_data JSONB  -- Additional context
);

-- ML model prediction log table
CREATE TABLE ml_prediction_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prediction_id VARCHAR(100) UNIQUE NOT NULL,  -- Unique prediction identifier
    
    -- Model information
    model_name VARCHAR(100) NOT NULL,  -- Model name
    model_version VARCHAR(50),  -- Model version
    model_type VARCHAR(50) NOT NULL,  -- Model type: HAZARD_PREDICTOR, CAPACITY_EVALUATOR, PRIORITY_CLASSIFIER
    
    -- Input data
    input_data JSONB NOT NULL,  -- Input features
    input_grid_id VARCHAR(50),  -- Grid ID if applicable
    input_habitation_id VARCHAR(50),  -- Habitation ID if applicable
    input_shelter_id VARCHAR(50),  -- Shelter ID if applicable
    
    -- Prediction results
    prediction_result JSONB NOT NULL,  -- Prediction output
    prediction_score DECIMAL(5, 2),  -- Primary prediction score
    prediction_class VARCHAR(50),  -- Predicted class
    confidence_score DECIMAL(5, 2),  -- Model confidence (0-100)
    
    -- Performance metrics
    inference_time_ms INTEGER,  -- Inference time in milliseconds
    memory_used_mb DECIMAL(8, 2),  -- Memory used in MB
    
    -- Context
    prediction_context TEXT,  -- Context for prediction
    triggered_by VARCHAR(100),  -- User or system that triggered prediction
    prediction_reason TEXT,  -- Reason for prediction
    
    -- Timing
    prediction_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Metadata
    model_parameters JSONB,  -- Model parameters used
    additional_data JSONB  -- Additional context
);

-- Data ingestion log table
CREATE TABLE data_ingestion_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ingestion_id VARCHAR(100) UNIQUE NOT NULL,  -- Unique ingestion identifier
    
    -- Source information
    data_source VARCHAR(50) NOT NULL,  -- Data source: ISRO_BHUVAN, IMD, CENSUS
    source_type VARCHAR(50) NOT NULL,  -- Source type: API, BATCH, MANUAL
    source_endpoint VARCHAR(255),  -- Source API endpoint or file path
    
    -- Data details
    data_type VARCHAR(50) NOT NULL,  -- Data type: TERRAIN, WEATHER, CENSUS
    record_count INTEGER,  -- Number of records processed
    data_size_bytes BIGINT,  -- Size of data in bytes
    
    -- Processing details
    processing_status VARCHAR(20) NOT NULL,  -- Status: STARTED, IN_PROGRESS, COMPLETED, FAILED
    processing_stage VARCHAR(50),  -- Current processing stage
    error_count INTEGER DEFAULT 0,  -- Number of errors
    warning_count INTEGER DEFAULT 0,  -- Number of warnings
    
    -- Time metrics
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,  -- Start time
    completed_at TIMESTAMP WITH TIME ZONE,  -- Completion time
    duration_seconds INTEGER,  -- Duration in seconds
    
    -- Quality metrics
    quality_score DECIMAL(5, 2),  -- Data quality score (0-100)
    validation_passed INTEGER,  -- Number of records that passed validation
    validation_failed INTEGER,  -- Number of records that failed validation
    
    -- Error details
    error_message TEXT,  -- Error message if failed
    error_details JSONB,  -- Detailed error information
    
    -- Trigger information
    triggered_by VARCHAR(100),  -- User or system that triggered ingestion
    trigger_type VARCHAR(50),  -- Trigger type: SCHEDULED, MANUAL, API
    
    -- Metadata
    correlation_id VARCHAR(100),  -- Correlation ID for tracking
    additional_data JSONB  -- Additional context
);

-- System performance log table
CREATE TABLE system_performance_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    performance_id VARCHAR(100) UNIQUE NOT NULL,  -- Unique performance identifier
    
    -- Request information
    endpoint_path VARCHAR(255),  -- API endpoint path
    request_method VARCHAR(10),  -- HTTP method
    request_size_bytes BIGINT,  -- Request size in bytes
    response_size_bytes BIGINT,  -- Response size in bytes
    
    -- Performance metrics
    response_time_ms INTEGER NOT NULL,  -- Response time in milliseconds
    db_query_time_ms INTEGER,  -- Database query time
    ml_inference_time_ms INTEGER,  -- ML inference time
    
    -- System metrics
    cpu_usage_percentage DECIMAL(5, 2),  -- CPU usage percentage
    memory_usage_mb DECIMAL(10, 2),  -- Memory usage in MB
    disk_io_mb DECIMAL(10, 2),  -- Disk I/O in MB
    
    -- Request context
    user_id UUID,  -- User ID if authenticated
    ip_address VARCHAR(45),  -- Client IP address
    user_agent TEXT,  -- User agent string
    
    -- Status
    http_status_code INTEGER,  -- HTTP status code
    status VARCHAR(20) NOT NULL,  -- Status: SUCCESS, ERROR, TIMEOUT
    
    -- Error information
    error_type VARCHAR(100),  -- Error type
    error_message TEXT,  -- Error message
    error_stack_trace TEXT,  -- Error stack trace
    
    -- Timing
    request_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Metadata
    correlation_id VARCHAR(100),  -- Correlation ID for tracking
    additional_data JSONB  -- Additional context
);

-- Alert log table
CREATE TABLE alert_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_id VARCHAR(100) UNIQUE NOT NULL,  -- Unique alert identifier
    
    -- Alert details
    alert_type VARCHAR(50) NOT NULL,  -- Alert type: RED_ZONE_CREATED, HIGH_RISK, SYSTEM_ERROR
    alert_severity VARCHAR(20) NOT NULL,  -- Severity: INFO, WARNING, ERROR, CRITICAL
    alert_title VARCHAR(200) NOT NULL,  -- Alert title
    alert_message TEXT NOT NULL,  -- Alert message
    
    -- Alert context
    affected_resource_type VARCHAR(50),  -- Affected resource type
    affected_resource_id VARCHAR(100),  -- Affected resource ID
    geographic_scope VARCHAR(50),  -- Geographic scope: NATIONAL, STATE, DISTRICT
    state_code VARCHAR(10),  -- State code if applicable
    district_code VARCHAR(10),  -- District code if applicable
    
    -- Alert triggering
    trigger_condition TEXT,  -- Condition that triggered alert
    trigger_value DECIMAL(10, 2),  -- Value that triggered alert
    threshold_value DECIMAL(10, 2),  -- Threshold that was exceeded
    
    -- Notification status
    notification_sent BOOLEAN DEFAULT FALSE,  -- Whether notification was sent
    notification_channels TEXT[],  -- Channels used: EMAIL, SMS, API
    notification_timestamp TIMESTAMP WITH TIME ZONE,  -- Notification timestamp
    recipients TEXT[],  -- Alert recipients
    
    -- Alert lifecycle
    acknowledged BOOLEAN DEFAULT FALSE,  -- Whether alert was acknowledged
    acknowledged_by VARCHAR(100),  -- User who acknowledged
    acknowledged_at TIMESTAMP WITH TIME ZONE,  -- Acknowledgment timestamp
    resolved BOOLEAN DEFAULT FALSE,  -- Whether alert was resolved
    resolved_by VARCHAR(100),  -- User who resolved
    resolved_at TIMESTAMP WITH TIME ZONE,  -- Resolution timestamp
    resolution_notes TEXT,  -- Resolution notes
    
    -- Timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,  -- Alert expiration
    
    -- Metadata
    correlation_id VARCHAR(100),  -- Correlation ID for tracking
    additional_data JSONB  -- Additional context
);

-- Create indexes
CREATE INDEX idx_data_change_log_table ON data_change_log (table_name);
CREATE INDEX idx_data_change_log_operation ON data_change_log (operation_type);
CREATE INDEX idx_data_change_log_record_id ON data_change_log (record_id);
CREATE INDEX idx_data_change_log_user_id ON data_change_log (user_id);
CREATE INDEX idx_data_change_log_timestamp ON data_change_log (change_timestamp);

CREATE INDEX idx_ml_prediction_log_model ON ml_prediction_log (model_name);
CREATE INDEX idx_ml_prediction_log_type ON ml_prediction_log (model_type);
CREATE INDEX idx_ml_prediction_log_grid_id ON ml_prediction_log (input_grid_id);
CREATE INDEX idx_ml_prediction_log_timestamp ON ml_prediction_log (prediction_timestamp);

CREATE INDEX idx_data_ingestion_log_source ON data_ingestion_log (data_source);
CREATE INDEX idx_data_ingestion_log_type ON data_ingestion_log (data_type);
CREATE INDEX idx_data_ingestion_log_status ON data_ingestion_log (processing_status);
CREATE INDEX idx_data_ingestion_log_timestamp ON data_ingestion_log (started_at);

CREATE INDEX idx_system_performance_log_endpoint ON system_performance_log (endpoint_path);
CREATE INDEX idx_system_performance_log_status ON system_performance_log (status);
CREATE INDEX idx_system_performance_log_response_time ON system_performance_log (response_time_ms);
CREATE INDEX idx_system_performance_log_timestamp ON system_performance_log (request_timestamp);

CREATE INDEX idx_alert_log_type ON alert_log (alert_type);
CREATE INDEX idx_alert_log_severity ON alert_log (alert_severity);
CREATE INDEX idx_alert_log_status ON alert_log (acknowledged, resolved);
CREATE INDEX idx_alert_log_timestamp ON alert_log (created_at);
CREATE INDEX idx_alert_log_geographic ON alert_log (state_code, district_code);

-- Add comments
COMMENT ON TABLE data_change_log IS 'Detailed log of all data modifications for audit trail';
COMMENT ON TABLE ml_prediction_log IS 'Log of all ML model predictions for monitoring and debugging';
COMMENT ON TABLE data_ingestion_log IS 'Log of all data ingestion operations for monitoring and troubleshooting';
COMMENT ON TABLE system_performance_log IS 'System performance metrics for monitoring and optimization';
COMMENT ON TABLE alert_log IS 'Alert log for tracking system notifications and responses';

-- Users and Roles Schema
-- This schema defines users, roles, and permissions for RBAC authentication

-- Roles table
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_name VARCHAR(50) UNIQUE NOT NULL,  -- Role name: ADMIN, ANALYST, FIELD_SURVEYOR, VIEWER
    display_name VARCHAR(100) NOT NULL,  -- Display name for the role
    description TEXT,  -- Role description
    
    -- Role hierarchy
    parent_role_id UUID,  -- Parent role for hierarchy
    level INTEGER DEFAULT 0,  -- Role level in hierarchy
    
    -- Permissions
    permissions TEXT[] NOT NULL,  -- Array of permission strings
    can_read BOOLEAN DEFAULT TRUE,  -- Can read data
    can_write BOOLEAN DEFAULT FALSE,  -- Can write data
    can_delete BOOLEAN DEFAULT FALSE,  -- Can delete data
    can_admin BOOLEAN DEFAULT FALSE,  -- Can perform admin operations
    
    -- Metadata
    is_system_role BOOLEAN DEFAULT FALSE,  -- Whether this is a system role
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(50) UNIQUE NOT NULL,  -- Unique user identifier
    username VARCHAR(100) UNIQUE NOT NULL,  -- Username for login
    email VARCHAR(255) UNIQUE NOT NULL,  -- Email address
    
    -- Authentication
    password_hash VARCHAR(255) NOT NULL,  -- Bcrypt password hash
    salt VARCHAR(100),  -- Password salt (if needed)
    
    -- User information
    full_name VARCHAR(200) NOT NULL,  -- Full name
    phone_number VARCHAR(20),  -- Phone number
    designation VARCHAR(100),  -- Designation/Title
    department VARCHAR(100),  -- Department
    organization VARCHAR(200),  -- Organization name
    
    -- Geographic assignment
    state_code VARCHAR(10),  -- Assigned state code
    district_code VARCHAR(10),  -- Assigned district code
    assigned_regions TEXT[],  -- Array of assigned region codes
    
    -- Role assignment
    role_id UUID NOT NULL,  -- Assigned role
    is_active BOOLEAN DEFAULT TRUE,  -- Account status
    is_verified BOOLEAN DEFAULT FALSE,  -- Email verification status
    
    -- Security
    last_login TIMESTAMP WITH TIME ZONE,  -- Last login timestamp
    failed_login_attempts INTEGER DEFAULT 0,  -- Failed login attempts
    account_locked_until TIMESTAMP WITH TIME ZONE,  -- Account lock expiration
    password_changed_at TIMESTAMP WITH TIME ZONE,  -- Last password change
    must_change_password BOOLEAN DEFAULT FALSE,  -- Force password change
    
    -- API access
    api_key VARCHAR(100) UNIQUE,  -- API key for programmatic access
    api_key_expires TIMESTAMP WITH TIME ZONE,  -- API key expiration
    
    -- Session management
    current_session_id VARCHAR(100),  -- Current session ID
    session_expires TIMESTAMP WITH TIME ZONE,  -- Session expiration
    
    -- Metadata
    created_by VARCHAR(100),  -- User who created this account
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User sessions table
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id VARCHAR(100) UNIQUE NOT NULL,  -- Session ID
    user_id UUID NOT NULL,  -- Reference to user
    
    -- Session details
    ip_address VARCHAR(45),  -- IP address
    user_agent TEXT,  -- User agent string
    device_type VARCHAR(50),  -- Device type: DESKTOP, MOBILE, TABLET
    browser VARCHAR(50),  -- Browser type
    
    -- Session timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,  -- Session expiration
    
    -- Session status
    is_active BOOLEAN DEFAULT TRUE,  -- Session status
    logout_timestamp TIMESTAMP WITH TIME ZONE,  -- Logout timestamp
    
    -- Security
    location_data JSONB,  -- Geographic location data
    security_flags TEXT[],  -- Security flags
    
    -- Foreign key to users
    CONSTRAINT fk_user_sessions_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE
);

-- API keys table
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key_id VARCHAR(100) UNIQUE NOT NULL,  -- API key identifier
    api_key_hash VARCHAR(255) NOT NULL,  -- Hashed API key
    
    -- Key ownership
    user_id UUID NOT NULL,  -- Reference to user
    key_name VARCHAR(100),  -- Key name/description
    
    -- Key permissions
    permissions TEXT[],  -- Array of permissions
    allowed_endpoints TEXT[],  -- Array of allowed endpoint patterns
    
    -- Key usage
    usage_count INTEGER DEFAULT 0,  -- Usage count
    last_used TIMESTAMP WITH TIME ZONE,  -- Last used timestamp
    
    -- Key timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,  -- Key expiration
    revoked_at TIMESTAMP WITH TIME ZONE,  -- Revocation timestamp
    
    -- Key status
    is_active BOOLEAN DEFAULT TRUE,  -- Key status
    revoke_reason TEXT,  -- Reason for revocation
    
    -- Foreign key to users
    CONSTRAINT fk_api_keys_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE
);

-- Audit log table
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    log_id VARCHAR(100) UNIQUE NOT NULL,  -- Unique log identifier
    
    -- User information
    user_id UUID,  -- User who performed the action
    username VARCHAR(100),  -- Username
    role_name VARCHAR(50),  -- Role at time of action
    
    -- Action details
    action_type VARCHAR(50) NOT NULL,  -- Action type: CREATE, READ, UPDATE, DELETE, LOGIN, LOGOUT
    resource_type VARCHAR(50) NOT NULL,  -- Resource type: USER, ROLE, HABITATION, SHELTER, RED_ZONE
    resource_id VARCHAR(100),  -- Resource ID affected
    action_description TEXT,  -- Description of the action
    
    -- Request details
    ip_address VARCHAR(45),  -- IP address
    user_agent TEXT,  -- User agent
    request_method VARCHAR(10),  -- HTTP method
    request_path TEXT,  -- Request path
    
    -- Changes
    old_values JSONB,  -- Old values (for updates)
    new_values JSONB,  -- New values
    changes_summary TEXT,  -- Summary of changes
    
    -- Status
    action_status VARCHAR(20) NOT NULL,  -- Status: SUCCESS, FAILURE, PARTIAL
    error_message TEXT,  -- Error message if failed
    
    -- Timing
    action_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processing_time_ms INTEGER,  -- Processing time in milliseconds
    
    -- Metadata
    session_id VARCHAR(100),  -- Session ID
    correlation_id VARCHAR(100),  -- Correlation ID for tracking
    additional_data JSONB  -- Additional context data
);

-- Create indexes
CREATE INDEX idx_users_user_id ON users (user_id);
CREATE INDEX idx_users_username ON users (username);
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_role_id ON users (role_id);
CREATE INDEX idx_users_state_district ON users (state_code, district_code);
CREATE INDEX idx_users_is_active ON users (is_active);

CREATE INDEX idx_roles_role_name ON roles (role_name);
CREATE INDEX idx_roles_parent_role ON roles (parent_role_id);

CREATE INDEX idx_user_sessions_session_id ON user_sessions (session_id);
CREATE INDEX idx_user_sessions_user_id ON user_sessions (user_id);
CREATE INDEX idx_user_sessions_expires ON user_sessions (expires_at);
CREATE INDEX idx_user_sessions_is_active ON user_sessions (is_active);

CREATE INDEX idx_api_keys_key_id ON api_keys (key_id);
CREATE INDEX idx_api_keys_user_id ON api_keys (user_id);
CREATE INDEX idx_api_keys_is_active ON api_keys (is_active);

CREATE INDEX idx_audit_log_user_id ON audit_log (user_id);
CREATE INDEX idx_audit_log_action_type ON audit_log (action_type);
CREATE INDEX idx_audit_log_resource_type ON audit_log (resource_type);
CREATE INDEX idx_audit_log_resource_id ON audit_log (resource_id);
CREATE INDEX idx_audit_log_action_timestamp ON audit_log (action_timestamp);
CREATE INDEX idx_audit_log_action_status ON audit_log (action_status);

-- Create foreign keys
ALTER TABLE users 
ADD CONSTRAINT fk_users_role 
FOREIGN KEY (role_id) 
REFERENCES roles(id) 
ON DELETE RESTRICT;

-- Create triggers for updated_at
CREATE OR REPLACE FUNCTION update_roles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION update_roles_updated_at();

CREATE OR REPLACE FUNCTION update_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_users_updated_at();

-- Insert default roles
INSERT INTO roles (role_name, display_name, description, permissions, can_read, can_write, can_delete, can_admin, is_system_role) VALUES
('ADMIN', 'Administrator', 'Full system access with administrative privileges', 
 ARRAY['ALL'], TRUE, TRUE, TRUE, TRUE, TRUE),
('ANALYST', 'Data Analyst', 'Can read and analyze data, generate reports', 
 ARRAY['READ', 'ANALYZE', 'EXPORT'], TRUE, FALSE, FALSE, FALSE, TRUE),
('FIELD_SURVEYOR', 'Field Surveyor', 'Can submit field data and update ground truth', 
 ARRAY['READ', 'WRITE_FIELD_DATA', 'SYNC'], TRUE, TRUE, FALSE, FALSE, TRUE),
('VIEWER', 'Viewer', 'Read-only access to data and reports', 
 ARRAY['READ'], TRUE, FALSE, FALSE, FALSE, TRUE);

-- Add comments
COMMENT ON TABLE roles IS 'User roles with permissions for RBAC';
COMMENT ON TABLE users IS 'User accounts with authentication and role assignments';
COMMENT ON TABLE user_sessions IS 'User session management for authentication';
COMMENT ON TABLE api_keys IS 'API keys for programmatic access';
COMMENT ON TABLE audit_log IS 'Audit trail of all system actions for compliance and security';

CREATE TABLE event (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    
    created_at DOUBLE,
    
    request_id VARCHAR(255),
    
    event_type VARCHAR(255),
    
    payload TEXT,
    
    request_user_email VARCHAR(255),
    
    success BOOLEAN,
    
    failure_reason VARCHAR(255)
    
) ENGINE=InnoDB;
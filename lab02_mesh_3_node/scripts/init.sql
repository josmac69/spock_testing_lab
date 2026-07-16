-- Enable Spock logical replication extension
CREATE EXTENSION IF NOT EXISTS spock;

-- Create target table for replication
CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    last_reported TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Spock logical replication extension
CREATE EXTENSION IF NOT EXISTS spock;

-- Create target table for replication (must have a primary key or replica identity full)
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

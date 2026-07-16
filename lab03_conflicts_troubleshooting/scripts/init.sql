-- Enable Spock logical replication extension
CREATE EXTENSION IF NOT EXISTS spock;

-- Create target table for replication
CREATE TABLE IF NOT EXISTS tasks (
    id INT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

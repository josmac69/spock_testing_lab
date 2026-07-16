-- Create the Spock node definition for node2.
-- The DSN is what other nodes will use to connect to this node.
SELECT spock.node_create(
    node_name := 'node2',
    dsn := 'host=node2 port=5432 dbname=spock_db user=spock_user password=spock_password'
);

-- Add all tables in public schema to the default replication set
SELECT spock.repset_add_all_tables('default', ARRAY['public']);
